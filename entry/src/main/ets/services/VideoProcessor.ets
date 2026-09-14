import { FFmpegKit, ReturnCode } from '@ohos/ffmpeg-kit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'QingJian';

export type CompressPreset = '480p' | '720p' | '1080p';

const PRESET_MAP: Record<CompressPreset, { width: number; height: number; bitrate: string }> = {
  '480p': { width: 854, height: 480, bitrate: '800k' },
  '720p': { width: 1280, height: 720, bitrate: '2M' },
  '1080p': { width: 1920, height: 1080, bitrate: '4M' }
};

export type ProgressCallback = (percent: number) => void;

/**
 * 视频处理封装（D3 已接入 @ohos/ffmpeg-kit）：
 * - 安装：在 entry 目录执行 `ohpm install @ohos/ffmpeg-kit`
 * - 进度：通过 ffmpeg 的 stderr 日志解析 `time=HH:MM:SS.xx` 推算百分比；
 *   若视频时长未知（无 duration），进度回调为 0~100 的估算值。
 */
export class VideoProcessor {
  /** 生成 concat 列表文件（拼接用），返回文件路径 */
  static createConcatList(inputs: Array<string>, listPath: string): void {
    const lines: Array<string> = inputs.map((p: string) => `file '${p.replaceAll("'", "'\\''")}'`);
    const fd = fs.openSync(listPath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(fd, lines.join('\n'));
    fs.closeSync(fd);
  }

  /**
   * 裁剪（统一重编码 libx264，保证起止点精确）。
   */
  static async clip(input: string, startSec: number, durSec: number, output: string,
    onProgress?: ProgressCallback): Promise<void> {
    const dur = Math.max(0.1, durSec);
    const cmd = `-y -ss ${startSec} -i ${input} -t ${dur} -c:v libx264 -preset veryfast -c:a aac ${output}`;
    return VideoProcessor.execute(cmd, onProgress);
  }

  /**
   * 拼接（concat demuxer，要求各段编码一致；不一致时先转码统一）。
   */
  static async concat(listFilePath: string, output: string, onProgress?: ProgressCallback): Promise<void> {
    const cmd = `-y -f concat -safe 0 -i ${listFilePath} -c copy ${output}`;
    return VideoProcessor.execute(cmd, onProgress);
  }

  /**
   * 压缩/转码：三档预设。
   */
  static async compress(input: string, preset: CompressPreset, output: string,
    onProgress?: ProgressCallback): Promise<void> {
    const p = PRESET_MAP[preset];
    const cmd =
      `-y -i ${input} -vf scale=${p.width}:${p.height} -b:v ${p.bitrate} -r 30 ` +
      `-c:v libx264 -preset veryfast -c:a aac ${output}`;
    return VideoProcessor.execute(cmd, onProgress);
  }

  /**
   * 统一执行入口：executeAsync 异步执行 + stderr 日志进度 + 返回码校验。
   */
  private static async execute(cmd: string, onProgress?: ProgressCallback): Promise<void> {
    hilog.info(0x0000, TAG, 'ffmpeg cmd: %{public}s', cmd);
    return new Promise<void>((resolve, reject) => {
      const session = FFmpegKit.executeAsync(cmd, (log) => {
        const msg = log.getMessage();
        hilog.debug(0x0000, TAG, '[ffmpeg] %{public}s', msg);
        // 解析进度：time=00:01:23.45
        const m = /time=(\d+):(\d+):([\d.]+)/.exec(msg);
        if (m !== null && onProgress !== undefined) {
          const secs = parseInt(m[1], 10) * 3600 + parseInt(m[2], 10) * 60 + parseFloat(m[3]);
          onProgress(Math.min(99, Math.floor(secs * 10))); // 估算进度（无总时长信息时）
        }
      });
      session.complete.then((stats) => {
        if (ReturnCode.isSuccess(stats.getReturnCode())) {
          if (onProgress !== undefined) {
            onProgress(100);
          }
          hilog.info(0x0000, TAG, 'ffmpeg ok');
          resolve();
        } else {
          const stack = stats.getFailStackTrace();
          hilog.error(0x0000, TAG, 'ffmpeg failed: %{public}s', stack);
          reject(new Error(`ffmpeg failed: ${stack}`));
        }
      }).catch((err: Error) => {
        hilog.error(0x0000, TAG, 'ffmpeg session error %{public}s', err.message);
        reject(err);
      });
    });
  }
}
