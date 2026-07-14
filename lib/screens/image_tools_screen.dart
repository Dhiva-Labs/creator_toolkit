import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../services/image_service.dart';
import '../services/output_service.dart';
import '../widgets/file_drop_zone.dart';
import '../widgets/job_list.dart';
import '../widgets/option_widgets.dart';
import 'tool_mixin.dart';

class ImageToolsScreen extends StatelessWidget {
  const ImageToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Image Tools'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Compress'),
              Tab(text: 'Resize'),
              Tab(text: 'Crop'),
              Tab(text: 'Convert'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CompressTab(),
            _ResizeTab(),
            _CropTab(),
            _ConvertTab(),
          ],
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
  double _quality = 80;
  int? _maxDimension;

  Future<void> _process() => runJobs(
        category: 'image',
        task: (path, id) async {
          final out = await OutputService.suggest(path, suffix: '_compressed');
          await ImageService.compress(
            inPath: path,
            outPath: out,
            quality: _quality.round(),
            maxDimension: _maxDimension,
          );
          return (out, sizeChange(path, out));
        },
      );

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        FileDropZone(
            extensions: ImageService.inputExtensions, onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Compression',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabeledSlider(
                label: 'Quality',
                value: _quality,
                min: 30,
                max: 100,
                divisions: 14,
                onChanged: (v) => setState(() => _quality = v),
              ),
              const SizedBox(height: 8),
              Text('Longest side',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              ChipSelector<int?>(
                options: const {
                  null: 'Original',
                  1920: '1920 px',
                  1280: '1280 px',
                  1080: '1080 px',
                },
                value: _maxDimension,
                onChanged: (v) => setState(() => _maxDimension = v),
              ),
            ],
          ),
        ),
        ProcessButton(
          label: files.length > 1
              ? 'Compress ${files.length} images'
              : 'Compress image',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'image'),
      ],
    );
  }
}

// ------------------------------------------------------------------ Resize

class _ResizeTab extends ConsumerStatefulWidget {
  const _ResizeTab();
  @override
  ConsumerState<_ResizeTab> createState() => _ResizeTabState();
}

class _ResizeTabState extends ConsumerState<_ResizeTab> with ToolProcessing {
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  bool _allowUpscale = false;

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _process() async {
    final width = int.tryParse(_widthController.text.trim());
    final height = int.tryParse(_heightController.text.trim());
    if (width == null && height == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a width and/or a height')));
      return;
    }
    await runJobs(
      category: 'image',
      task: (path, id) async {
        final out = await OutputService.suggest(path, suffix: '_resized');
        await ImageService.resize(
          inPath: path,
          outPath: out,
          width: width,
          height: height,
          allowUpscale: _allowUpscale,
        );
        return (out, null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        FileDropZone(
            extensions: ImageService.inputExtensions, onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Target size (leave one empty to keep aspect ratio)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _widthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Width (px)'),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('×'),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Height (px)'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow upscaling'),
                subtitle: const Text(
                    'Off: images smaller than the target keep their size'),
                value: _allowUpscale,
                onChanged: (v) => setState(() => _allowUpscale = v),
              ),
            ],
          ),
        ),
        ProcessButton(
          label: files.length > 1
              ? 'Resize ${files.length} images'
              : 'Resize image',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'image'),
      ],
    );
  }
}

// -------------------------------------------------------------------- Crop

class _CropTab extends ConsumerStatefulWidget {
  const _CropTab();
  @override
  ConsumerState<_CropTab> createState() => _CropTabState();
}

class _CropTabState extends ConsumerState<_CropTab> with ToolProcessing {
  static const _aspects = <String, double>{
    'Square 1:1': 1,
    'Portrait 4:5': 4 / 5,
    'Story 9:16': 9 / 16,
    'Landscape 16:9': 16 / 9,
    'Classic 4:3': 4 / 3,
    'Photo 3:2': 3 / 2,
  };
  String _aspect = 'Square 1:1';

  Future<void> _process() => runJobs(
        category: 'image',
        task: (path, id) async {
          final out = await OutputService.suggest(path, suffix: '_cropped');
          await ImageService.cropToAspect(
            inPath: path,
            outPath: out,
            aspect: _aspects[_aspect]!,
          );
          return (out, null);
        },
      );

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        FileDropZone(
            extensions: ImageService.inputExtensions, onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Crop to aspect ratio (centered)',
          child: ChipSelector<String>(
            options: {for (final key in _aspects.keys) key: key},
            value: _aspect,
            onChanged: (v) => setState(() => _aspect = v),
          ),
        ),
        ProcessButton(
          label:
              files.length > 1 ? 'Crop ${files.length} images' : 'Crop image',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'image'),
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
  String _format = 'jpg';
  double _quality = 90;

  Future<void> _process() => runJobs(
        category: 'image',
        title: (path) => '${p.basename(path)} → ${_format.toUpperCase()}',
        task: (path, id) async {
          final out = await OutputService.suggest(path, ext: _format);
          await ImageService.convert(
            inPath: path,
            outPath: out,
            quality: _quality.round(),
          );
          return (out, null);
        },
      );

  @override
  Widget build(BuildContext context) {
    return ToolTabBody(
      children: [
        FileDropZone(
            extensions: ImageService.inputExtensions, onAdded: addFiles),
        SelectedFiles(files: files, onRemove: removeFile, onClear: clearFiles),
        OptionCard(
          title: 'Output format',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChipSelector<String>(
                options: const {'jpg': 'JPG', 'png': 'PNG', 'webp': 'WEBP'},
                value: _format,
                onChanged: (v) => setState(() => _format = v),
              ),
              if (_format != 'png') ...[
                const SizedBox(height: 8),
                LabeledSlider(
                  label: 'Quality',
                  value: _quality,
                  min: 30,
                  max: 100,
                  divisions: 14,
                  onChanged: (v) => setState(() => _quality = v),
                ),
              ],
            ],
          ),
        ),
        ProcessButton(
          label: files.length > 1
              ? 'Convert ${files.length} images'
              : 'Convert image',
          busy: busy,
          enabled: files.isNotEmpty,
          onPressed: _process,
        ),
        const JobList(category: 'image'),
      ],
    );
  }
}
