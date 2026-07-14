import 'package:flutter/material.dart';

class SocialPreset {
  const SocialPreset({
    required this.platform,
    required this.name,
    required this.width,
    required this.height,
    this.quality = 85,
    this.maxBytes,
  });

  final String platform;
  final String name;
  final int width;
  final int height;
  final int quality;

  /// If set, quality is lowered until the file fits (e.g. YouTube's 2 MB thumbnail cap).
  final int? maxBytes;

  String get dimensions => '$width × $height';
}

class SocialPlatform {
  const SocialPlatform(this.name, this.icon);
  final String name;
  final IconData icon;
}

const socialPlatforms = [
  SocialPlatform('Instagram', Icons.camera_alt_outlined),
  SocialPlatform('YouTube', Icons.play_circle_outline),
  SocialPlatform('TikTok', Icons.music_note_outlined),
  SocialPlatform('Facebook', Icons.thumb_up_outlined),
];

const socialPresets = <SocialPreset>[
  // Instagram
  SocialPreset(platform: 'Instagram', name: 'Square Post', width: 1080, height: 1080),
  SocialPreset(platform: 'Instagram', name: 'Portrait Post', width: 1080, height: 1350),
  SocialPreset(platform: 'Instagram', name: 'Story / Reel Cover', width: 1080, height: 1920),
  SocialPreset(platform: 'Instagram', name: 'Landscape Post', width: 1080, height: 566),
  // YouTube
  SocialPreset(platform: 'YouTube', name: 'Thumbnail', width: 1280, height: 720, quality: 90, maxBytes: 2 * 1024 * 1024),
  SocialPreset(platform: 'YouTube', name: 'Channel Banner', width: 2560, height: 1440),
  SocialPreset(platform: 'YouTube', name: 'Community Post', width: 1080, height: 1080),
  // TikTok
  SocialPreset(platform: 'TikTok', name: 'Video Cover', width: 1080, height: 1920),
  SocialPreset(platform: 'TikTok', name: 'Profile Photo', width: 400, height: 400, quality: 90),
  // Facebook
  SocialPreset(platform: 'Facebook', name: 'Shared Post', width: 1200, height: 630),
  SocialPreset(platform: 'Facebook', name: 'Square Post', width: 1080, height: 1080),
  SocialPreset(platform: 'Facebook', name: 'Cover Photo', width: 820, height: 312),
  SocialPreset(platform: 'Facebook', name: 'Event Cover', width: 1920, height: 1005),
];
