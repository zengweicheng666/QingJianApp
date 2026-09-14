import { router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FileUtil } from '../utils/FileUtil';

const TAG = 'QingJian';

/** 文件管理可选的视频后缀 */
const VIDEO_SUFFIXES: Array<string> = ['.mp4', '.mov', '.3gp', '.mkv', '.webm', '.avi'];
/** 文件管理可选的图片后缀 */
const IMAGE_SUFFIXES: Array<string> = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'];

/**
 * 素材页：相册（PhotoViewPicker）+ 文件管理"我的手机"（DocumentViewPicker，免权限）。
 * 视频 → 编辑/压缩导出；图片 → 转 3 秒视频导出（E6）。
 */
@Entry
@Component
struct AlbumPage {
  /** 选择单个视频并拷到沙箱，返回路径；取消返回空串 */
  private async pickVideo(): Promise<string> {
    try {
      const pickerHelper = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
      options.maxSelectNumber = 1;
      const res = await pickerHelper.select(options);
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

  /** 从文件管理"我的手机"选一个文件（按后缀过滤）并拷到沙箱 */
  private async pickFromFiles(suffixFilters: Array<string>): Promise<string> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      options.fileSuffixFilters = suffixFilters;
      // API 26：select() 直接返回 uri 数组（string[]）
      const uris: Array<string> = await documentPicker.select(options);
      if (uris === undefined || uris.length === 0) {
        return '';
      }
      return FileUtil.copyUriToSandbox(uris[0], 0);
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'pickFromFiles failed code=%{public}d msg=%{public}s', e.code, e.message);
      promptAction.showToast({ message: '从文件管理选择失败' });
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

  /** 文件管理选视频 → 编辑页（裁剪/倍速） */
  private async pickFileToEdit(): Promise<void> {
    const path = await this.pickFromFiles(VIDEO_SUFFIXES);
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

  /** 文件管理选视频 → 直接压缩导出 */
  private async pickFileToCompress(): Promise<void> {
    const path = await this.pickFromFiles(VIDEO_SUFFIXES);
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

  /** 文件管理选图片 → 转 3 秒视频导出 */
  private async pickImageToVideo(): Promise<void> {
    const path = await this.pickFromFiles(IMAGE_SUFFIXES);
    if (path === '') {
      return;
    }
    router.pushUrl({
      url: 'pages/ExportPage',
      params: { mode: 'image', imagePath: path }
    }).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'push ExportPage failed %{public}s', err.message);
    });
  }

  build() {
    Column({ space: 16 }) {
      Text('素材')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 28 })

      Text('素材来源：系统相册 / 文件管理（我的手机）')
        .fontSize(13)
        .fontColor('#667')

      // ── 相册来源 ──
      Text('【相册】')
        .fontSize(13)
        .fontColor('#0b57a4')
        .alignSelf(ItemAlign.Start)
        .margin({ left: 40 })

      Button('选择视频并编辑（裁剪/倍速）')
        .width(280)
        .onClick(() => this.pickToEdit())

      Button('直接压缩导出（预设三档）')
        .width(280)
        .type(ButtonType.Capsule)
        .backgroundColor('#0b57a4')
        .onClick(() => this.pickToCompress())

      // ── 文件管理来源（E6）──
      Text('【文件管理 · 我的手机】')
        .fontSize(13)
        .fontColor('#0b57a4')
        .alignSelf(ItemAlign.Start)
        .margin({ left: 40, top: 8 })

      Button('从文件选视频并编辑')
        .width(280)
        .onClick(() => this.pickFileToEdit())

      Button('从文件选视频压缩导出')
        .width(280)
        .onClick(() => this.pickFileToCompress())

      Button('从文件选图片转视频（3 秒）')
        .width(280)
        .type(ButtonType.Capsule)
        .backgroundColor('#0b57a4')
        .onClick(() => this.pickImageToVideo())

      Text('文件入口使用系统文件选择器，可浏览"我的手机"下\nDownload/图片/视频等目录，免权限')
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
