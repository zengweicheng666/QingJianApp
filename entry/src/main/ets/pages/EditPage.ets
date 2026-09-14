import { router } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'QingJian';

/**
 * 编辑页（D3）：视频播放 + 裁剪起止时间（最小 1s）+ 拼接占位 + 导出入口。
 * 路由参数：videoPath（来自相机录像或相册选择）。
 */
@Entry
@Component
struct EditPage {
  @State videoPath: string = '';
  @State durationSec: number = 0;
  @State startSec: number = 0;
  @State endSec: number = 0;
  private videoController: VideoController = new VideoController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params !== undefined && params.videoPath !== undefined) {
      this.videoPath = params.videoPath;
      this.loadDuration();
    }
  }

  /** 用 AVPlayer 读取视频时长（Video 组件不直接暴露 duration） */
  private async loadDuration(): Promise<void> {
    if (this.videoPath === '') {
      return;
    }
    try {
      const avPlayer: media.AVPlayer = await media.createAVPlayer();
      avPlayer.on('durationUpdate', (duration: number) => {
        const total = Math.floor(duration / 1000);
        this.durationSec = total;
        this.startSec = 0;
        this.endSec = total > 0 ? total : 0;
        avPlayer.release();
      });
      avPlayer.url = `file://${this.videoPath}`;
      await avPlayer.prepare();
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'loadDuration failed code=%{public}d msg=%{public}s', e.code, e.message);
    }
  }

  private fmt(sec: number): string {
    const s = Math.max(0, Math.floor(sec));
    const mm = Math.floor(s / 60);
    const ss = s % 60;
    return `${mm}:${ss.toString().padStart(2, '0')}`;
  }

  /** 起点滑块：约束 start < end - 1 */
  private onStartChange(value: number): void {
    const max = Math.max(0, this.endSec - 1);
    this.startSec = Math.min(value, max);
  }

  /** 终点滑块：约束 end > start + 1 */
  private onEndChange(value: number): void {
    const min = this.startSec + 1;
    this.endSec = Math.max(value, min);
  }

  private goExport(): void {
    if (this.durationSec <= 0) {
      return;
    }
    router.pushUrl({
      url: 'pages/ExportPage',
      params: {
        videoPath: this.videoPath,
        startSec: this.startSec,
        endSec: this.endSec,
        durationSec: this.durationSec
      }
    }).catch((err: Error) => {
      hilog.error(0x0000, TAG, 'push ExportPage failed %{public}s', err.message);
    });
  }

  build() {
    Column({ space: 12 }) {
      Text('编辑')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16 })

      if (this.videoPath !== '') {
        Video({
          src: `file://${this.videoPath}`,
          controller: this.videoController
        })
          .width('100%')
          .height(280)
          .controls(true)
      } else {
        Text('未选择视频')
          .fontSize(14)
          .fontColor('#889')
          .height(280)
      }

      if (this.durationSec > 0) {
        // 裁剪起止
        Column({ space: 8 }) {
          Row() {
            Text('裁剪起点')
              .fontSize(14)
            Blank()
            Text(`${this.fmt(this.startSec)} / ${this.fmt(this.durationSec)}`)
              .fontSize(13)
              .fontColor('#0b57a4')
          }
          .width('92%')

          Slider({
            value: this.startSec,
            min: 0,
            max: Math.max(1, this.durationSec - 1),
            step: 1
          })
            .width('92%')
            .onChange((value: number) => this.onStartChange(value))

          Row() {
            Text('裁剪终点')
              .fontSize(14)
            Blank()
            Text(`${this.fmt(this.endSec)} / ${this.fmt(this.durationSec)}`)
              .fontSize(13)
              .fontColor('#0b57a4')
          }
          .width('92%')

          Slider({
            value: this.endSec,
            min: 1,
            max: this.durationSec,
            step: 1
          })
            .width('92%')
            .onChange((value: number) => this.onEndChange(value))

          Text(`裁剪时长：${this.fmt(this.endSec - this.startSec)}（最小 1 秒）`)
            .fontSize(12)
            .fontColor('#889')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      } else {
        Text('D3 待实现：裁剪起止时间滑块（AVPlayer 读取时长后可用）')
          .fontSize(13)
          .fontColor('#889')
      }

      Text('D5 待实现：拼接多段列表 + 顺序调整')
        .fontSize(13)
        .fontColor('#889')

      Button('导出')
        .width(240)
        .enabled(this.durationSec > 0)
        .margin({ top: 8 })
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
