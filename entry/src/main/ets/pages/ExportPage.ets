import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VideoProcessor, CompressPreset } from '../services/VideoProcessor';
import { PermissionUtil } from '../utils/PermissionUtil';

const TAG = 'QingJian';

/**
 * 导出页（D4）：执行裁剪/压缩 → 进度展示 → 保存到相册。
 * 路由参数：videoPath / startSec / endSec（裁剪区间）。
 */
@Entry
@Component
struct ExportPage {
  @State videoPath: string = '';
  @State startSec: number = 0;
  @State endSec: number = 0;
  @State progress: number = 0;
  @State statusText: string = '就绪';
  @State exporting: boolean = false;
  @State outputPath: string = '';
  @State preset: CompressPreset = '720p';
  @State useCompress: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, number | string>;
    if (params !== undefined) {
      this.videoPath = (params.videoPath as string) ?? '';
      this.startSec = (params.startSec as number) ?? 0;
      this.endSec = (params.endSec as number) ?? 0;
    }
  }

  /** 执行导出：裁剪 或 压缩（勾选压缩时走压缩预设） */
  private async startExport(): Promise<void> {
    if (this.videoPath === '' || this.exporting) {
      return;
    }
    this.exporting = true;
    this.progress = 0;
    this.statusText = '处理中...';
    try {
      const outPath = `${getContext(this).filesDir}/qingjian_out_${Date.now()}.mp4`;
      if (this.useCompress) {
        await VideoProcessor.compress(this.videoPath, this.preset, outPath,
          (p: number) => this.progress = p);
      } else {
        const dur = Math.max(0.1, this.endSec - this.startSec);
        await VideoProcessor.clip(this.videoPath, this.startSec, dur, outPath,
          (p: number) => this.progress = p);
      }
      this.outputPath = outPath;
      this.statusText = '处理完成';
      promptAction.showToast({ message: '处理完成，点击保存到相册' });
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'export failed %{public}s', e.message);
      this.statusText = `处理失败：${e.message}`;
      promptAction.showToast({ message: '处理失败，请重试' });
    } finally {
      this.exporting = false;
    }
  }

  /** 保存到相册：photoAccessHelper.createAsset 写入（需 WRITE_IMAGEVIDEO 权限） */
  private async saveToAlbum(): Promise<void> {
    if (this.outputPath === '') {
      return;
    }
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const granted = await PermissionUtil.requestWriteMediaPermission(context);
      if (!granted) {
        promptAction.showToast({ message: '未授予相册写入权限' });
        return;
      }
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.VIDEO, 'mp4');
      // 将产物文件内容写入媒体库 uri
      fs.copyFileSync(this.outputPath, uri);
      promptAction.showToast({ message: '已保存到相册' });
      this.statusText = '已保存到相册';
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'saveToAlbum failed code=%{public}d msg=%{public}s', e.code, e.message);
      promptAction.showToast({ message: '保存失败，请检查权限' });
    }
  }

  build() {
    Column({ space: 14 }) {
      Text('导出')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 28 })

      if (this.videoPath !== '') {
        Text(this.useCompress ? '压缩/转码' : `裁剪 ${this.startSec}s → ${this.endSec}s`)
          .fontSize(14)
          .fontColor('#334')
      } else {
        Text('无输入视频')
          .fontSize(14)
          .fontColor('#889')
      }

      // 压缩预设选项
      Row({ space: 18 }) {
        Text('压缩预设：')
          .fontSize(14)
        Radio({ value: '480p', group: 'preset' })
          .checked(this.preset === '480p')
          .onChange(() => this.preset = '480p')
        Text('480p')
          .fontSize(14)
        Radio({ value: '720p', group: 'preset' })
          .checked(this.preset === '720p')
          .onChange(() => this.preset = '720p')
        Text('720p')
          .fontSize(14)
        Radio({ value: '1080p', group: 'preset' })
          .checked(this.preset === '1080p')
          .onChange(() => this.preset = '1080p')
        Text('1080p')
          .fontSize(14)
      }
      .justifyContent(FlexAlign.Center)

      Checkbox('压缩导出（默认裁剪）')
        .select(this.useCompress)
        .onChange((checked: boolean) => this.useCompress = checked)

      Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
        .width('80%')
        .color('#0b57a4')

      Text(this.statusText)
        .fontSize(14)
        .fontColor(this.statusText.startsWith('处理失败') ? Color.Red : '#334')

      Button(this.exporting ? '处理中...' : '开始导出')
        .width(240)
        .enabled(!this.exporting && this.videoPath !== '')
        .onClick(() => this.startExport())

      Button('保存到相册')
        .width(240)
        .enabled(this.outputPath !== '')
        .onClick(() => this.saveToAlbum())

      Button('返回')
        .width(240)
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .height('100%')
  }
}
