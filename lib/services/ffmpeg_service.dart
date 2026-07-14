import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

class FfmpegException implements Exception {
  FfmpegException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runs FFmpeg: the bundled ffmpeg-kit on Android, the system binary on desktop.
class FfmpegService {
  static final _timeRe = RegExp(r'time=(\d+):(\d+):(\d+(?:\.\d+)?)');

  static Future<Duration?> probeDuration(String path) async {
    double? seconds;
    if (Platform.isAndroid) {
      final session = await FFprobeKit.getMediaInformation(path);
      seconds =
          double.tryParse(session.getMediaInformation()?.getDuration() ?? '');
    } else {
      try {
        final result = await Process.run('ffprobe', [
          '-v', 'error',
          '-show_entries', 'format=duration',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          path,
        ]);
        seconds = double.tryParse((result.stdout as String).trim());
      } on ProcessException {
        return null;
      }
    }
    if (seconds == null) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Runs ffmpeg with [args] (no leading binary name). Reports progress as
  /// 0..1 through [onProgress] when [total] is known.
  static Future<void> run(
    List<String> args, {
    Duration? total,
    void Function(double progress)? onProgress,
  }) {
    final fullArgs = ['-hide_banner', '-y', ...args];
    final totalMs = total?.inMilliseconds;

    void report(num ms) {
      if (onProgress != null && totalMs != null && totalMs > 0) {
        onProgress((ms / totalMs).clamp(0.0, 1.0).toDouble());
      }
    }

    if (Platform.isAndroid) {
      final completer = Completer<void>();
      FFmpegKit.executeWithArgumentsAsync(fullArgs, (session) async {
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc)) {
          completer.complete();
        } else {
          final logs = await session.getAllLogsAsString() ?? '';
          completer.completeError(
              FfmpegException(_tail(logs, fallback: 'FFmpeg failed')));
        }
      }, null, (stats) => report(stats.getTime()));
      return completer.future;
    }
    return _runDesktop(fullArgs, report);
  }

  static Future<void> _runDesktop(
      List<String> args, void Function(num ms) report) async {
    final Process process;
    try {
      process = await Process.start('ffmpeg', args);
    } on ProcessException {
      throw FfmpegException(
          'FFmpeg not found. Install it (e.g. "sudo apt install ffmpeg") and retry.');
    }
    final stderrBuffer = StringBuffer();
    process.stdout.drain<void>();
    final done = process.stderr
        .transform(const SystemEncoding().decoder)
        .forEach((chunk) {
      stderrBuffer.write(chunk);
      final match = _timeRe.allMatches(chunk).lastOrNull;
      if (match != null) {
        report(((int.parse(match[1]!) * 3600 +
                    int.parse(match[2]!) * 60 +
                    double.parse(match[3]!)) *
                1000)
            .round());
      }
    });
    final exitCode = await process.exitCode;
    await done;
    if (exitCode != 0) {
      throw FfmpegException(
          _tail(stderrBuffer.toString(), fallback: 'FFmpeg failed'));
    }
  }

  static String _tail(String log, {required String fallback}) {
    final lines = log
        .trim()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return fallback;
    return lines.length <= 4 ? lines.join('\n') : lines.sublist(lines.length - 4).join('\n');
  }
}
