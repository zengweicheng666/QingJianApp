# QingJian 轻剪

HarmonyOS NEXT（API 26）拍剪一体视频工具：相机拍摄 → 裁剪 / 压缩 / 拼接 / 倍速 / 图片转视频 → 保存相册。

## 功能

- 相机拍摄：拍照、录像、前后摄切换（@kit.CameraKit + AVRecorder）
- 素材导入：系统相册 Picker、文件管理「我的手机」（DocumentViewPicker，免权限 SAF）
- 视频编辑：起止点裁剪、0.5/1/1.5/2 倍速、480p/720p/1080p 压缩预设
- 多段拼接：多片段顺序合并
- 图片转视频：单图生成 1–10 秒 720p MP4
- 导出保存：ffmpeg-kit 处理后写入系统相册（photoAccessHelper）

## 技术栈

- DevEco Studio 26 / ArkTS / ArkUI 声明式 UI
- 视频处理：`@ohos/ffmpeg-kit`（NAPI，仅提供 arm64-v8a 原生库）
- 媒体：AVPlayer / AVMetadataExtractor（fdSrc 读取时长）、Video 组件
- 存储：应用沙箱 + 安全控件/Picker，零敏感权限外暴露

## 目录结构

```
entry/src/main/ets/
├── pages/          # Index 拍摄 / AlbumPage 素材 / EditPage 编辑
│                   # ClipMergePage 拼接 / ExportPage 导出
├── services/       # CameraService 相机 / VideoProcessor ffmpeg 封装
└── utils/          # FileUtil / PermissionUtil
docs/               # MVP 开发计划与技术备注
emulator_media/     # 模拟器联调测试素材
```

## 构建运行

1. DevEco Studio 打开本工程，Sync 后 `assembleHap`；或命令行：
   ```powershell
   $env:DEVECO_SDK_HOME="<你的SDK路径>"
   hvigorw.bat assembleHap --mode module -p product=default
   ```
2. 产物：`entry/build/default/outputs/default/entry-default-unsigned.hap`
3. **视频处理（ffmpeg）需 arm64 设备**：HarmonyOS 真机，或 arm64-v8a 模拟器；x86_64 模拟器缺少对应原生库无法导出。

## 文档

- [MVP 开发计划](docs/轻剪App_MVP开发计划.md)
