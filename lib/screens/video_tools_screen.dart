import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../providers/app_providers.dart';
import '../services/output_service.dart';
import '../services/video_service.dart';
import '../widgets/ffmpeg_banner.dart';
import '../widgets/file_drop_zone.dart';
import '../widgets/job_list.dart';
import '../widgets/option_widgets.dart';
import 'tool_mixin.dart';

class VideoToolsScreen extends StatelessWidget {
  const VideoToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Video Tools'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Compress'),
              Tab(text: 'Convert'),
              Tab(text: 'Trim'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_CompressTab(), _ConvertTab(), _TrimTab()],
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
  int _crf = 26;
  int? _maxHeight;

  Future<void> _process() => runJobs(
        category: 'video',
        task: (path, id) async {
          final out = await OutputService.suggest(path,
              suffix: '_compressed', ext: 'mp4');
          await VideoService.compress(
            inPath: path,
            outPath: out,
            crf: _crf,
            maxHeight: _maxHeight,
            onProgress: (v) =>
                ref.read(jobsProvider.notifier).progress(id, v),
          );
          return (out, sizeChange(path, out));
        },
      );

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        const FfmpegBanner(),
        FileDropZone(
            extensions: VideoService.inputExtensions, onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Compression (H.264 MP4)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quality', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              ChipSelector<int>(
                options: const {
                  20: 'High quality',
                  26: 'Balanced',
                  30: 'Smaller',
                  34: 'Smallest',
                },
                value: _crf,
                onChanged: (v) => setState(() => _crf = v),
              ),
              const SizedBox(height: 16),
              Text('Resolution cap',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              ChipSelector<int?>(
                options: const {
                  null: 'Original',
                  1080: '1080p',
                  720: '720p',
                  480: '480p',
                },
                value: _maxHeight,
                onChanged: (v) => setState(() => _maxHeight = v),
              ),
            ],
          ),
        ),
        ProcessButton(
          label: files.length > 1
              ? 'Compress ${files.length} videos'
              : 'Compress video',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'video'),
      ],
    );
  }
}

// ----------------------------------------------------------------- Convert

class _ConvertTab extends ConsumerStatefulWidget {
  const _ConvertTab();
  @override
  ConsumerState<_ConvertTab> createState() => _ConvertTabState();
}

class _ConvertTabState extends ConsumerState<_ConvertTab> with ToolProcessing {
  String _format = 'mp4';

  Future<void> _process() => runJobs(
        category: 'video',
        title: (path) => '${p.basename(path)} → ${_format.toUpperCase()}',
        task: (path, id) async {
          final out = await OutputService.suggest(path, ext: _format);
          await VideoService.convert(
            inPath: path,
            outPath: out,
            onProgress: (v) =>
                ref.read(jobsProvider.notifier).progress(id, v),
          );
          return (out, null);
        },
      );

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        const FfmpegBanner(),
        FileDropZone(
            extensions: VideoService.inputExtensions, onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Output format',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChipSelector<String>(
                options: {
                  for (final format in VideoService.convertFormats)
                    format: format.toUpperCase()
                },
                value: _format,
                onChanged: (v) => setState(() => _format = v),
              ),
              if (_format == 'gif')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'GIF export uses 12 fps at 480 px wide.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        ProcessButton(
          label: files.length > 1
              ? 'Convert ${files.length} videos'
              : 'Convert video',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'video'),
      ],
    );
  }
}

// -------------------------------------------------------------------- Trim

class _TrimTab extends ConsumerStatefulWidget {
  const _TrimTab();
  @override
  ConsumerState<_TrimTab> createState() => _TrimTabState();
}

class _TrimTabState extends ConsumerState<_TrimTab> with ToolProcessing {
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  bool _reencode = false;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Duration? _parseTime(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length > 3) return null;
    double seconds = 0;
    for (final part in parts) {
      final value = double.tryParse(part);
      if (value == null || value < 0) return null;
      seconds = seconds * 60 + value;
    }
    return Duration(milliseconds: (seconds * 1000).round());
  }

  Future<void> _process() async {
    final start = _parseTime(_startController.text) ?? Duration.zero;
    final end = _parseTime(_endController.text);
    if (_endController.text.trim().isNotEmpty && end == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('End time not understood — use 90, 1:30 or 0:01:30')));
      return;
    }
    if (end != null && end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time')));
      return;
    }
    await runJobs(
      category: 'video',
      task: (path, id) async {
        final out = await OutputService.suggest(path,
            suffix: '_trimmed',
            ext: _reencode
                ? 'mp4'
                : p.extension(path).replaceFirst('.', '').toLowerCase());
        await VideoService.trim(
          inPath: path,
          outPath: out,
          start: start,
          end: end,
          reencode: _reencode,
          onProgress: (v) => ref.read(jobsProvider.notifier).progress(id, v),
        );
        return (out, null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        const FfmpegBanner(),
        FileDropZone(
          extensions: VideoService.inputExtensions,
          multiple: false,
          onAdded: (paths) => addFiles(paths, single: true),
        ),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Trim range',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _startController,
                      decoration: const InputDecoration(
                          labelText: 'Start', hintText: '0:00'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('→'),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _endController,
                      decoration: const InputDecoration(
                          labelText: 'End', hintText: 'end of video'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Frame-accurate cut (re-encode)'),
                subtitle: const Text(
                    'Off: instant cut at the nearest keyframe, original quality'),
                value: _reencode,
                onChanged: (v) => setState(() => _reencode = v),
              ),
            ],
          ),
        ),
        ProcessButton(
          label: 'Trim video',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'video'),
      ],
    );
  }
}
