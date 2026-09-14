import { router } from '@kit.ArkUI';

/**
 * 编辑页（D3-D4 填充）：
 * Video 播放器 + 裁剪起止时间滑块 + 拼接片段列表 + 导出设置。
 * 骨架阶段：读取路由参数 videoPath 展示播放器与入口占位。
 */
@Entry
@Component
struct EditPage {
  @State videoPath: string = '';
  @State durationSec: number = 0;
  private videoController: VideoController = new VideoController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params !== undefined && params.videoPath !== undefined) {
      this.videoPath = params.videoPath;
    }
  }

  private goExport(): void {
    router.pushUrl({
      url: 'pages/ExportPage',
      params: { videoPath: this.videoPath }
    }).catch((err: Error) => {
      console.error('push ExportPage failed ' + err.message);
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

      Text('D3 待实现：裁剪起止时间滑块（最小 1s）')
        .fontSize(13)
        .fontColor('#889')
      Text('D5 待实现：拼接多段列表 + 顺序调整')
        .fontSize(13)
        .fontColor('#889')

      Button('导出')
        .width(240)
        .margin({ top: 16 })
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
