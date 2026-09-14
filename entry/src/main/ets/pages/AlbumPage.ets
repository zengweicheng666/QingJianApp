import { router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FileUtil } from '../utils/FileUtil';

const TAG = 'QingJian';

/**
 * 相册页：系统安全选择器（免权限）选视频。
 * 双入口：选视频去编辑（裁剪/倍速/导出），或直接压缩导出（D6 闭环）。
 */
@Entry
@Component
struct AlbumPage {
  /** 选择单个视频并拷到沙箱，返回路径；取消返回空串 */
  private async pickVideo(): Promise<string> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
      options.maxSelectNumber = 1;
      const res = await picker.select(options);
      const uris = res.photoUris;
      if (uris === undefined || uris.length === 0) {
        return '';
      }
      return FileUtil.copyUriToSandbox(uris[0], 0);
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'pickVideo failed code=%{public}d msg=%{public}s', e.code, e.message);
      promptAction.showToast({ message: '选择视频失败' });
      return '';
    }
  }

  private async pickToEdit(): Promise<void> {
    const path = await this.pickVideo();
    if (path === '') {
      return;
    }
    router.pushUrl({
      url: 'pages/EditPage',
      params: { videoPath: path }
    }).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'push EditPage failed %{public}s', err.message);
    });
  }

  private async pickToCompress(): Promise<void> {
    const path = await this.pickVideo();
    if (path === '') {
      return;
    }
    router.pushUrl({
      url: 'pages/ExportPage',
      params: { mode: 'compress', videoPath: path }
    }).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'push ExportPage failed %{public}s', err.message);
    });
  }

  build() {
    Column({ space: 20 }) {
      Text('相册')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 32 })

      Text('从系统相册选择一个视频')
        .fontSize(14)
        .fontColor('#667')

      Button('选择视频并编辑（裁剪/倍速）')
        .width(280)
        .onClick(() => this.pickToEdit())

      Button('直接压缩导出（预设三档）')
        .width(280)
        .type(ButtonType.Capsule)
        .backgroundColor('#0b57a4')
        .onClick(() => this.pickToCompress())

      Text('压缩入口：选完直接进入导出页选 480p/720p/1080p 预设，\n处理完成保存回相册')
        .fontSize(12)
        .fontColor('#889')
        .textAlign(TextAlign.Center)

      Button('返回')
        .width(280)
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .height('100%')
  }
}
