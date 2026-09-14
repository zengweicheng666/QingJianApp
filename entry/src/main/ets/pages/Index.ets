import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CameraService } from '../services/CameraService';
import { PermissionUtil } from '../utils/PermissionUtil';

const TAG = 'QingJian';
const MAX_RECORD_SEC = 60;

/**
 * 首页：相机页（D1-D2 + D7 打磨）。
 * 预览 / 录像（60s 上限 + 倒计时）/ 拍照 / 前后切换 / 闪光灯 / 相册入口 / 权限拒绝引导。
 */
@Entry
@Component
struct Index {
  @State isRecording: boolean = false;
  @State isFront: boolean = false;
  @State flashLabel: string = '关';
  @State cameraReady: boolean = false;
  @State recordElapsed: number = 0;
  @State permissionDenied: boolean = false;
  private xComponentController: XComponentController = new XComponentController();
  private cameraService: CameraService | undefined = undefined;
  private surfaceId: string = '';
  private isInitializing: boolean = false;
  private recordTimer: number = -1;

  async aboutToAppear(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const granted = await PermissionUtil.requestCameraPermissions(context);
    if (!granted) {
      this.permissionDenied = true;
      return;
    }
    this.permissionDenied = false;
    this.cameraService = new CameraService(context);
  }

  onPageShow(): void {
    if (this.cameraService !== undefined && this.surfaceId !== '' && !this.isInitializing) {
      this.initCamera();
    }
  }

  onPageHide(): void {
    this.clearRecordTimer();
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

  private clearRecordTimer(): void {
    if (this.recordTimer !== -1) {
      clearInterval(this.recordTimer);
      this.recordTimer = -1;
    }
  }

  /** 停止录像并跳编辑页（共用：手动停止 / 60s 自动停止） */
  private async stopAndGoEdit(): Promise<void> {
    this.clearRecordTimer();
    if (this.cameraService === undefined) {
      this.isRecording = false;
      return;
    }
    const path = await this.cameraService.stopRecording();
    this.isRecording = false;
    this.recordElapsed = 0;
    if (path !== '') {
      router.pushUrl({
        url: 'pages/EditPage',
        params: { videoPath: path }
      }).catch((err: Error) => {
        hilog.error(0x0000, TAG, 'push EditPage failed %{public}s', err.message);
      });
    } else {
      promptAction.showToast({ message: '录像失败，请重试' });
    }
  }

  private async onRecordTap(): Promise<void> {
    if (this.cameraService === undefined) {
      return;
    }
    if (!this.isRecording) {
      const ok = await this.cameraService.startRecording();
      if (!ok) {
        promptAction.showToast({ message: '无法开始录像' });
        return;
      }
      this.isRecording = true;
      this.recordElapsed = 0;
      // 60s 上限倒计时
      this.recordTimer = setInterval(() => {
        this.recordElapsed += 1;
        if (this.recordElapsed >= MAX_RECORD_SEC) {
          promptAction.showToast({ message: '已达到 60 秒上限' });
          this.stopAndGoEdit();
        }
      }, 1000);
    } else {
      this.stopAndGoEdit();
    }
  }

  private async onPhotoTap(): Promise<void> {
    if (this.cameraService === undefined) {
      return;
    }
    const path = await this.cameraService.takePicture();
    if (path !== '') {
      promptAction.showToast({ message: '拍照成功（D2 接入相册保存）' });
    } else {
      promptAction.showToast({ message: '拍照失败，请重试' });
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

  private async reRequestPermission(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const granted = await PermissionUtil.requestCameraPermissions(context);
    if (granted) {
      this.permissionDenied = false;
      this.cameraService = new CameraService(context);
      if (this.surfaceId !== '') {
        this.initCamera();
      }
    } else {
      promptAction.showToast({ message: '未获得权限，请在系统设置中开启' });
    }
  }

  private goAlbum(): void {
    router.pushUrl({ url: 'pages/AlbumPage' }).catch(() => undefined);
  }

  private fmtRemain(): string {
    const remain = Math.max(0, MAX_RECORD_SEC - this.recordElapsed);
    const mm = Math.floor(remain / 60);
    const ss = remain % 60;
    return `${mm}:${ss.toString().padStart(2, '0')}`;
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
          if (!this.permissionDenied) {
            this.initCamera();
          }
        })
        .onDestroy(() => {
          this.clearRecordTimer();
          this.cameraService?.release();
        })

      // 权限拒绝引导
      if (this.permissionDenied) {
        Column({ space: 12 }) {
          Text('需要相机和麦克风权限才能拍摄')
            .fontSize(15)
            .fontColor(Color.White)
          Text('请在系统设置-应用-轻剪中开启相机与麦克风权限')
            .fontSize(12)
            .fontColor('#bbb')
          Button('重新申请权限')
            .width(180)
            .onClick(() => this.reRequestPermission())
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
        .position({ x: 0, y: '35%' })
        .alignItems(HorizontalAlign.Center)
      }

      // 顶部工具栏
      Row({ space: 16 }) {
        Text('相册')
          .fontSize(16)
          .fontColor(Color.White)
          .onClick(() => this.goAlbum())
        Blank()
        Text(`闪光 ${this.flashLabel}`)
          .fontSize(16)
          .fontColor(Color.White)
          .onClick(() => this.onToggleFlash())
        Text(this.isFront ? '前摄' : '后摄')
          .fontSize(16)
          .fontColor(Color.White)
          .onClick(() => this.onSwitchCamera())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16 })
      .alignItems(VerticalAlign.Top)
      .position({ x: 0, y: 0 })

      // 底部控制区
      Column({ space: 10 }) {
        Row({ space: 60 }) {
          // 拍照
          Column({ space: 6 }) {
            Button({ type: ButtonType.Circle })
              .width(60)
              .height(60)
              .backgroundColor(Color.White)
              .opacity(0.9)
              .onClick(() => this.onPhotoTap())
            Text('拍照')
              .fontSize(12)
              .fontColor(Color.White)
          }
          // 录像
          Column({ space: 6 }) {
            Button({ type: ButtonType.Circle })
              .width(this.isRecording ? 56 : 72)
              .height(this.isRecording ? 56 : 72)
              .backgroundColor(this.isRecording ? Color.Red : Color.White)
              .border({ width: 4, color: Color.White })
              .opacity(0.95)
              .onClick(() => this.onRecordTap())
            Text(this.isRecording ? '停止' : '录像')
              .fontSize(12)
              .fontColor(Color.White)
          }
        }
        .justifyContent(FlexAlign.Center)

        if (this.isRecording) {
          Text(`● 录制中 ${this.fmtRemain()}`)
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor('rgba(0,0,0,0.5)')
            .borderRadius(12)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        }
      }
      .width('100%')
      .padding({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
