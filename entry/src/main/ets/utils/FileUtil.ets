import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'QingJian';

/**
 * 文件工具：媒体 uri（相册 file://media/... 或文件管理 file://docs/...）→ 应用沙箱文件拷贝。
 * ffmpeg NAPI 只认真实文件路径，选择器返回的 uri 必须先落到沙箱。
 * fs.openSync 同时支持 media 与 docs 两种 file:// uri（SAF 授权后可直接读）。
 */
export class FileUtil {
  /** 将相册 uri 拷贝到沙箱，返回沙箱路径 */
  static copyUriToSandbox(uri: string, index: number): string {
    const dot = uri.lastIndexOf('.');
    const ext = dot >= 0 ? uri.substring(dot + 1) : 'mp4';
    const dest = `${getContext().filesDir}/media_${Date.now()}_${index}.${ext}`;
    const srcFile: fs.File = fs.openSync(uri, fs.OpenMode.READ_ONLY);
    const dstFile: fs.File = fs.openSync(dest, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    const srcFd = srcFile.fd;
    const dstFd = dstFile.fd;
    const buf = new ArrayBuffer(1 << 20); // 1MB 缓冲
    let offset = 0;
    try {
      while (true) {
        const read = fs.readSync(srcFd, buf, { offset: offset });
        if (read <= 0) {
          break;
        }
        fs.writeSync(dstFd, buf, { offset: offset, length: read });
        offset += read;
      }
    } finally {
      fs.closeSync(srcFd);
      fs.closeSync(dstFd);
    }
    hilog.info(0x0000, TAG, 'copied %{public}s -> %{public}s (%{public}d bytes)', uri, dest, offset);
    return dest;
  }
}
