import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Warns when no FFmpeg binary is available (desktop only).
class FfmpegBanner extends ConsumerWidget {
  const FfmpegBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(ffmpegAvailableProvider).value ?? true;
    if (available) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'FFmpeg was not found on this system. Install it '
                '(Linux: "sudo apt install ffmpeg", Windows: add ffmpeg.exe to PATH) '
                'to use the video and audio tools.',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
