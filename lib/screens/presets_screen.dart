import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../models/social_preset.dart';
import '../services/image_service.dart';
import '../services/output_service.dart';
import '../widgets/file_drop_zone.dart';
import '../widgets/job_list.dart';
import '../widgets/option_widgets.dart';
import 'tool_mixin.dart';

class PresetsScreen extends StatelessWidget {
  const PresetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Social Media Presets')),
      body: const _PresetsBody(),
    );
  }
}

class _PresetsBody extends ConsumerStatefulWidget {
  const _PresetsBody();
  @override
  ConsumerState<_PresetsBody> createState() => _PresetsBodyState();
}

class _PresetsBodyState extends ConsumerState<_PresetsBody>
    with ToolProcessing {
  String _platform = socialPlatforms.first.name;
  late SocialPreset _preset = _platformPresets.first;

  List<SocialPreset> get _platformPresets =>
      socialPresets.where((preset) => preset.platform == _platform).toList();

  void _selectPlatform(String platform) {
    setState(() {
      _platform = platform;
      _preset = _platformPresets.first;
    });
  }

  Future<void> _process() => runJobs(
        category: 'preset',
        title: (path) =>
            '${p.basename(path)} → $_platform ${_preset.name}',
        task: (path, id) async {
          final out = await OutputService.suggest(
            path,
            suffix:
                '_${OutputService.slug('$_platform ${_preset.name}')}',
            ext: 'jpg',
          );
          final summary = await ImageService.applyPreset(
              inPath: path, outPath: out, preset: _preset);
          final size = OutputService.formatBytes(File(out).lengthSync());
          return (out, '$summary • $size');
        },
      );

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        OptionCard(
          title: 'Platform',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final platform in socialPlatforms)
                ChoiceChip(
                  avatar: Icon(platform.icon, size: 18),
                  label: Text(platform.name),
                  selected: platform.name == _platform,
                  onSelected: (_) => _selectPlatform(platform.name),
                ),
            ],
          ),
        ),
        OptionCard(
          title: 'Preset',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in _platformPresets)
                    ChoiceChip(
                      label: Text('${preset.name} · ${preset.dimensions}'),
                      selected: preset == _preset,
                      onSelected: (_) => setState(() => _preset = preset),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Exports a ${_preset.dimensions} JPG (cover crop, centered) '
                'at quality ${_preset.quality}'
                '${_preset.maxBytes != null ? ', kept under ${OutputService.formatBytes(_preset.maxBytes!)}' : ''}.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FileDropZone(
            extensions: ImageService.inputExtensions, onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        ProcessButton(
          label: files.length > 1
              ? 'Export ${files.length} images for $_platform'
              : 'Export for $_platform',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'preset'),
      ],
    );
  }
}
