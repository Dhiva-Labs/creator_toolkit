import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Decides where processed files land and helps reveal them.
///
/// Desktop: ~/CreatorToolkit. Android: the app's external files dir
/// (Android/data/&lt;app&gt;/files/CreatorToolkit, browsable with a file manager).
class OutputService {
  static Future<Directory> baseDir() async {
    Directory root;
    if (Platform.isAndroid) {
      root = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          Directory.current.path;
      root = Directory(home);
    }
    return Directory(p.join(root.path, 'CreatorToolkit')).create(recursive: true);
  }

  /// A non-clashing output path derived from [inputPath].
  static Future<String> suggest(String inputPath,
      {String suffix = '', String? ext}) async {
    final dir = await baseDir();
    final base = p.basenameWithoutExtension(inputPath);
    final extension =
        (ext ?? p.extension(inputPath).replaceFirst('.', '')).toLowerCase();
    var candidate = p.join(dir.path, '$base$suffix.$extension');
    var i = 1;
    while (FileSystemEntity.typeSync(candidate) !=
        FileSystemEntityType.notFound) {
      candidate = p.join(dir.path, '$base$suffix (${i++}).$extension');
    }
    return candidate;
  }

  /// A fresh output folder (for multi-file results like PDF splitting).
  static Future<Directory> suggestDir(String name) async {
    final dir = await baseDir();
    var candidate = p.join(dir.path, name);
    var i = 1;
    while (FileSystemEntity.typeSync(candidate) !=
        FileSystemEntityType.notFound) {
      candidate = p.join(dir.path, '$name (${i++})');
    }
    return Directory(candidate).create(recursive: true);
  }

  /// Opens the folder containing [path] in the system file manager (desktop only).
  static Future<void> reveal(String path) async {
    final target =
        FileSystemEntity.isDirectorySync(path) ? path : p.dirname(path);
    if (Platform.isLinux) {
      await Process.start('xdg-open', [target],
          mode: ProcessStartMode.detached);
    } else if (Platform.isWindows) {
      await Process.start('explorer', [target],
          mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      await Process.start('open', [target], mode: ProcessStartMode.detached);
    }
  }

  static String slug(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
