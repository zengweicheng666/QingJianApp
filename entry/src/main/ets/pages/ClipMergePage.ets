import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { FileUtil } from '../utils/FileUtil';

const TAG = 'QingJian';

/**
 * 拼接页（D5）：片段列表管理（添加/删除/排序）+ 拼接导出入口。
 * 添加：系统相册选择视频（PhotoViewPicker）→ 拷贝到沙箱 → 加入列表。
 * 导出：跳转 ExportPage（mode=concat），由 ffmpeg filter_complex 统一转码拼接。
 */
@Entry
@Component
struct ClipMergePage {
  @State clips: Array<string> = [];

  /** 从系统相册选一个视频加入列表 */
  private async addClip(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const options = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
      options.maxSelectNumber = 1;
      const res = await picker.select(options);
      const uris = res.photoUris;
      if (uris === undefined || uris.length === 0) {
        return;
      }
      const path = FileUtil.copyUriToSandbox(uris[0], this.clips.length);
      this.clips.push(path);
      promptAction.showToast({ message: `已添加第 ${this.clips.length} 段` });
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'addClip failed code=%{public}d msg=%{public}s', e.code, e.message);
      promptAction.showToast({ message: '添加片段失败' });
    }
  }

  private moveUp(index: number): void {
    if (index <= 0) {
      return;
    }
    const item = this.clips[index];
    this.clips.splice(index, 1);
    this.clips.splice(index - 1, 0, item);
  }

  private moveDown(index: number): void {
    if (index >= this.clips.length - 1) {
      return;
    }
    const item = this.clips[index];
    this.clips.splice(index, 1);
    this.clips.splice(index + 1, 0, item);
  }

  private removeClip(index: number): void {
    this.clips.splice(index, 1);
  }

  private fileName(path: string): string {
    const idx = path.lastIndexOf('/');
    return idx >= 0 ? path.substring(idx + 1) : path;
  }

  private goExport(): void {
    if (this.clips.length < 2) {
      promptAction.showToast({ message: '拼接至少需要 2 段视频' });
      return;
    }
    router.pushUrl({
      url: 'pages/ExportPage',
      params: {
        mode: 'concat',
        clipPaths: this.clips
      }
    }).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'push ExportPage failed %{public}s', err.message);
    });
  }

  build() {
    Column({ space: 10 }) {
      Text('拼接')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16 })

      Button('添加片段（从相册选择）')
        .width(260)
        .onClick(() => this.addClip())

      if (this.clips.length === 0) {
        Text('暂无片段\n点击上方按钮从相册选择视频（至少 2 段）')
          .fontSize(13)
          .fontColor('#889')
          .textAlign(TextAlign.Center)
          .margin({ top: 40 })
      } else {
        List({ space: 8 }) {
          ForEach(this.clips, (path: string, index: number) => {
            ListItem() {
              Row({ space: 8 }) {
                Text(`${index + 1}.`)
                  .fontSize(14)
                  .fontColor('#0b57a4')
                  .width(24)
                Text(this.fileName(path))
                  .fontSize(13)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Button('↑')
                  .width(40)
                  .height(32)
                  .fontSize(13)
                  .enabled(index > 0)
                  .onClick(() => this.moveUp(index))
                Button('↓')
                  .width(40)
                  .height(32)
                  .fontSize(13)
                  .enabled(index < this.clips.length - 1)
                  .onClick(() => this.moveDown(index))
                Button('×')
                  .width(40)
                  .height(32)
                  .fontSize(13)
                  .type(ButtonType.Circle)
                  .backgroundColor('#d32f2f')
                  .onClick(() => this.removeClip(index))
              }
              .width('94%')
              .padding(8)
              .borderRadius(8)
              .backgroundColor('#f2f6fb')
            }
          }, (path: string, index: number) => `${index}_${path}`)
        }
        .layoutWeight(1)
        .width('100%')
      }

      Text(this.clips.length >= 2 ? `共 ${this.clips.length} 段，将统一转码拼接` : '')
        .fontSize(12)
        .fontColor('#889')

      Button('拼接导出')
        .width(240)
        .enabled(this.clips.length >= 2)
        .onClick(() => this.goExport())

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
