import { router } from '@kit.ArkUI';
import { media } from '@kit.MediaKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'QingJian';

/**
 * 编辑页（D3）：视频播放 + 裁剪起止时间（最小 1s）+ 拼接占位 + 导出入口。
 * 路由参数：videoPath（来自相机录像或相册/文件选择）。
 * 时长来源：AVPlayer 标准状态机（initialized→prepare→prepared 读 duration）；
 *           Video.onPrepared 仅作兜底，且过滤 <1s 假值（模拟器曾返回 51ms）。
 */
@Entry
@Component
struct EditPage {
  @State videoPath: string = '';
  @State durationSec: number = 0;
  @State startSec: number = 0;
  @State endSec: number = 0;
  @State speed: number = 1;
  private videoController: VideoController = new VideoController();
  private readonly speedOptions: Array<number> = [0.5, 1, 1.5, 2];

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params !== undefined && params.videoPath !== undefined) {
      this.videoPath = params.videoPath;
      this.loadDuration();
    }
  }

  /** 生效时长（毫秒）：过滤 <1s 的模拟器假值 */
  private applyDuration(durationMs: number): void {
    if (durationMs >= 1000 && this.durationSec <= 0) {
      const total = Math.floor(durationMs / 1000);
      this.durationSec = total;
      this.startSec = 0;
      this.endSec = total > 0 ? total : 0;
      hilog.info(0x0000, TAG, 'duration applied: %{public}d ms (%{public}d s)', durationMs, total);
    }
  }

  /** AVPlayer 读时长：fdSrc 喂源（模拟器不接受 file:// url，报 401），initialized→prepare→prepared 读 duration */
  private async loadDuration(): Promise<void> {
    if (this.videoPath === '') {
      return;
    }
    let avPlayer: media.AVPlayer | undefined = undefined;
    let srcFile: fs.File | undefined = undefined;
    try {
      srcFile = fs.openSync(this.videoPath, fs.OpenMode.READ_ONLY);
      avPlayer = await media.createAVPlayer();
      avPlayer.on('stateChange', async (state: media.AVPlayerState) => {
        if (state === 'initialized') {
          await avPlayer?.prepare();
        } else if (state === 'prepared') {
          this.applyDuration(avPlayer?.duration ?? 0);
          try {
            avPlayer?.release();
          } catch (e) {
            hilog.warn(0x0000, TAG, 'release failed %{public}s', (e as Error).message);
          }
          if (srcFile !== undefined) {
            try {
              fs.closeSync(srcFile);
            } catch (e) {
              hilog.warn(0x0000, TAG, 'close fd failed %{public}s', (e as Error).message);
            }
          }
        }
      });
      avPlayer.on('error', (err: BusinessError) => {
        hilog.error(0x0000, TAG, 'avPlayer error code=%{public}d msg=%{public}s', err.code, err.message);
      });
      // 用文件描述符作为播放源（沙箱路径 file:// 在模拟器上被拒）
      avPlayer.fdSrc = { fd: srcFile.fd };
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'loadDuration failed code=%{public}d msg=%{public}s', e.code, e.message);
    }
  }

  /** Video 组件兜底：准备完成事件（模拟器 duration 可能返回假值，过滤） */
  private onVideoPrepared(durationMs: number): void {
    this.applyDuration(durationMs);
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
        durationSec: this.durationSec,
        speed: this.speed
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
          .onPrepared((event: PreparedInfo) => this.onVideoPrepared(event.duration))
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

        // 倍速选择
        Column({ space: 8 }) {
          Text('倍速')
            .fontSize(14)
          Row({ space: 10 }) {
            ForEach(this.speedOptions, (opt: number) => {
              Button(`${opt}x`)
                .width(64)
                .height(36)
                .fontSize(13)
                .backgroundColor(this.speed === opt ? '#0b57a4' : '#e8eef7')
                .fontColor(this.speed === opt ? Color.White : '#334')
                .type(ButtonType.Capsule)
                .onClick(() => this.speed = opt)
            }, (opt: number) => `${opt}`)
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      } else {
        Text('正在读取视频时长...')
          .fontSize(13)
          .fontColor('#889')
      }

      Text('导出支持：裁剪 + 倍速 + 压缩预设；拼接入口在下方')
        .fontSize(12)
        .fontColor('#889')

      Button('导出')
        .width(240)
        .enabled(this.durationSec > 0)
        .margin({ top: 8 })
        .onClick(() => this.goExport())

      Button('去拼接（D5）')
        .width(240)
        .onClick(() => {
          router.pushUrl({ url: 'pages/ClipMergePage' }).catch(() => undefined);
        })

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
