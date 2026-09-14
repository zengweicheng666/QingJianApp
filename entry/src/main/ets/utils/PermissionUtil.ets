import { abilityAccessCtrl, common, Permissions, BusinessError } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'QingJian';

/**
 * 权限申请工具：拍摄需要 相机 + 麦克风。
 * 相册读取使用系统安全相册选择器（无需权限），保存使用安全控件 SaveButton（无需权限）。
 */
export class PermissionUtil {
  static readonly CAMERA_PERMISSIONS: Array<Permissions> = [
    'ohos.permission.CAMERA',
    'ohos.permission.MICROPHONE'
  ];

  /**
   * 申请拍摄权限，返回是否全部授权。
   */
  static async requestCameraPermissions(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const result = await atManager.requestPermissionsFromUser(context, PermissionUtil.CAMERA_PERMISSIONS);
      const granted = result.authResults.every((r: number) => r === 0);
      hilog.info(0x0000, TAG, 'requestCameraPermissions granted=%{public}s', JSON.stringify(result.authResults));
      return granted;
    } catch (err) {
      const e = err as BusinessError;
      hilog.error(0x0000, TAG, 'requestCameraPermissions failed code=%{public}d msg=%{public}s', e.code, e.message);
      return false;
    }
  }
}
