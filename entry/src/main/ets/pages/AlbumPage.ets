import { router } from '@kit.ArkUI';

/**
 * 相册选择页（D2 填充）：
 * 使用系统安全相册选择器 photoAccessHelper.PhotoViewPicker 选择视频（免权限），
 * 选中后携带 uri 跳转编辑页。
 * 骨架阶段：仅占位，D2 实现 getPhotoViewPicker().select({ MIMEType: 'video/*' })。
 */
@Entry
@Component
struct AlbumPage {
  build() {
    Column({ space: 16 }) {
      Text('相册选择')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 32 })
      Text('D2 待实现：photoViewPicker 选择系统视频\n选中后进入编辑页')
        .fontSize(14)
        .fontColor('#667')
        .textAlign(TextAlign.Center)
        .margin({ top: 8 })
      Button('返回')
        .margin({ top: 24 })
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .height('100%')
  }
}
