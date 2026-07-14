import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../providers/app_providers.dart';
import '../services/audio_service.dart';
import '../services/output_service.dart';
import '../widgets/ffmpeg_banner.dart';
import '../widgets/file_drop_zone.dart';
import '../widgets/job_list.dart';
import '../widgets/option_widgets.dart';
import 'tool_mixin.dart';

class AudioToolsScreen extends StatelessWidget {
  const AudioToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Tools'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Compress'), Tab(text: 'Convert')],
          ),
        ),
        body: const TabBarView(children: [_CompressTab(), _ConvertTab()]),
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
  String _format = 'mp3';
  double _bitrate = 128;

  Future<void> _process() => runJobs(
        category: 'audio',
        task: (path, id) async {
          final out = await OutputService.suggest(path,
              suffix: '_compressed', ext: _format);
          await AudioService.compress(
            inPath: path,
            outPath: out,
            bitrateKbps: _bitrate.round(),
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
            extensions: AudioService.inputExtensions, onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Compression',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChipSelector<String>(
                options: {
                  for (final format in AudioService.lossyFormats)
                    format: format.toUpperCase()
                },
                value: _format,
                onChanged: (v) => setState(() => _format = v),
              ),
              const SizedBox(height: 8),
              LabeledSlider(
                label: 'Bitrate',
                value: _bitrate,
                min: 64,
                max: 256,
                divisions: 6,
                display: '${_bitrate.round()} kbps',
                onChanged: (v) => setState(() => _bitrate = v),
              ),
            ],
          ),
        ),
        ProcessButton(
          label: files.length > 1
              ? 'Compress ${files.length} files'
              : 'Compress audio',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'audio'),
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
  String _format = 'mp3';
  double _bitrate = 192;

  bool get _lossy => AudioService.lossyFormats.contains(_format);

  Future<void> _process() => runJobs(
        category: 'audio',
        title: (path) => '${p.basename(path)} → ${_format.toUpperCase()}',
        task: (path, id) async {
          final out = await OutputService.suggest(path, ext: _format);
          await AudioService.convert(
            inPath: path,
            outPath: out,
            bitrateKbps: _bitrate.round(),
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
            extensions: AudioService.inputExtensions, onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Output format',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChipSelector<String>(
                options: {
                  for (final format in AudioService.convertFormats)
                    format: format.toUpperCase()
                },
                value: _format,
                onChanged: (v) => setState(() => _format = v),
              ),
              if (_lossy) ...[
                const SizedBox(height: 8),
                LabeledSlider(
                  label: 'Bitrate',
                  value: _bitrate,
                  min: 64,
                  max: 320,
                  divisions: 8,
                  display: '${_bitrate.round()} kbps',
                  onChanged: (v) => setState(() => _bitrate = v),
                ),
              ],
            ],
          ),
        ),
        ProcessButton(
          label: files.length > 1
              ? 'Convert ${files.length} files'
              : 'Convert audio',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'audio'),
      ],
    );
  }
}
