import { router } from '@kit.ArkUI';

/**
 * 导出页（D4-D6 填充）：
 * 分辨率/码率选项 + ffmpeg 进度条 + 保存相册（SaveButton 安全控件免权限）。
 * 骨架阶段：占位。
 */
@Entry
@Component
struct ExportPage {
  @State progress: number = 0;
  @State statusText: string = '待开始';

  build() {
    Column({ space: 16 }) {
      Text('导出')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 32 })

      Text('D4 待实现：裁剪/转码执行 + 进度回调')
        .fontSize(13)
        .fontColor('#889')
      Text('D6 待实现：480p/720p/1080p 预设 + 保存相册')
        .fontSize(13)
        .fontColor('#889')

      Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
        .width('80%')
        .color('#0b57a4')

      Text(this.statusText)
        .fontSize(14)

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
