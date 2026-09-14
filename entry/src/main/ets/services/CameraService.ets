import { common } from '@kit.AbilityKit';
import { camera } from '@kit.CameraKit';
import { media } from '@kit.MediaKit';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'QingJian';

/**
 * 相机生命周期封装（API 26 / DevEco 26.0.0）：
 * 预览 / 录像（AVRecorder 落盘 mp4）/ 拍照（ImageReceiver 取 JPEG 保存沙箱）/ 前后切换 / 闪光灯 / 释放
 * 使用前必须先完成权限申请（PermissionUtil）。
 */
export class CameraService {
  private context: common.UIAbilityContext;
  private cameraManager: camera.CameraManager | undefined = undefined;
  private cameraInput: camera.CameraInput | undefined = undefined;
  private previewOutput: camera.PreviewOutput | undefined = undefined;
  private videoOutput: camera.VideoOutput | undefined = undefined;
  private photoOutput: camera.PhotoOutput | undefined = undefined;
  private session: camera.CaptureSession | undefined = undefined;
  private avRecorder: media.AVRecorder | undefined = undefined;
  private videoFd: number = -1;
  private videoFilePath: string = '';
  private imageReceiver: image.ImageReceiver | undefined = undefined;
  private cameraIndex: number = 0; // 0 后摄，1 前摄
  private isRecording: boolean = false;
  private flashMode: camera.FlashMode = camera.FlashMode.FLASH_MODE_CLOSE;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * 初始化相机并开始预览。
   * @param previewSurfaceId XComponent 提供的 surfaceId
   */
  async init(previewSurfaceId: string): Promise<void> {
    try {
      this.cameraManager = camera.getCameraManager(this.context);
      await this.createAndStartSession(previewSurfaceId);
      hilog.info(0x0000, TAG, 'camera init done');
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'camera init failed code=%{public}d msg=%{public}s', e.code, e.message);
    }
  }

  /** 以当前 cameraIndex 创建输入流、输出流并启动会话 */
  private async createAndStartSession(previewSurfaceId: string): Promise<void> {
    if (this.cameraManager === undefined) {
      return;
    }
    // 若已有会话先停止并释放
    await this.releaseSession();

    const cameras: Array<camera.CameraDevice> = this.cameraManager.getSupportedCameras();
    if (cameras.length === 0) {
      hilog.error(0x0000, TAG, 'no camera device');
      return;
    }
    const device: camera.CameraDevice = cameras[Math.min(this.cameraIndex, cameras.length - 1)];

    // 1. 输入流
    this.cameraInput = this.cameraManager.createCameraInput(device);
    await this.cameraInput.open();

    // 2. 输出能力
    const capability: camera.CameraOutputCapability =
      this.cameraManager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);

    // 3. 预览输出
    const previewProfile: camera.Profile = capability.previewProfiles[0];
    this.previewOutput = this.cameraManager.createPreviewOutput(previewProfile, previewSurfaceId);

    // 4. 录像输出（AVRecorder surface）—— 失败不影响预览
    this.avRecorder = await media.createAVRecorder();
    this.videoFilePath = `${this.context.filesDir}/qingjian_rec_${Date.now()}.mp4`;
    const videoFile: fs.File = fs.openSync(this.videoFilePath,
      fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    this.videoFd = videoFile.fd;
    const videoProfile: camera.VideoProfile = capability.videoProfiles[0];
    const avConfig: media.AVRecorderConfig = {
      audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
      videoSourceType: media.VideoSourceType.VIDEO_SOURCE_TYPE_SURFACE_ES,
      profile: {
        audioBitrate: 96000,
        audioChannels: 2,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 48000,
        fileFormat: media.ContainerFormatType.CFT_MPEG_4,
        videoBitrate: 8000000,
        videoCodec: media.CodecMimeType.VIDEO_AVC,
        videoFrameWidth: videoProfile.size.width,
        videoFrameHeight: videoProfile.size.height,
        videoFrameRate: 30
      },
      url: `fd://${this.videoFd}`,
      rotation: 0,
      location: undefined
    };
    await this.avRecorder.prepare(avConfig);
    const inputSurface: string = await this.avRecorder.getInputSurface();
    this.videoOutput = this.cameraManager.createVideoOutput(videoProfile, inputSurface);

    // 5. 拍照输出（ImageReceiver 接收 JPEG，不占预览 surface）
    this.imageReceiver = image.createImageReceiver(videoProfile.size.width, videoProfile.size.height,
      image.ImageFormat.JPEG, 2);
    const photoSurface: string = await this.imageReceiver.getReceivingSurfaceId();
    this.photoOutput = this.cameraManager.createPhotoOutput(capability.photoProfiles[0], photoSurface);

    // 6. 会话组装（API 26 统一 addOutput；CaptureSession 提供闪光灯等能力）
    this.session = this.cameraManager.createCaptureSession();
    this.session.addInput(this.cameraInput);
    this.session.addOutput(this.previewOutput);
    this.session.addOutput(this.videoOutput);
    this.session.addOutput(this.photoOutput);
    await this.session.commitConfig();
    await this.session.start();

    // 7. 恢复上次闪光灯设置
    this.applyFlashMode(this.flashMode);
  }

  /** 开始录像 */
  async startRecording(): Promise<boolean> {
    if (this.avRecorder === undefined || this.isRecording) {
      return false;
    }
    try {
      await this.avRecorder.start();
      this.isRecording = true;
      return true;
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'startRecording failed code=%{public}d msg=%{public}s', e.code, e.message);
      return false;
    }
  }

  /** 停止录像，返回视频文件路径（后续交给编辑页/ffmpeg） */
  async stopRecording(): Promise<string> {
    if (this.avRecorder === undefined || !this.isRecording) {
      return '';
    }
    try {
      await this.avRecorder.stop();
      await this.avRecorder.release();
      this.avRecorder = undefined;
      this.isRecording = false;
      return this.videoFilePath;
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'stopRecording failed code=%{public}d msg=%{public}s', e.code, e.message);
      return '';
    }
  }

  /** 拍照：从 ImageReceiver 取 JPEG 保存到沙箱，返回路径 */
  async takePicture(): Promise<string> {
    if (this.photoOutput === undefined || this.imageReceiver === undefined) {
      return '';
    }
    try {
      await this.photoOutput.capture();
      const img: image.Image = await this.imageReceiver.readNextImage();
      const component: image.Component = await img.getComponent(image.ComponentType.JPEG);
      const buffer: ArrayBuffer = component.byteBuffer;
      const outPath = `${this.context.filesDir}/qingjian_photo_${Date.now()}.jpg`;
      const outFile: fs.File = fs.openSync(outPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(outFile.fd, buffer);
      fs.closeSync(outFile.fd);
      await img.release();
      return outPath;
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'takePicture failed code=%{public}d msg=%{public}s', e.code, e.message);
      return '';
    }
  }

  /** 切换前后摄 */
  async switchCamera(previewSurfaceId: string): Promise<void> {
    this.cameraIndex = this.cameraIndex === 0 ? 1 : 0;
    await this.createAndStartSession(previewSurfaceId);
  }

  /** 循环切换闪光灯：关 -> 开 -> 自动 */
  async toggleFlash(): Promise<camera.FlashMode> {
    const next: camera.FlashMode =
      this.flashMode === camera.FlashMode.FLASH_MODE_CLOSE
        ? camera.FlashMode.FLASH_MODE_OPEN
        : this.flashMode === camera.FlashMode.FLASH_MODE_OPEN
          ? camera.FlashMode.FLASH_MODE_AUTO
          : camera.FlashMode.FLASH_MODE_CLOSE;
    this.flashMode = next;
    this.applyFlashMode(next);
    return next;
  }

  private applyFlashMode(mode: camera.FlashMode): void {
    if (this.session === undefined) {
      return;
    }
    try {
      if (this.session.hasFlash() && this.session.isFlashModeSupported(mode)) {
        this.session.setFlashMode(mode);
      }
    } catch (err) {
      hilog.warn(0x0000, TAG, 'applyFlashMode failed');
    }
  }

  /** 释放相机资源（页面离开/销毁时必须调用） */
  async release(): Promise<void> {
    try {
      if (this.isRecording && this.avRecorder !== undefined) {
        await this.avRecorder.stop();
      }
    } catch (err) {
      // 忽略停止异常
    }
    this.isRecording = false;
    if (this.avRecorder !== undefined) {
      await this.avRecorder.release().catch(() => undefined);
      this.avRecorder = undefined;
    }
    if (this.videoFd !== -1) {
      fs.closeSync(this.videoFd);
      this.videoFd = -1;
    }
    await this.releaseSession();
    hilog.info(0x0000, TAG, 'camera released');
  }

  private async releaseSession(): Promise<void> {
    try {
      if (this.session !== undefined) {
        await this.session.stop();
        await this.session.release();
        this.session = undefined;
      }
    } catch (err) {
      hilog.warn(0x0000, TAG, 'release session warn');
    }
    try {
      if (this.cameraInput !== undefined) {
        await this.cameraInput.close();
        this.cameraInput = undefined;
      }
    } catch (err) {
      hilog.warn(0x0000, TAG, 'release input warn');
    }
    this.previewOutput = undefined;
    this.videoOutput = undefined;
    this.photoOutput = undefined;
  }
}
