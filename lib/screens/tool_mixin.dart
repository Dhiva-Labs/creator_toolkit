import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../providers/app_providers.dart';
import '../services/output_service.dart';

/// File selection + sequential job running shared by every tool tab.
mixin ToolProcessing<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final List<String> files = [];
  bool busy = false;

  void addFiles(List<String> paths, {bool single = false}) {
    setState(() {
      if (single) {
        files
          ..clear()
          ..add(paths.first);
        return;
      }
      for (final path in paths) {
        if (!files.contains(path)) files.add(path);
      }
    });
  }

  void removeFile(int index) => setState(() => files.removeAt(index));

  void clearFiles() => setState(() => files.clear());

  /// Runs [task] for each selected file, tracking each as a job.
  /// [task] returns (outputPath, note).
  Future<void> runJobs({
    required String category,
    required Future<(String, String?)> Function(String path, int jobId) task,
    String Function(String path)? title,
  }) async {
    if (files.isEmpty || busy) return;
    setState(() => busy = true);
    final jobs = ref.read(jobsProvider.notifier);
    for (final path in List.of(files)) {
      final id = jobs.start(category, title?.call(path) ?? p.basename(path));
      try {
        final (output, note) = await task(path, id);
        jobs.success(id, output: output, note: note);
      } catch (error) {
        jobs.fail(id, error);
      }
    }
    if (mounted) setState(() => busy = false);
  }
}

/// "1.4 MB → 320 KB" note for before/after file sizes.
String sizeChange(String inPath, String outPath) {
  final before = File(inPath).lengthSync();
  final after = File(outPath).lengthSync();
  return '${OutputService.formatBytes(before)} → ${OutputService.formatBytes(after)}';
}
