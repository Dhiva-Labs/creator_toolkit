import 'package:creator_toolkit/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the real app and walks the main navigation paths.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: CreatorToolkitApp()));
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard shows all five category cards', (tester) async {
    await pumpApp(tester);
    expect(find.text('Creator Toolkit'), findsOneWidget);
    expect(find.text('Image Tools'), findsOneWidget);
    expect(find.text('Video Tools'), findsOneWidget);
    expect(find.text('Audio Tools'), findsOneWidget);
    expect(find.text('PDF Tools'), findsOneWidget);
    expect(find.text('Social Media Presets'), findsOneWidget);
  });

  testWidgets('every tool screen opens and shows its tabs', (tester) async {
    await pumpApp(tester);

    Future<void> open(String card, List<String> expectTexts) async {
      await tester.tap(find.text(card));
      await tester.pumpAndSettle();
      for (final text in expectTexts) {
        expect(find.text(text), findsWidgets, reason: '$card → $text');
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await open('Image Tools', ['Compress', 'Resize', 'Crop', 'Convert']);
    await open('Video Tools', ['Compress', 'Convert', 'Trim']);
    await open('Audio Tools', ['Compress', 'Convert']);
    await open('PDF Tools', ['Compress', 'Merge', 'Split']);
    await open('Social Media Presets', ['Instagram', 'YouTube', 'TikTok', 'Facebook']);
  });

  testWidgets('image tabs switch and show their options', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Image Tools'));
    await tester.pumpAndSettle();

    expect(find.text('Quality'), findsOneWidget);
    await tester.tap(find.text('Resize'));
    await tester.pumpAndSettle();
    expect(find.text('Width (px)'), findsOneWidget);
    await tester.tap(find.text('Crop'));
    await tester.pumpAndSettle();
    expect(find.text('Square 1:1'), findsOneWidget);
    await tester.tap(find.text('Convert'));
    await tester.pumpAndSettle();
    expect(find.text('WEBP'), findsOneWidget);
  });

  testWidgets('preset selection follows the platform', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Social Media Presets'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Square Post'), findsWidgets);
    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Thumbnail'), findsWidgets);
    expect(find.textContaining('1280 × 720'), findsWidgets);
  });

  testWidgets('theme toggle cycles modes', (tester) async {
    await pumpApp(tester);
    final button = find.byTooltip('System theme — tap to change');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Light theme — tap to change'), findsOneWidget);
    await tester.tap(find.byTooltip('Light theme — tap to change'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dark theme — tap to change'), findsOneWidget);
  });
}
