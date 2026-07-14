import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/job.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void cycle() {
    state = switch (state) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Whether a usable FFmpeg is present (system binary on desktop, bundled on Android).
final ffmpegAvailableProvider = FutureProvider<bool>((ref) async {
  if (Platform.isAndroid) return true;
  try {
    final result = await Process.run('ffmpeg', ['-version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
});

class JobsNotifier extends Notifier<List<Job>> {
  int _nextId = 0;

  @override
  List<Job> build() => const [];

  int start(String category, String title) {
    final id = _nextId++;
    state = [
      ...state,
      Job(id: id, category: category, title: title, status: JobStatus.running),
    ];
    return id;
  }

  void _update(int id, Job Function(Job) change) {
    state = [
      for (final job in state)
        if (job.id == id) change(job) else job,
    ];
  }

  void progress(int id, double value) =>
      _update(id, (j) => j.copyWith(progress: value));

  void success(int id, {required String output, String? note}) => _update(
      id,
      (j) => j.copyWith(
          status: JobStatus.success,
          outputPath: output,
          detail: note,
          clearProgress: true));

  void fail(int id, Object error) => _update(
      id,
      (j) => j.copyWith(
          status: JobStatus.failure, detail: '$error', clearProgress: true));

  /// Removes finished jobs of one category.
  void clear(String category) {
    state = [
      for (final job in state)
        if (job.category != category || job.status == JobStatus.running) job,
    ];
  }
}

final jobsProvider =
    NotifierProvider<JobsNotifier, List<Job>>(JobsNotifier.new);
