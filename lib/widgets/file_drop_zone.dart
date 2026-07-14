import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Tap-to-browse picker that also accepts drag & drop on desktop.
class FileDropZone extends StatefulWidget {
  const FileDropZone({
    super.key,
    required this.extensions,
    required this.onAdded,
    this.multiple = true,
  });

  final List<String> extensions;
  final bool multiple;
  final ValueChanged<List<String>> onAdded;

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _hovering = false;

  bool _accepts(String path) => widget.extensions
      .contains(p.extension(path).replaceFirst('.', '').toLowerCase());

  Future<void> _browse() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: widget.extensions,
      allowMultiple: widget.multiple,
    );
    if (result == null) return;
    final paths = [
      for (final file in result.files)
        if (file.path != null) file.path!,
    ];
    if (paths.isNotEmpty) widget.onAdded(paths);
  }

  void _dropped(DropDoneDetails details) {
    final accepted = [
      for (final file in details.files)
        if (_accepts(file.path)) file.path,
    ];
    if (!widget.multiple && accepted.length > 1) {
      accepted.removeRange(1, accepted.length);
    }
    if (accepted.isNotEmpty) widget.onAdded(accepted);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: (details) {
        setState(() => _hovering = false);
        _dropped(details);
      },
      child: Material(
        color: _hovering
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _browse,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovering ? scheme.primary : scheme.outlineVariant,
                width: _hovering ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.upload_file_outlined,
                    size: 40, color: scheme.primary),
                const SizedBox(height: 8),
                Text(
                  widget.multiple
                      ? 'Drop files here or tap to browse'
                      : 'Drop a file here or tap to browse',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.extensions.map((e) => e.toUpperCase()).join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chips for the currently selected files.
class SelectedFiles extends StatelessWidget {
  const SelectedFiles({
    super.key,
    required this.files,
    required this.onRemove,
    required this.onClear,
  });

  final List<String> files;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${files.length} selected',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < files.length; i++)
                InputChip(
                  label: Text(p.basename(files[i]),
                      overflow: TextOverflow.ellipsis),
                  onDeleted: () => onRemove(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
