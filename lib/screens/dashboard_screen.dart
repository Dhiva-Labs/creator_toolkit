import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/output_service.dart';
import 'audio_tools_screen.dart';
import 'image_tools_screen.dart';
import 'pdf_tools_screen.dart';
import 'presets_screen.dart';
import 'video_tools_screen.dart';

class _Category {
  const _Category(this.title, this.subtitle, this.icon, this.color, this.build);
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() build;
}

final _categories = <_Category>[
  _Category('Image Tools', 'Compress · Resize · Crop · Convert · Batch',
      Icons.image_outlined, const Color(0xFF7C4DFF), () => const ImageToolsScreen()),
  _Category('Video Tools', 'Compress · Convert · Trim',
      Icons.movie_outlined, const Color(0xFFEF5350), () => const VideoToolsScreen()),
  _Category('Audio Tools', 'Compress · Convert',
      Icons.audiotrack_outlined, const Color(0xFF26A69A), () => const AudioToolsScreen()),
  _Category('PDF Tools', 'Compress · Merge · Split',
      Icons.picture_as_pdf_outlined, const Color(0xFFFF7043), () => const PdfToolsScreen()),
  _Category('Social Media Presets', 'Instagram · YouTube · TikTok · Facebook',
      Icons.share_outlined, const Color(0xFF42A5F5), () => const PresetsScreen()),
];

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final (modeIcon, modeLabel) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto_outlined, 'System theme'),
      ThemeMode.light => (Icons.light_mode_outlined, 'Light theme'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'Dark theme'),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Creator Toolkit'),
        actions: [
          IconButton(
            tooltip: '$modeLabel — tap to change',
            icon: Icon(modeIcon),
            onPressed: () => ref.read(themeModeProvider.notifier).cycle(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'Optimize and convert media before you share it online.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 460,
                    mainAxisExtent: 128,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) =>
                      _CategoryCard(category: _categories[index]),
                ),
              ),
              if (!Platform.isAndroid)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextButton.icon(
                      icon: const Icon(Icons.folder_open_outlined, size: 18),
                      label: const Text('Open output folder'),
                      onPressed: () async {
                        final dir = await OutputService.baseDir();
                        await OutputService.reveal(dir.path);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final _Category category;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => category.build())),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(category.icon, color: category.color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      category.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
