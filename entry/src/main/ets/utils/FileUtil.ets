import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'QingJian';

/**
 * 文件工具：相册 uri（file://media/...）→ 应用沙箱文件拷贝。
 * ffmpeg NAPI 只认真实文件路径，媒体库 uri 必须先落到沙箱。
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
