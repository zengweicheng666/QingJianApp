import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CameraService } from '../services/CameraService';
import { PermissionUtil } from '../utils/PermissionUtil';

const TAG = 'QingJian';

/**
 * 首页：相机页（D1-D2）。
 * 预览 / 录像 / 拍照 / 前后切换 / 闪光灯 / 相册入口。
 */
@Entry
@Component
struct Index {
  @State isRecording: boolean = false;
  @State isFront: boolean = false;
  @State flashLabel: string = '关';
  @State cameraReady: boolean = false;
  @State lastVideoPath: string = '';
  @State lastPhotoPath: string = '';
  private xComponentController: XComponentController = new XComponentController();
  private cameraService: CameraService | undefined = undefined;
  private surfaceId: string = '';
  private isInitializing: boolean = false;

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const granted = await PermissionUtil.requestCameraPermissions(context);
    if (!granted) {
      promptAction.showToast({ message: '需要相机和麦克风权限才能拍摄' });
      return;
    }
    this.cameraService = new CameraService(context);
  }

  onPageShow(): void {
    // 从编辑页返回时重新拉起预览
    if (this.cameraService !== undefined && this.surfaceId !== '' && !this.isInitializing) {
      this.initCamera();
    }
  }

  onPageHide(): void {
    this.cameraService?.release();
  }

  private initCamera(): void {
    if (this.isInitializing || this.cameraService === undefined) {
      return;
    }
    this.isInitializing = true;
    this.cameraService.init(this.surfaceId).then(() => {
      this.cameraReady = true;
      this.isInitializing = false;
    });
  }

  private async onRecordTap(): Promise<void> {
    if (this.cameraService === undefined) {
      return;
    }
    if (!this.isRecording) {
      const ok = await this.cameraService.startRecording();
      if (ok) {
        this.isRecording = true;
      }
    } else {
      const path = await this.cameraService.stopRecording();
      this.isRecording = false;
      if (path !== '') {
        this.lastVideoPath = path;
        // 拍完自动进入编辑页（MVP 核心闭环）
        router.pushUrl({
          url: 'pages/EditPage',
          params: { videoPath: path }
        }).catch((err: Error) => {
          hilog.error(0x0000, TAG, 'push EditPage failed %{public}s', err.message);
        });
      }
    }
  }

  private async onPhotoTap(): Promise<void> {
    if (this.cameraService === undefined) {
      return;
    }
    const path = await this.cameraService.takePicture();
    if (path !== '') {
      this.lastPhotoPath = path;
      promptAction.showToast({ message: '拍照成功（D2 接入相册保存）' });
    }
  }

  private async onSwitchCamera(): Promise<void> {
    if (this.cameraService === undefined || this.surfaceId === '') {
      return;
    }
    this.isFront = !this.isFront;
    await this.cameraService.switchCamera(this.surfaceId);
  }

  private async onToggleFlash(): Promise<void> {
    if (this.cameraService === undefined) {
      return;
    }
    const mode = await this.cameraService.toggleFlash();
    this.flashLabel = mode === 0 ? '关' : mode === 1 ? '开' : '自动';
  }

  private goAlbum(): void {
    router.pushUrl({ url: 'pages/AlbumPage' }).catch(() => undefined);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 相机预览
      XComponent({
        id: 'cameraPreview',
        type: XComponentType.SURFACE,
        controller: this.xComponentController
      })
        .width('100%')
        .height('100%')
        .onLoad(() => {
          this.surfaceId = this.xComponentController.getXComponentSurfaceId();
          this.initCamera();
        })
        .onDestroy(() => {
          this.cameraService?.release();
        })

      // 顶部工具栏
      Row({ space: 16 }) {
        Text('相册')
          .fontSize(16)
          .fontColor(Color.White)
          .onClick(() => this.goAlbum())
        Blank()
        Text(this.flashLabel)
          .fontSize(16)
          .fontColor(Color.White)
          .onClick(() => this.onToggleFlash())
        Text(this.isFront ? '前' : '后')
          .fontSize(16)
          .fontColor(Color.White)
          .onClick(() => this.onSwitchCamera())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })
      .alignItems(VerticalAlign.Top)
      .position({ x: 0, y: 0 })

      // 底部控制区
      Row({ space: 40 }) {
        // 拍照
        Button({ type: ButtonType.Circle })
          .width(64)
          .height(64)
          .backgroundColor(Color.White)
          .opacity(0.9)
          .onClick(() => this.onPhotoTap())
          .shadow({ radius: 8, color: 'rgba(0,0,0,0.3)' })
        // 录像
        Button({ type: ButtonType.Circle })
          .width(this.isRecording ? 56 : 76)
          .height(this.isRecording ? 56 : 76)
          .backgroundColor(this.isRecording ? Color.Red : Color.White)
          .border({ width: 4, color: Color.White })
          .opacity(0.95)
          .onClick(() => this.onRecordTap())
          .shadow({ radius: 10, color: 'rgba(0,0,0,0.35)' })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 48 })

      if (this.isRecording) {
        Text('● 录制中')
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor('rgba(0,0,0,0.5)')
          .borderRadius(12)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .position({ x: '40%', y: '46%' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
