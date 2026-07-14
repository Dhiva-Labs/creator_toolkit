import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/job.dart';
import '../providers/app_providers.dart';
import '../services/output_service.dart';

/// Live results list for one tool category.
class JobList extends ConsumerWidget {
  const JobList({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref
        .watch(jobsProvider)
        .where((job) => job.category == category)
        .toList()
        .reversed
        .toList();
    if (jobs.isEmpty) return const SizedBox.shrink();

    final hasFinished = jobs.any((j) => j.status != JobStatus.running);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Results', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            if (hasFinished)
              TextButton(
                onPressed: () =>
                    ref.read(jobsProvider.notifier).clear(category),
                child: const Text('Clear'),
              ),
          ],
        ),
        for (final job in jobs) _JobTile(job: job),
      ],
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;

    final (IconData icon, Color color) = switch (job.status) {
      JobStatus.running => (Icons.autorenew, scheme.primary),
      JobStatus.success => (Icons.check_circle_outline, scheme.primary),
      JobStatus.failure => (Icons.error_outline, scheme.error),
    };

    final subtitleLines = <String>[
      if (job.status == JobStatus.failure)
        job.detail ?? 'Failed'
      else ...[
        if (job.outputPath != null) job.outputPath!,
        if (job.detail != null) job.detail!,
      ],
    ];

    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(job.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis),
                ),
                if (job.status == JobStatus.success &&
                    desktop &&
                    job.outputPath != null)
                  IconButton(
                    tooltip: 'Show in folder',
                    icon: const Icon(Icons.folder_open_outlined, size: 20),
                    onPressed: () => OutputService.reveal(job.outputPath!),
                  ),
              ],
            ),
            if (job.status == JobStatus.running) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: job.progress,
                borderRadius: BorderRadius.circular(4),
              ),
              if (job.progress != null) ...[
                const SizedBox(height: 4),
                Text('${(job.progress! * 100).round()}%',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
            for (final line in subtitleLines)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 28),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: job.status == JobStatus.failure
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
