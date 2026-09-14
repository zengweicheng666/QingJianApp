# 「轻剪」拍剪一体 App · MVP 开发计划

> 版本：v1.0 ｜ 日期：2026-09-14 ｜ 状态：待评审
> 平台：HarmonyOS NEXT（API 18+，ArkTS/ArkUI + NAPI）｜ 工具链：DevEco Studio 5.x + hvigor
> 关联资料：`D:\Work-HMOS\NAPI相机视频开发资料\`（Camera Kit NDK 指南、AVCodec 指南、hm-codec-demo、knowledge_demo_entainment/MediaCuteDemo）

---

## 0. 一句话定位

**打开相机即拍、拍完即剪、剪完即存**的轻量视频工具：相机拍摄（Camera Kit）→ 视频处理（ffmpeg NAPI）→ 导出相册。

## 0.1 当前进度（2026-09-14 更新）

| 阶段 | 状态 |
|---|---|
| D1-D2 工程骨架 + 相机拍摄（预览/录像/拍照/切换/闪光灯/权限） | ✅ 已实现（git 已提交） |
| D3 ffmpeg 接入（@ohos/ffmpeg-kit）+ 编辑页裁剪 UI（起止滑块） | ✅ 已实现（代码就绪，待真机验证） |
| D4 导出闭环（裁剪→进度→保存相册） | ✅ 已实现（代码就绪，待真机验证） |
| D5 拼接（多段 + 顺序调整） | ✅ 已实现（代码就绪，待真机验证） |
| D6 压缩三档预设（代码已内置，待真机验证） | 🔶 部分 |
| D7 边界打磨 + 回归 | ⬜ 待开发 |

> ⚠️ D3 依赖：真机编译前需在 `entry` 目录执行 `ohpm install @ohos/ffmpeg-kit`。

## 1. 项目概述

| 项 | 内容 |
|---|---|
| 产品名 | 轻剪（暂定，可改） |
| 目标用户 | 普通用户（拍完想快速裁剪/压缩/拼接视频发朋友圈或存储） |
| 核心价值 | 拍摄与编辑在同一 App 内闭环，操作 3 步内完成：拍 → 剪 → 存 |
| 技术路线 | Camera Kit（拍摄）+ @ohos/ffmpeg-kit NAPI（处理），一期不做 NDK 直通编码 |
| 运行环境 | 真机（模拟器不支持相机），HarmonyOS NEXT API 18+ |

## 2. MVP 范围

### ✅ 做（4 大功能模块）

| # | 模块 | 功能点 | 验收标准 |
|---|---|---|---|
| M1 | 相机拍摄 | 预览取景、录像、拍照、前后摄切换、闪光灯、录像时长上限（60s） | 能录一段 mp4 并在系统相册看到 |
| M2 | 相册导入 | 系统相册视频网格选择（单选/多选） | 能选中任意已有视频进入编辑 |
| M3 | 视频编辑 | 裁剪（起止时间，最小 1s）、拼接（多段，可调整顺序） | 裁剪/拼接结果与设定一致 |
| M4 | 导出 | 分辨率（480p/720p/1080p）+ 码率选项、进度展示、保存到相册、失败提示 | 导出视频系统相册可播放 |

### ❌ 不做（二期）

- 相机流 NDK 直通编码（hm-codec-demo 方案）
- 滤镜 / 美颜 / AI 特效 / 实时预览二次处理
- 音轨编辑、字幕、转场
- 分享/发布到社交平台

## 3. 技术栈与架构

```
┌─────────────────────────────────────────────────────────┐
│ UI 层  ArkTS (ArkUI)                                     │
│   相机页 Index · 相册页 AlbumPage · 编辑页 EditPage · 导出页 ExportPage  │
├─────────────────────────────────────────────────────────┤
│ 服务层  ArkTS Service                                    │
│   CameraService（相机生命周期封装）· VideoProcessor（ffmpeg 封装）      │
├─────────────────────────────────────────────────────────┤
│ 能力层  NAPI                                              │
│   @ohos/ffmpeg-kit（ffmpeg.so 桥接，命令执行 + 进度回调）              │
├─────────────────────────────────────────────────────────┤
│ 系统层  HarmonyOS Kit                                     │
│   Camera Kit（相机采集）· Media Kit（AVRecorder 录像）·              │
│   PhotoAccessHelper（媒体库读写）· 安全控件 SaveButton（免权限保存）      │
└─────────────────────────────────────────────────────────┘
```

- 相机：`@kit.CameraKit`（cameraManager → 后/前 CameraDevice → PreviewOutput + VideoOutput），录像用 `AVRecorder` 落盘为 mp4。
- 处理：`@ohos/ffmpeg-kit`（ohpm 三方库，NAPI 桥接 ffmpeg），封装为 `VideoProcessor` 统一 Promise + 进度回调。
- 存储：沙箱临时目录做中间文件，最终用安全控件 `SaveButton`（免读写权限）或 `PhotoAccessHelper.createAsset` 存入相册。
- 权限：仅需 `ohos.permission.CAMERA` + `ohos.permission.MICROPHONE`（拍摄），读取相册用系统相册选择器（免权限）。

## 4. 页面与交互流程

```
  ┌──────────┐   拍完自动进入   ┌──────────┐   导出   ┌──────────┐
  │  相机页   │ ─────────────▶ │  编辑页   │ ──────▶ │  导出页   │
  └──────────┘                 └──────────┘          └──────────┘
       │ ▲                         ▲  ▲                  │
       │ │ 右上角相册入口            │  │ 再次编辑          │ 保存到相册
       ▼ │                         │  │                  ▼
  ┌──────────┐   选中视频          ┌──┴──┐           系统相册（可播放）
  │ 相册选择页 │ ─────────────────▶ │ 编辑页 │
  └──────────┘                    └─────┘
```

**相机页**：XComponent 取景预览；底部录像/拍照按钮；顶部前后摄切换 + 闪光灯；右上角相册入口；底部"最近拍摄"缩略图。
**相册选择页**：系统相册视频网格，单选/多选后进入编辑。
**编辑页**：Video 播放器 + 进度条；**裁剪模式**起止时间滑块（最小 1s）；**拼接模式**多段列表（上移/下移/删除）；底部导出设置（分辨率/码率）+「导出」按钮。
**导出页**：ffmpeg 进度条；完成后展示缩略图 + 「保存到相册」「再次编辑」「完成」。

## 5. 技术实现要点

### 5.1 相机拍摄（Camera Kit，ArkTS）

```ts
import { camera } from '@kit.CameraKit';
import { media } from '@kit.MediaKit';
import { common } from '@kit.AbilityKit';

// 1. 创建 CameraManager
const cameraManager = camera.getCameraManager(context);
// 2. 获取设备并创建输入
const cameras = cameraManager.getSupportedCameras();
const input = cameraManager.createCameraInput(cameras[0]); // 后摄
await input.open();
// 3. 获取输出能力
const capability = cameraManager.getSupportedOutputCapability(cameras[0]);
// 4. 预览输出（surfaceId 由 XComponent 提供）
const previewOutput = cameraManager.createPreviewOutput(capability.previewProfiles[0], surfaceId);
// 5. 录像输出（surfaceId 来自 AVRecorder）
const avRecorder = media.createAVRecorder();
await avRecorder.prepare(avConfig); // 配置 H.264 + 分辨率 + 码率 + 输出 fd
const videoOutput = cameraManager.createVideoOutput(capability.videoProfiles[0], avRecorder.getInputSurface());
// 6. 会话组装
const session = cameraManager.createSession(camera.SceneMode.NORMAL_PHOTO);
session.addInput(input); session.addPreviewOutput(previewOutput); session.addVideoOutput(videoOutput);
await session.commitConfig(); await session.start();
// 7. 录像
await avRecorder.start(); ... await avRecorder.stop(); await videoOutput.stop();
// 8. 切换前后摄：session.stop() → release 输出 → 重建 input/output → 重新 start
```

- 关键点：预览流与录像流分辨率宽高比需一致（如 4:3）。
- 生命周期：页面 onPageHide/onDestroy 时释放 session、output、input，防止相机被占用。

### 5.2 视频处理（@ohos/ffmpeg-kit NAPI）

安装：`ohpm install @ohos/ffmpeg-kit`（会自动带 `libffmpegkit_napi.so` + `@ohos/aki` 桥接）。

**ffmpeg 命令模板（核心）**：

| 功能 | 命令 | 说明 |
|---|---|---|
| 裁剪 | `ffmpeg -ss {start} -i {input} -t {dur} -c:v libx264 -c:a aac -y {output}` | MVP 统一重编码，保证关键帧精确 |
| 拼接 | `ffmpeg -f concat -safe 0 -i {list.txt} -c copy -y {output}` | list.txt 内 `file 'xxx.mp4'` 逐行 |
| 压缩/转码 | `ffmpeg -i {input} -vf scale={w}:{h} -b:v {bitrate} -r 30 -c:v libx264 -c:a aac -y {output}` | 480p/720p/1080p 三档预设 |

**封装接口（VideoProcessor.ets）**：

```ts
export class VideoProcessor {
  static async clip(input: string, startSec: number, durSec: number, out: string): Promise<void>;
  static async concat(inputs: string[], out: string): Promise<void>;
  static async compress(input: string, preset: '480p'|'720p'|'1080p', out: string): Promise<void>;
  // 统一内部：ffmpegKit.executeAsync(cmd, onProgress) → 进度回调更新 UI
}
```

**MediaCuteDemo 复用清单**（`knowledge_demo_entainment-master/FA/MediaCuteDemo`）：

| 文件/位置 | 复用内容 |
|---|---|
| `entry/src/main/ets/.../MP4Parser.ets` | 视频处理命令构造 + 回调范式（videoClip 等） |
| `oh-package.json5` / `build-profile.json5` | `@ohos/ffmpeg-kit` 依赖与编译配置 |
| 页面调用方式 | ffmpegKit.executeAsync / getMediaInformation 用法 |

### 5.3 媒体库读写

- 选视频：`PhotoAccessHelper.getPhotoAccessHelper(context).getAssets({ fetchColumns, predicates: 按 mediaType=VIDEO 过滤 })`（MVP 用系统安全相册选择器更省事：`photoAccessHelper.showAssetsPicker` 或 `photoViewPicker`）。
- 保存：`photoAccessHelper.createAsset(photoAccessHelper.PhotoType.VIDEO, 'mp4')` → 打开 uri 写入导出文件；或直接用 `SaveButton` 安全控件免权限保存。
- 中间文件：`context.filesDir`（沙箱）存裁剪/拼接产物，导出后再清缓存。

### 5.4 权限与配置

- `module.json5` 声明：`ohos.permission.CAMERA`、`ohos.permission.MICROPHONE`
- 运行时：`abilityAccessCtrl.createAtManager().requestPermissionsFromUser(context, perms)`，首次进入相机页时弹窗引导。
- 拒绝处理：弹提示 + 引导去设置页。

### 5.5 工程结构规划

```
AppScope/
entry/src/main/
├── ets/
│   ├── entryability/EntryAbility.ets
│   ├── pages/Index.ets          # 相机页
│   ├── pages/AlbumPage.ets      # 相册选择页
│   ├── pages/EditPage.ets       # 编辑页（裁剪/拼接）
│   ├── pages/ExportPage.ets     # 导出页
│   ├── components/              # RecordButton、TimeSlider、ClipList 等
│   ├── services/CameraService.ets   # 相机生命周期封装
│   ├── services/VideoProcessor.ets  # ffmpeg 封装
│   └── utils/                   # 权限、路径、时间格式化
├── module.json5
└── resources/
```

## 6. 里程碑排期（7 天，真机为主）

```
D1  D2  |  D3  D4  |  D5  D6  |  D7
阶段A：拍摄基础  阶段B：编辑导出闭环  阶段C：拼接压缩  阶段D：打磨交付
```

| 天 | 任务 | 完成标志（Gate） |
|---|---|---|
| D1 | 创建工程；权限申请流程；相机页预览 + 拍照跑通 | 真机上能看到相机预览、能拍照 |
| D2 | 录像落地（AVRecorder → mp4）；前后摄切换；闪光灯；相册读取 | 能从相机录一段 mp4 并在系统相册看到 |
| D3 | 编辑页骨架：Video 播放器 + 进度条 + 裁剪起止设置；接通 ffmpeg（ohpm 安装 + 最小命令验证） | ffmpeg 能对测试视频执行一次转码并产出文件 |
| D4 | 裁剪导出闭环：录 → 剪 → 导出 → 存相册 | 30 分钟内跑通全链路，产物可播放 |
| D5 | 拼接：多段选择 + 顺序调整 + 合并导出 | 多段拼接产物与预期一致 |
| D6 | 压缩/转码三档预设 + 进度条 + 失败错误处理 | 大视频压缩成功且有进度反馈 |
| D7 | 边界打磨：无权限/无视频/处理失败/低内存；图标文案；真机全流程回归 | 全流程 0 崩溃，失败有提示 |

## 7. 风险与对策

| 风险 | 影响 | 对策 |
|---|---|---|
| ffmpeg-kit 包体大、首次构建慢 | 安装/打包耗时 | 接受（MVP 求快）；二期换 AVCodec NDK 瘦身 |
| 模拟器无相机 | 无法开发调试 | 提前准备真机；相机逻辑真机联调 |
| `-c copy` 裁剪关键帧不精确 | 起止点偏差 | MVP 裁剪统一重编码（libx264），精确但稍慢 |
| 大视频转码耗时长/发热 | 体验差 | 录像 60s 上限 + 进度反馈；超长视频提示 |
| 拼接片段编码/分辨率不一致 | 输出异常 | MVP 提示用户；二期加"拼接前统一转码" |
| 相机资源未释放 | 二次进入黑屏/占用 | CameraService 统一 onPageHide/onDestroy 释放 |

## 8. 二期规划（出活后可选方向，按优先级）

1. **NDK 相机流直通编码**：Camera → Surface → VideoEncoder → Muxer → MP4（hm-codec-demo 完整方案），省去中间文件、提升录制性能。
2. **实时滤镜**：预览流二次处理（ImageReceiver，见 Camera Kit NDK 指南），支持滤镜/美颜。
3. **模板化剪辑**：转场、字幕、背景音乐，短视频模板一键套用。
4. **社交规格预设**：微信/抖音/快手一键压缩导出。

---

## 附件

- 可视化一图流：`轻剪App_MVP开发计划_可视化.html`（功能架构 + 页面流程 + 里程碑时间线 + 数据流）
- 技术文档（离线版）：`D:\Work-HMOS\NAPI相机视频开发资料\官方文档\Camera_Kit_NDK相机开发指南.md`、`D:\Work-HMOS\NAPI相机视频开发资料\官方文档\AVCodec_Kit_NDK视频编解码开发指南.md`
- 示例工程：`D:\Work-HMOS\NAPI相机视频开发资料\示例工程\hm-codec-demo/`（二期 NDK 直通编码参考）、`D:\Work-HMOS\NAPI相机视频开发资料\示例工程\knowledge_demo_entainment\...\MediaCuteDemo/`（ffmpeg 调用复用）
- 工程根目录：`D:\Work-HMOS\QingJianApp\`（DevEco Studio 直接打开此目录）
