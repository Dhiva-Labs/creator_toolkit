import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../providers/app_providers.dart';
import '../services/output_service.dart';
import '../services/pdf_service.dart';
import '../widgets/file_drop_zone.dart';
import '../widgets/job_list.dart';
import '../widgets/option_widgets.dart';
import 'tool_mixin.dart';

class PdfToolsScreen extends StatelessWidget {
  const PdfToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PDF Tools'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Compress'),
              Tab(text: 'Merge'),
              Tab(text: 'Split'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_CompressTab(), _MergeTab(), _SplitTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Compress

class _CompressTab extends ConsumerStatefulWidget {
  const _CompressTab();
  @override
  ConsumerState<_CompressTab> createState() => _CompressTabState();
}

class _CompressTabState extends ConsumerState<_CompressTab>
    with ToolProcessing {
  Future<void> _process() => runJobs(
        category: 'pdf',
        task: (path, id) async {
          final out = await OutputService.suggest(path, suffix: '_compressed');
          final (before, after) =
              await PdfService.compress(inPath: path, outPath: out);
          return (
            out,
            '${OutputService.formatBytes(before)} → ${OutputService.formatBytes(after)}'
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        FileDropZone(extensions: const ['pdf'], onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Compression',
          child: Text(
            'Rebuilds the PDF with maximum stream compression. '
            'Documents that are mostly large scanned images may shrink only a little.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        ProcessButton(
          label: files.length > 1
              ? 'Compress ${files.length} PDFs'
              : 'Compress PDF',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'pdf'),
      ],
    );
  }
}

// ------------------------------------------------------------------- Merge

class _MergeTab extends ConsumerStatefulWidget {
  const _MergeTab();
  @override
  ConsumerState<_MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends ConsumerState<_MergeTab> with ToolProcessing {
  Future<void> _process() async {
    if (files.length < 2 || busy) return;
    setState(() => busy = true);
    final jobs = ref.read(jobsProvider.notifier);
    final id = jobs.start('pdf', 'Merge ${files.length} PDFs');
    try {
      final out =
          await OutputService.suggest(files.first, suffix: '_merged');
      final pages =
          await PdfService.merge(inPaths: List.of(files), outPath: out);
      jobs.success(id, output: out, note: '$pages pages');
    } catch (error) {
      jobs.fail(id, error);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        FileDropZone(extensions: const ['pdf'], onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Merge order',
          child: Text(
            'PDFs are combined in the order they were added. '
            'Remove and re-add a file to change its position.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        ProcessButton(
          label: 'Merge ${files.length} PDFs',
          busy: busy,
          enabled: files.length >= 2,
          onPressed: _process,
        ),
        const JobList(category: 'pdf'),
      ],
    );
  }
}

// ------------------------------------------------------------------- Split

class _SplitTab extends ConsumerStatefulWidget {
  const _SplitTab();
  @override
  ConsumerState<_SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends ConsumerState<_SplitTab> with ToolProcessing {
  bool _everyPage = true;
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _process() async {
    int? from;
    int? to;
    if (!_everyPage) {
      from = int.tryParse(_fromController.text.trim());
      to = int.tryParse(_toController.text.trim());
      if (from == null || to == null || from < 1 || to < from) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enter a valid page range, e.g. 2 to 5')));
        return;
      }
    }
    await runJobs(
      category: 'pdf',
      task: (path, id) async {
        if (_everyPage) {
          final dir = await OutputService.suggestDir(
              '${p.basenameWithoutExtension(path)}_pages');
          final count =
              await PdfService.splitAll(inPath: path, outDir: dir.path);
          return (dir.path, '$count single-page PDFs');
        }
        final out =
            await OutputService.suggest(path, suffix: '_p$from-$to');
        final count = await PdfService.extractRange(
            inPath: path, outPath: out, from: from!, to: to!);
        return (out, '$count pages');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        FileDropZone(
          extensions: const ['pdf'],
          multiple: false,
          onAdded: (paths) => addFiles(paths, single: true),
        ),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Split mode',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('Every page'),
                      icon: Icon(Icons.grid_view_outlined)),
                  ButtonSegment(
                      value: false,
                      label: Text('Page range'),
                      icon: Icon(Icons.content_cut)),
                ],
                selected: {_everyPage},
                onSelectionChanged: (selection) =>
                    setState(() => _everyPage = selection.first),
              ),
              if (!_everyPage)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _fromController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'From page'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('→'),
                      ),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _toController,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'To page'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        ProcessButton(
          label: _everyPage ? 'Split into pages' : 'Extract pages',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'pdf'),
      ],
    );
  }
}
