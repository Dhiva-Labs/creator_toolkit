import 'ffmpeg_service.dart';

/// Even-dimension guard: yuv420p encoders reject odd widths/heights.
const _evenScale = 'scale=trunc(iw/2)*2:trunc(ih/2)*2';

class VideoService {
  static const inputExtensions = [
    'mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v', 'wmv', 'flv', 'ts', 'mts', '3gp',
  ];
  static const convertFormats = ['mp4', 'mkv', 'mov', 'webm', 'gif'];

  /// H.264 re-encode; [crf] controls size/quality, [maxHeight] caps resolution.
  static Future<void> compress({
    required String inPath,
    required String outPath,
    int crf = 26,
    int? maxHeight,
    void Function(double)? onProgress,
  }) async {
    final total = await FfmpegService.probeDuration(inPath);
    final filter = maxHeight == null
        ? _evenScale
        : 'scale=-2:min($maxHeight\\,trunc(ih/2)*2)';
    await FfmpegService.run([
      '-i', inPath,
      '-vf', filter,
      '-c:v', 'libx264', '-crf', '$crf', '-preset', 'veryfast',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac', '-b:a', '128k',
      '-movflags', '+faststart',
      outPath,
    ], total: total, onProgress: onProgress);
  }

  /// Converts to the container/codec implied by [outPath]'s extension.
  static Future<void> convert({
    required String inPath,
    required String outPath,
    void Function(double)? onProgress,
  }) async {
    final total = await FfmpegService.probeDuration(inPath);
    final ext = outPath.split('.').last.toLowerCase();
    final args = switch (ext) {
      'webm' => [
          '-i', inPath,
          '-vf', _evenScale,
          '-c:v', 'libvpx-vp9', '-crf', '33', '-b:v', '0',
          '-row-mt', '1', '-cpu-used', '4',
          '-c:a', 'libopus', '-b:a', '128k',
          outPath,
        ],
      'gif' => [
          '-i', inPath,
          '-vf', 'fps=12,scale=480:-2',
          '-loop', '0', '-an',
          outPath,
        ],
      _ => [
          '-i', inPath,
          '-vf', _evenScale,
          '-c:v', 'libx264', '-crf', '23', '-preset', 'veryfast',
          '-pix_fmt', 'yuv420p',
          '-c:a', 'aac', '-b:a', '160k',
          if (ext == 'mp4' || ext == 'mov' || ext == 'm4v')
            ...['-movflags', '+faststart'],
          outPath,
        ],
    };
    await FfmpegService.run(args, total: total, onProgress: onProgress);
  }

  /// Cuts [start]..[end]. Stream copy is instant but snaps to keyframes;
  /// re-encoding is frame-accurate (output becomes MP4).
  static Future<void> trim({
    required String inPath,
    required String outPath,
    required Duration start,
    Duration? end,
    bool reencode = false,
    void Function(double)? onProgress,
  }) async {
    final total = await FfmpegService.probeDuration(inPath);
    Duration? outLength;
    final stop = end ?? total;
    if (stop != null && stop > start) outLength = stop - start;

    await FfmpegService.run([
      '-i', inPath,
      '-ss', _fmt(start),
      if (end != null) ...['-to', _fmt(end)],
      if (reencode) ...[
        '-vf', _evenScale,
        '-c:v', 'libx264', '-crf', '20', '-preset', 'veryfast',
        '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '160k',
        '-movflags', '+faststart',
      ] else ...[
        '-c', 'copy',
        '-avoid_negative_ts', 'make_zero',
      ],
      outPath,
    ], total: outLength, onProgress: onProgress);
  }

  static String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
