import 'ffmpeg_service.dart';

class AudioService {
  static const inputExtensions = [
    'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus', 'wma', 'aiff',
  ];
  static const lossyFormats = ['mp3', 'm4a', 'ogg'];
  static const convertFormats = ['mp3', 'm4a', 'wav', 'flac', 'ogg'];

  /// Re-encodes to a lossy format at [bitrateKbps].
  static Future<void> compress({
    required String inPath,
    required String outPath,
    int bitrateKbps = 128,
    void Function(double)? onProgress,
  }) =>
      convert(
        inPath: inPath,
        outPath: outPath,
        bitrateKbps: bitrateKbps,
        onProgress: onProgress,
      );

  /// Converts to the format implied by [outPath]'s extension.
  static Future<void> convert({
    required String inPath,
    required String outPath,
    int bitrateKbps = 192,
    void Function(double)? onProgress,
  }) async {
    final total = await FfmpegService.probeDuration(inPath);
    final ext = outPath.split('.').last.toLowerCase();
    final codecArgs = switch (ext) {
      'mp3' => ['-c:a', 'libmp3lame', '-b:a', '${bitrateKbps}k'],
      'm4a' => ['-c:a', 'aac', '-b:a', '${bitrateKbps}k'],
      'ogg' => ['-c:a', 'libvorbis', '-b:a', '${bitrateKbps}k'],
      'wav' => ['-c:a', 'pcm_s16le'],
      'flac' => ['-c:a', 'flac'],
      _ => ['-b:a', '${bitrateKbps}k'],
    };
    await FfmpegService.run(
      ['-i', inPath, '-vn', ...codecArgs, outPath],
      total: total,
      onProgress: onProgress,
    );
  }
}
