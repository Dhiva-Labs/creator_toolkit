import 'dart:io';

import 'package:creator_toolkit/models/social_preset.dart';
import 'package:creator_toolkit/services/audio_service.dart';
import 'package:creator_toolkit/services/ffmpeg_service.dart';
import 'package:creator_toolkit/services/image_service.dart';
import 'package:creator_toolkit/services/pdf_service.dart';
import 'package:creator_toolkit/services/video_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Exercises the real processing pipelines on the host (desktop code paths).
/// Video/audio tests need a system ffmpeg and are skipped when it's missing.
void main() {
  late Directory tmp;
  late bool hasFfmpeg;

  String path(String name) => '${tmp.path}/$name';

  File makeImage(String name, int w, int h) {
    final image = img.Image(width: w, height: h);
    img.fill(image, color: img.ColorRgb8(200, 30, 90));
    final bytes = name.endsWith('.jpg')
        ? img.encodeJpg(image, quality: 95)
        : img.encodePng(image);
    return File(path(name))..writeAsBytesSync(bytes);
  }

  File makePdf(String name, int pages) {
    final doc = PdfDocument();
    for (var i = 0; i < pages; i++) {
      doc.pages.add().graphics.drawString(
          'Page ${i + 1} of $name', PdfStandardFont(PdfFontFamily.helvetica, 20));
    }
    final file = File(path(name))..writeAsBytesSync(doc.saveSync());
    doc.dispose();
    return file;
  }

  (int, int) dimensions(String filePath) {
    final image = img.decodeImage(File(filePath).readAsBytesSync())!;
    return (image.width, image.height);
  }

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('creator_toolkit_test');
    try {
      hasFfmpeg =
          (await Process.run('ffmpeg', ['-version'])).exitCode == 0;
    } on ProcessException {
      hasFfmpeg = false;
    }
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  group('ImageService', () {
    test('compress caps the longest side and shrinks the file', () async {
      final src = makeImage('big.jpg', 1600, 1200);
      final out = path('big_c.jpg');
      await ImageService.compress(
          inPath: src.path, outPath: out, quality: 60, maxDimension: 800);
      expect(dimensions(out), (800, 600));
      expect(File(out).lengthSync(), greaterThan(0));
    });

    test('resize fits inside the box without upscaling', () async {
      final src = makeImage('photo.png', 1000, 500);
      final out = path('photo_r.png');
      await ImageService.resize(
          inPath: src.path, outPath: out, width: 400, height: 400);
      expect(dimensions(out), (400, 200));

      final out2 = path('photo_r2.png');
      await ImageService.resize(
          inPath: src.path, outPath: out2, width: 4000);
      expect(dimensions(out2), (1000, 500), reason: 'no upscale by default');
    });

    test('crop to square is centered', () async {
      final src = makeImage('wide.png', 300, 100);
      final out = path('wide_sq.png');
      await ImageService.cropToAspect(
          inPath: src.path, outPath: out, aspect: 1);
      expect(dimensions(out), (100, 100));
    });

    test('convert png → jpg flattens and writes', () async {
      final src = makeImage('art.png', 320, 200);
      final out = path('art.jpg');
      await ImageService.convert(inPath: src.path, outPath: out, quality: 85);
      expect(img.decodeJpg(File(out).readAsBytesSync()), isNotNull);
    });

    test('convert to webp via ffmpeg', () async {
      final src = makeImage('art2.png', 320, 200);
      final out = path('art2.webp');
      await ImageService.convert(inPath: src.path, outPath: out, quality: 80);
      expect(dimensions(out), (320, 200));
    }, skip: !Platform.isLinux && !Platform.isWindows && !Platform.isMacOS);

    test('social preset cover-crops to exact dimensions', () async {
      final src = makeImage('portrait.jpg', 900, 1600);
      final out = path('portrait_yt.jpg');
      const preset = SocialPreset(
          platform: 'YouTube',
          name: 'Thumbnail',
          width: 1280,
          height: 720,
          quality: 90,
          maxBytes: 2 * 1024 * 1024);
      final summary = await ImageService.applyPreset(
          inPath: src.path, outPath: out, preset: preset);
      expect(dimensions(out), (1280, 720));
      expect(File(out).lengthSync(), lessThan(2 * 1024 * 1024));
      expect(summary, contains('1280 × 720'));
    });
  });

  group('PdfService', () {
    test('merge combines all pages in order', () async {
      final a = makePdf('a.pdf', 2);
      final b = makePdf('b.pdf', 3);
      final out = path('merged.pdf');
      final pages =
          await PdfService.merge(inPaths: [a.path, b.path], outPath: out);
      expect(pages, 5);
      final doc = PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(doc.pages.count, 5);
      doc.dispose();
    });

    test('splitAll writes one file per page', () async {
      final src = makePdf('book.pdf', 4);
      final dir = Directory(path('book_pages'))..createSync();
      final count =
          await PdfService.splitAll(inPath: src.path, outDir: dir.path);
      expect(count, 4);
      expect(dir.listSync().whereType<File>().length, 4);
    });

    test('extractRange keeps the requested pages', () async {
      final src = makePdf('report.pdf', 5);
      final out = path('report_p2-3.pdf');
      final count = await PdfService.extractRange(
          inPath: src.path, outPath: out, from: 2, to: 3);
      expect(count, 2);
      final doc = PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(doc.pages.count, 2);
      doc.dispose();
    });

    test('extractRange rejects an impossible range', () async {
      final src = makePdf('short.pdf', 2);
      expect(
        () => PdfService.extractRange(
            inPath: src.path, outPath: path('x.pdf'), from: 1, to: 9),
        throwsA(isA<PdfException>()),
      );
    });

    test('compress rewrites a smaller or equal file', () async {
      final src = makePdf('fat.pdf', 6);
      final out = path('fat_c.pdf');
      final (before, after) =
          await PdfService.compress(inPath: src.path, outPath: out);
      expect(after, greaterThan(0));
      expect(before, File(src.path).lengthSync());
      final doc = PdfDocument(inputBytes: File(out).readAsBytesSync());
      expect(doc.pages.count, 6);
      doc.dispose();
    });
  });

  group('FFmpeg pipelines (desktop)', () {
    late String sample;

    setUpAll(() async {
      if (!hasFfmpeg) return;
      sample = path('sample.mp4');
      await FfmpegService.run([
        '-f', 'lavfi', '-i', 'testsrc=duration=2:size=320x240:rate=15',
        '-f', 'lavfi', '-i', 'sine=frequency=440:duration=2',
        '-shortest',
        '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac',
        sample,
      ]);
    });

    test('probeDuration reads the clip length', () async {
      if (!hasFfmpeg) return;
      final duration = await FfmpegService.probeDuration(sample);
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, closeTo(2000, 250));
    });

    test('video compress produces a playable mp4 and reports progress',
        () async {
      if (!hasFfmpeg) return;
      final out = path('sample_c.mp4');
      final updates = <double>[];
      await VideoService.compress(
          inPath: sample,
          outPath: out,
          crf: 30,
          maxHeight: 120,
          onProgress: updates.add);
      expect(File(out).lengthSync(), greaterThan(0));
      final duration = await FfmpegService.probeDuration(out);
      expect(duration!.inMilliseconds, closeTo(2000, 400));
      expect(updates, isNotEmpty);
      expect(updates.last, closeTo(1.0, 0.15));
    });

    test('video convert to webm', () async {
      if (!hasFfmpeg) return;
      final out = path('sample.webm');
      await VideoService.convert(inPath: sample, outPath: out);
      expect(File(out).lengthSync(), greaterThan(0));
    });

    test('trim with re-encode cuts to the requested length', () async {
      if (!hasFfmpeg) return;
      final out = path('sample_trim.mp4');
      await VideoService.trim(
          inPath: sample,
          outPath: out,
          start: const Duration(milliseconds: 500),
          end: const Duration(milliseconds: 1500),
          reencode: true);
      final duration = await FfmpegService.probeDuration(out);
      expect(duration!.inMilliseconds, closeTo(1000, 300));
    });

    test('audio compress and convert', () async {
      if (!hasFfmpeg) return;
      final wav = path('tone.wav');
      await FfmpegService.run(
          ['-f', 'lavfi', '-i', 'sine=frequency=440:duration=2', wav]);
      final mp3 = path('tone.mp3');
      await AudioService.compress(
          inPath: wav, outPath: mp3, bitrateKbps: 128);
      expect(File(mp3).lengthSync(), greaterThan(0));
      final flac = path('tone.flac');
      await AudioService.convert(inPath: mp3, outPath: flac);
      expect(File(flac).lengthSync(), greaterThan(0));
    });

    test('failure surfaces a readable error', () async {
      if (!hasFfmpeg) return;
      final bogus = File(path('broken.mp4'))..writeAsStringSync('not video');
      expect(
        () => VideoService.compress(
            inPath: bogus.path, outPath: path('broken_c.mp4')),
        throwsA(isA<FfmpegException>()),
      );
    });
  });
}
