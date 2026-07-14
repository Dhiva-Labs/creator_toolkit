import 'package:flutter/foundation.dart';

enum JobStatus { running, success, failure }

@immutable
class Job {
  const Job({
    required this.id,
    required this.category,
    required this.title,
    required this.status,
    this.progress,
    this.outputPath,
    this.detail,
  });

  final int id;
  final String category;
  final String title;
  final JobStatus status;

  /// 0..1 while running, or null for indeterminate.
  final double? progress;

  /// Where the result was written (file or folder).
  final String? outputPath;

  /// Extra note on success, or the error message on failure.
  final String? detail;

  Job copyWith({
    JobStatus? status,
    double? progress,
    String? outputPath,
    String? detail,
    bool clearProgress = false,
  }) {
    return Job(
      id: id,
      category: category,
      title: title,
      status: status ?? this.status,
      progress: clearProgress ? null : (progress ?? this.progress),
      outputPath: outputPath ?? this.outputPath,
      detail: detail ?? this.detail,
    );
  }
}
