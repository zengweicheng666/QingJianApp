import {
  ffmpegSession,
  asyncFFmpegSessionExecute,
  enableFFmpegSessionCompleteCallback,
  abstractSessionGetReturnCode,
  abstractSessionGetAllLogsAsString,
  getFFmpegVersion
} from '@ohos/ffmpeg-kit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'QingJian';

export type CompressPreset = '480p' | '720p' | '1080p';

export interface CompressPresetSpec {
  width: number;
  height: number;
  bitrate: string;
}

const PRESET_MAP: Record<CompressPreset, CompressPresetSpec> = {
  '480p': { width: 854, height: 480, bitrate: '800k' },
  '720p': { width: 1280, height: 720, bitrate: '2M' },
  '1080p': { width: 1920, height: 1080, bitrate: '4M' }
};

export type ProgressCallback = (progressSeconds: number) => void;

/**
 * 视频处理器：基于 @ohos/ffmpeg-kit（1.0.1）的裁剪/压缩/拼接/倍速封装。
 * API：ffmpegSession(args) 创建会话 → asyncFFmpegSessionExecute 异步执行 →
 *      完成回调里用 abstractSessionGetReturnCode 判断结果，日志轮询解析 time= 进度。
 * 注意：MVP 串行调用（同一时间只跑一个转码任务）。
 */
export class VideoProcessor {
  private static callbackRegistered: boolean = false;
  private static activeSessionId: number | undefined = undefined;
  private static activeResolve: (() => void) | undefined = undefined;
  private static activeReject: ((err: Error) => void) | undefined = undefined;
  private static activeTimer: number | undefined = undefined;

  static version(): string {
    try {
      return getFFmpegVersion();
    } catch (e) {
      return 'unknown';
    }
  }

  /** 注册全局完成回调（仅一次），回调触发时驱动当前活动 Promise */
  private static ensureCallback(): void {
    if (VideoProcessor.callbackRegistered) {
      return;
    }
    VideoProcessor.callbackRegistered = true;
    enableFFmpegSessionCompleteCallback(() => {
      const sid = VideoProcessor.activeSessionId;
      if (sid === undefined) {
        return;
      }
      if (VideoProcessor.activeTimer !== undefined) {
        clearInterval(VideoProcessor.activeTimer);
        VideoProcessor.activeTimer = undefined;
      }
      const code = abstractSessionGetReturnCode(sid);
      if (code === 0) {
        hilog.info(0x0000, TAG, 'ffmpeg session %{public}d success', sid);
        VideoProcessor.activeResolve?.();
      } else {
        const logs = abstractSessionGetAllLogsAsString(sid, 0);
        const tail = logs.length > 600 ? logs.substring(logs.length - 600) : logs;
        hilog.error(0x0000, TAG, 'ffmpeg session %{public}d failed code=%{public}d', sid, code);
        VideoProcessor.activeReject?.(new Error(`ffmpeg 退出码 ${code}: ${tail}`));
      }
      VideoProcessor.activeSessionId = undefined;
      VideoProcessor.activeResolve = undefined;
      VideoProcessor.activeReject = undefined;
    });
  }

  /**
   * 执行一条 ffmpeg 命令（参数数组）。
   * @param args  ffmpeg 参数（不含开头的 "ffmpeg"）
   * @param onProgress 进度回调（秒，从日志 time= 解析）
   */
  static execute(args: Array<string>, onProgress?: ProgressCallback): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      try {
        VideoProcessor.ensureCallback();
        const session: Map<string, ESObject> = ffmpegSession(args);
        const sessionId: number = session.get('sessionId') as number;
        if (sessionId === undefined || sessionId === null || Number.isNaN(sessionId)) {
          reject(new Error('创建 ffmpeg 会话失败'));
          return;
        }
        hilog.info(0x0000, TAG, 'execute session=%{public}d cmd=%{public}s', sessionId, args.join(' '));
        VideoProcessor.activeSessionId = sessionId;
        VideoProcessor.activeResolve = resolve;
        VideoProcessor.activeReject = reject;
        if (onProgress !== undefined) {
          VideoProcessor.activeTimer = setInterval(() => {
            try {
              const logs = abstractSessionGetAllLogsAsString(sessionId, 0);
              const m = /time=(\d+):(\d+):([\d.]+)/.exec(logs);
              if (m !== null) {
                const sec = parseInt(m[1]) * 3600 + parseInt(m[2]) * 60 + parseFloat(m[3]);
                onProgress(sec);
              }
            } catch (e) {
              // 日志读取失败忽略，等完成回调兜底
            }
          }, 500);
        }
        asyncFFmpegSessionExecute(sessionId);
      } catch (e) {
        reject(e as Error);
      }
    });
  }

  /** 裁剪：精确 seek + 拷贝编码（快速、无损） */
  static clip(input: string, startSec: number, durSec: number, output: string,
    onProgress?: ProgressCallback): Promise<void> {
    const args: Array<string> = [
      '-y',
      '-ss', startSec.toFixed(2),
      '-i', input,
      '-t', durSec.toFixed(2),
      '-c', 'copy',
      output
    ];
    return VideoProcessor.execute(args, onProgress);
  }

  /** 压缩：按预设缩放 + libx264 重编码 */
  static compress(input: string, preset: CompressPreset, output: string,
    onProgress?: ProgressCallback): Promise<void> {
    const p = PRESET_MAP[preset];
    const args: Array<string> = [
      '-y',
      '-i', input,
      '-vf', `scale=${p.width}:${p.height}:force_original_aspect_ratio=decrease`,
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-b:v', p.bitrate,
      '-c:a', 'aac',
      '-b:a', '128k',
      '-movflags', '+faststart',
      output
    ];
    return VideoProcessor.execute(args, onProgress);
  }

  /**
   * 倍速（0.5x ~ 2x）：视频 setpts 变速 + 音频 atempo 变速保调。
   */
  static speed(input: string, rate: number, output: string, onProgress?: ProgressCallback): Promise<void> {
    const r = Math.min(2, Math.max(0.5, rate));
    const v = (1 / r).toFixed(3);
    const a = r.toFixed(3);
    const args: Array<string> = [
      '-y',
      '-i', input,
      '-filter_complex', `[0:v]setpts=${v}*PTS[v];[0:a]atempo=${a}[a]`,
      '-map', '[v]',
      '-map', '[a]',
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-c:a', 'aac',
      output
    ];
    return VideoProcessor.execute(args, onProgress);
  }

  /** 拼接（concat demuxer，要求各段编码一致；不一致时先转码统一） */
  static concat(listFilePath: string, output: string, onProgress?: ProgressCallback): Promise<void> {
    const args: Array<string> = [
      '-y',
      '-f', 'concat',
      '-safe', '0',
      '-i', listFilePath,
      '-c', 'copy',
      output
    ];
    return VideoProcessor.execute(args, onProgress);
  }

  /**
   * 拼接（主用）：filter_complex 动态拼接，统一缩放 720p 并重编码，
   * 兼容不同来源（相机/相册）编码与分辨率不一致的片段。
   */
  static concatFilter(inputs: Array<string>, output: string, onProgress?: ProgressCallback): Promise<void> {
    const n = inputs.length;
    if (n < 2) {
      return Promise.reject(new Error('拼接至少需要 2 段视频'));
    }
    const parts: Array<string> = [];
    const maps: Array<string> = [];
    for (let i = 0; i < n; i++) {
      parts.push(`[${i}:v]scale=1280:720:force_original_aspect_ratio=decrease,` +
        `pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1[v${i}];`);
      maps.push(`[v${i}][${i}:a]`);
    }
    const filter = `${parts.join('')}${maps.join('')}concat=n=${n}:v=1:a=1[vout][aout]`;
    const args: Array<string> = ['-y'];
    for (const p of inputs) {
      args.push('-i', p);
    }
    args.push(
      '-filter_complex', filter,
      '-map', '[vout]',
      '-map', '[aout]',
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-c:a', 'aac',
      output
    );
    return VideoProcessor.execute(args, onProgress);
  }
}
