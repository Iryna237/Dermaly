import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/services/gemini_service.dart';
import 'package:ziskin/services/skin_progress_storage.dart';
import 'package:ziskin/skin_scan_comparison.dart';

void main() {
  group('ScanPhoto', () {
    Widget host(ScanPhoto photo) => MaterialApp(home: Scaffold(body: Center(child: photo)));

    testWidgets('tapping a photo opens it full screen with its title', (tester) async {
      await tester.pumpWidget(host(const ScanPhoto(
        imagePath: 'scan.jpg',
        width: 140,
        height: 180,
        fullScreenTitle: 'Your skin in Apr 2026',
      )));

      await tester.tap(find.byType(ScanPhoto));
      await tester.pumpAndSettle();

      expect(find.byType(ScanPhotoViewer), findsOneWidget);
      expect(find.text('Your skin in Apr 2026'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('a scan without photo does not open anything', (tester) async {
      await tester.pumpWidget(host(const ScanPhoto(
        imagePath: '',
        width: 48,
        height: 48,
        fullScreenTitle: 'April 2026',
      )));

      await tester.tap(find.byType(ScanPhoto));
      await tester.pumpAndSettle();

      expect(find.byType(ScanPhotoViewer), findsNothing);
    });
  });

  SkinAnalysisResult at(DateTime date) =>
      SkinAnalysisResult.fallback(imagePath: '').copyWith(analyzedAt: date);

  group('SkinProgressStorage.combine', () {
    final analysis = at(DateTime(2026, 3, 14));

    test('without a skin analysis there is no progress to show', () {
      expect(SkinProgressStorage.combine(null, [at(DateTime(2026, 4, 2))]), isEmpty);
    });

    test('the skin analysis alone is the starting point', () {
      expect(SkinProgressStorage.combine(analysis, const []), [analysis]);
    });

    test('monthly scans follow the starting point from the next month', () {
      final april = at(DateTime(2026, 4, 2));
      final may = at(DateTime(2026, 5, 30));

      expect(SkinProgressStorage.combine(analysis, [april, may]), [analysis, april, may]);
    });

    test('scans from the analysis month or before are left out', () {
      final february = at(DateTime(2026, 2, 20));
      final sameMonth = at(DateTime(2026, 3, 28));
      final april = at(DateTime(2026, 4, 1));

      expect(
        SkinProgressStorage.combine(analysis, [february, sameMonth, april]),
        [analysis, april],
      );
    });

    test('a later year counts even when its month number is smaller', () {
      final december = at(DateTime(2026, 12, 5));
      final nextJanuary = at(DateTime(2027, 1, 5));
      final lastYear = at(DateTime(2025, 12, 5));

      expect(
        SkinProgressStorage.combine(analysis, [lastYear, december, nextJanuary]),
        [analysis, december, nextJanuary],
      );
    });
  });
}
