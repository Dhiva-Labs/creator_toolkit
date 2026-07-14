import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../models/social_preset.dart';
import 'ffmpeg_service.dart';

class ImageException implements Exception {
  ImageException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// PNG intermediate produced off the UI isolate: bytes plus dimensions.
typedef _Png = (Uint8List bytes, int width, int height);

/// All image work: pure-Dart `image` for JPG/PNG, ffmpeg (desktop) or the
/// platform encoder via flutter_image_compress (Android) for WEBP output.
class ImageService {
  static const inputExtensions = [
    'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'tif', 'tiff',
  ];

  /// Re-encodes at [quality]; optionally caps the longest side.
  static Future<void> compress({
    required String inPath,
    required String outPath,
    int quality = 80,
    int? maxDimension,
  }) async {
    final ext = _ext(outPath);
    // Fast native path for straight JPG re-encodes on Android.
    if (Platform.isAndroid &&
        maxDimension == null &&
        (ext == 'jpg' || ext == 'jpeg')) {
      final result = await FlutterImageCompress.compressAndGetFile(
        inPath,
        outPath,
        quality: quality,
        // Large bounds mean "keep original size" (the plugin never upscales).
        minWidth: 100000,
        minHeight: 100000,
        format: CompressFormat.jpeg,
        keepExif: true,
      );
      if (result == null) throw ImageException('Could not compress image');
      return;
    }
    if (ext == 'webp') {
      final png = await Isolate.run(() {
        var image = _decode(inPath);
        image = _limit(image, maxDimension);
        return _toPng(image);
      });
      await _writeWebp(png, outPath, quality);
      return;
    }
    await Isolate.run(() {
      var image = _decode(inPath);
      image = _limit(image, maxDimension);
      _encodeAndWrite(image, outPath, quality);
    });
  }

  /// Resizes keeping aspect ratio (fits inside width × height when both given).
  static Future<void> resize({
    required String inPath,
    required String outPath,
    int? width,
    int? height,
    bool allowUpscale = false,
    int quality = 90,
  }) async {
    if (width == null && height == null) {
      throw ImageException('Enter a width or a height');
    }
    img.Image transform() {
      final image = _decode(inPath);
      final (w, h) =
          _fit(image.width, image.height, width, height, allowUpscale);
      if (w == image.width && h == image.height) return image;
      return img.copyResize(image,
          width: w, height: h, interpolation: img.Interpolation.cubic);
    }

    if (_ext(outPath) == 'webp') {
      final png = await Isolate.run(() => _toPng(transform()));
      await _writeWebp(png, outPath, quality);
    } else {
      await Isolate.run(() => _encodeAndWrite(transform(), outPath, quality));
    }
  }

  /// Center-crops to [aspect] (width / height).
  static Future<void> cropToAspect({
    required String inPath,
    required String outPath,
    required double aspect,
    int quality = 90,
  }) async {
    img.Image transform() => _centerCropAspect(_decode(inPath), aspect);

    if (_ext(outPath) == 'webp') {
      final png = await Isolate.run(() => _toPng(transform()));
      await _writeWebp(png, outPath, quality);
    } else {
      await Isolate.run(() => _encodeAndWrite(transform(), outPath, quality));
    }
  }

  /// Converts to the format implied by [outPath]'s extension.
  static Future<void> convert({
    required String inPath,
    required String outPath,
    int quality = 90,
  }) async {
    if (_ext(outPath) == 'webp') {
      final png = await Isolate.run(() => _toPng(_decode(inPath)));
      await _writeWebp(png, outPath, quality);
    } else {
      await Isolate.run(() => _encodeAndWrite(_decode(inPath), outPath, quality));
    }
  }

  /// Cover-crops to the preset's exact dimensions and exports a JPG,
  /// stepping quality down if the preset has a size cap. Returns a summary.
  static Future<String> applyPreset({
    required String inPath,
    required String outPath,
    required SocialPreset preset,
  }) {
    return Isolate.run(() {
      var image = _decode(inPath);
      image = _coverCrop(image, preset.width, preset.height);
      var quality = preset.quality;
      var bytes = img.encodeJpg(_flatten(image), quality: quality);
      final cap = preset.maxBytes;
      while (cap != null && bytes.length > cap && quality > 40) {
        quality -= 10;
        bytes = img.encodeJpg(_flatten(image), quality: quality);
      }
      File(outPath).writeAsBytesSync(bytes);
      return '${preset.width} × ${preset.height}, quality $quality';
    });
  }

  // ---- helpers (safe to call inside isolates) ----

  static String _ext(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  static img.Image _decode(String path) {
    final bytes = File(path).readAsBytesSync();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw ImageException('Could not read ${p.basename(path)}');
    }
    return img.bakeOrientation(image);
  }

  static img.Image _limit(img.Image image, int? maxDimension) {
    if (maxDimension == null) return image;
    final longest = math.max(image.width, image.height);
    if (longest <= maxDimension) return image;
    final scale = maxDimension / longest;
    return img.copyResize(image,
        width: math.max(1, (image.width * scale).round()),
        height: math.max(1, (image.height * scale).round()),
        interpolation: img.Interpolation.cubic);
  }

  static (int, int) _fit(
      int sw, int sh, int? width, int? height, bool allowUpscale) {
    double scale;
    if (width != null && height != null) {
      scale = math.min(width / sw, height / sh);
    } else if (width != null) {
      scale = width / sw;
    } else {
      scale = height! / sh;
    }
    if (!allowUpscale) scale = math.min(scale, 1);
    return (
      math.max(1, (sw * scale).round()),
      math.max(1, (sh * scale).round()),
    );
  }

  static img.Image _centerCropAspect(img.Image image, double aspect) {
    final sw = image.width, sh = image.height;
    int cw, ch;
    if (sw / sh > aspect) {
      ch = sh;
      cw = math.max(1, (sh * aspect).round());
    } else {
      cw = sw;
      ch = math.max(1, (sw / aspect).round());
    }
    if (cw == sw && ch == sh) return image;
    return img.copyCrop(image,
        x: (sw - cw) ~/ 2, y: (sh - ch) ~/ 2, width: cw, height: ch);
  }

  static img.Image _coverCrop(img.Image image, int tw, int th) {
    final scale = math.max(tw / image.width, th / image.height);
    var resized = image;
    if (scale != 1) {
      resized = img.copyResize(image,
          width: math.max(tw, (image.width * scale).round()),
          height: math.max(th, (image.height * scale).round()),
          interpolation: img.Interpolation.cubic);
    }
    if (resized.width == tw && resized.height == th) return resized;
    return img.copyCrop(resized,
        x: (resized.width - tw) ~/ 2,
        y: (resized.height - th) ~/ 2,
        width: tw,
        height: th);
  }

  /// JPG can't store alpha; flatten transparent images onto white.
  static img.Image _flatten(img.Image image) {
    if (image.numChannels < 4) return image;
    final background =
        img.Image(width: image.width, height: image.height, numChannels: 3);
    img.fill(background, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(background, image);
    return background;
  }

  static _Png _toPng(img.Image image) =>
      (img.encodePng(image), image.width, image.height);

  static void _encodeAndWrite(img.Image image, String outPath, int quality) {
    final ext = _ext(outPath);
    final Uint8List bytes;
    switch (ext) {
      case 'jpg' || 'jpeg':
        bytes = img.encodeJpg(_flatten(image), quality: quality);
      case 'png':
        bytes = img.encodePng(image, level: 9);
      default:
        throw ImageException('Unsupported output format .$ext');
    }
    File(outPath).writeAsBytesSync(bytes);
  }

  static Future<void> _writeWebp(_Png png, String outPath, int quality) async {
    final (bytes, width, height) = png;
    if (Platform.isAndroid) {
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        format: CompressFormat.webp,
        minWidth: width,
        minHeight: height,
      );
      await File(outPath).writeAsBytes(out);
      return;
    }
    // Desktop: encode through ffmpeg's libwebp.
    final tmpDir = Directory.systemTemp.createTempSync('creator_toolkit');
    final tmpPng = File(p.join(tmpDir.path, 'frame.png'));
    try {
      await tmpPng.writeAsBytes(bytes);
      await FfmpegService.run(
          ['-i', tmpPng.path, '-c:v', 'libwebp', '-quality', '$quality', outPath]);
    } finally {
      tmpDir.delete(recursive: true).ignore();
    }
  }
}
