import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show Offset;

import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfException implements Exception {
  PdfException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// PDF manipulation via Syncfusion's pure-Dart PDF library (works offline
/// on every platform, runs in a background isolate).
class PdfService {
  /// Merges [inPaths] in order. Returns the total page count.
  static Future<int> merge({
    required List<String> inPaths,
    required String outPath,
  }) {
    return Isolate.run(() {
      final dest = PdfDocument();
      dest.pageSettings.margins.all = 0;
      var pages = 0;
      for (final path in inPaths) {
        final src = _open(path);
        for (var i = 0; i < src.pages.count; i++) {
          final page = src.pages[i];
          dest.pageSettings.size = page.size;
          dest.pages.add().graphics.drawPdfTemplate(
              page.createTemplate(), Offset.zero, page.size);
          pages++;
        }
        src.dispose();
      }
      _write(dest, outPath);
      return pages;
    });
  }

  /// Writes each page of [inPath] as its own PDF inside [outDir].
  /// Returns the number of files written.
  static Future<int> splitAll({
    required String inPath,
    required String outDir,
  }) {
    return Isolate.run(() {
      final src = _open(inPath);
      final base = p.basenameWithoutExtension(inPath);
      final count = src.pages.count;
      final digits = count.toString().length;
      for (var i = 0; i < count; i++) {
        final page = src.pages[i];
        final dest = PdfDocument();
        dest.pageSettings.margins.all = 0;
        dest.pageSettings.size = page.size;
        dest.pages.add().graphics.drawPdfTemplate(
            page.createTemplate(), Offset.zero, page.size);
        final name =
            '${base}_page_${(i + 1).toString().padLeft(digits, '0')}.pdf';
        _write(dest, p.join(outDir, name));
      }
      src.dispose();
      return count;
    });
  }

  /// Extracts pages [from]..[to] (1-based, inclusive) into a new PDF.
  static Future<int> extractRange({
    required String inPath,
    required String outPath,
    required int from,
    required int to,
  }) {
    return Isolate.run(() {
      final src = _open(inPath);
      final count = src.pages.count;
      if (from < 1 || to > count || from > to) {
        src.dispose();
        throw PdfException('Page range must be within 1–$count');
      }
      final dest = PdfDocument();
      dest.pageSettings.margins.all = 0;
      for (var i = from - 1; i < to; i++) {
        final page = src.pages[i];
        dest.pageSettings.size = page.size;
        dest.pages.add().graphics.drawPdfTemplate(
            page.createTemplate(), Offset.zero, page.size);
      }
      src.dispose();
      _write(dest, outPath);
      return to - from + 1;
    });
  }

  /// Re-saves with maximum stream compression and no incremental updates.
  /// Returns (bytes before, bytes after).
  static Future<(int, int)> compress({
    required String inPath,
    required String outPath,
  }) {
    return Isolate.run(() {
      final before = File(inPath).lengthSync();
      final doc = _open(inPath);
      doc.compressionLevel = PdfCompressionLevel.best;
      doc.fileStructure.incrementalUpdate = false;
      doc.fileStructure.crossReferenceType =
          PdfCrossReferenceType.crossReferenceStream;
      _write(doc, outPath);
      return (before, File(outPath).lengthSync());
    });
  }

  static PdfDocument _open(String path) {
    try {
      return PdfDocument(inputBytes: File(path).readAsBytesSync());
    } catch (_) {
      throw PdfException(
          'Could not open ${p.basename(path)} — is it a valid, unencrypted PDF?');
    }
  }

  static void _write(PdfDocument doc, String outPath) {
    final bytes = doc.saveSync();
    doc.dispose();
    File(outPath).writeAsBytesSync(bytes);
  }
}
