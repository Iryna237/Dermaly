import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/services/gemini_service.dart';
import 'package:ziskin/services/skin_analysis_storage.dart';
import 'package:ziskin/services/skin_progress_storage.dart';

void main() {
  const standardConcerns = [
    'Dark Spots',
    'Acne',
    'Redness',
    'Pores',
    'Texture / Unevenness',
    'Fine Lines',
  ];

  group('SkinAnalysisResult.fromJson', () {
    SkinAnalysisResult parse(Map<String, dynamic> json) =>
        SkinAnalysisResult.fromJson(json, imagePath: 'face.jpg');

    test('scores are kept between 0 and 100', () {
      final result = parse({'overallScore': 140, 'hydrationLevel': -5});

      expect(result.overallScore, 100);
      expect(result.hydrationLevel, 0);
    });

    test('scores sent as text are read, unreadable ones fall back', () {
      expect(parse({'overallScore': '85'}).overallScore, 85);
      expect(parse({'overallScore': 'high'}).overallScore, 78);
      expect(parse({}).overallScore, 78);
      expect(parse({}).hydrationLevel, 65);
    });

    test('blank texts are replaced by defaults', () {
      final result = parse({
        'skinType': '  ',
        'skinTypeDetails': '',
        'recommendationSummary': null,
      });

      expect(result.skinType, 'Combination Skin');
      expect(result.skinTypeDetails, isNotEmpty);
      expect(result.recommendationSummary, isNotEmpty);
    });

    test('the six standard concerns always come first, in a fixed order', () {
      final result = parse({
        'concerns': <String, dynamic>{
          'Rosacea': 40,
          'Acne': 60,
          'Dark Spots': '120',
        },
      });

      expect(result.concerns.keys, [...standardConcerns, 'Rosacea']);
      expect(result.concerns['Dark Spots'], 100);
      expect(result.concerns['Acne'], 60);
      expect(result.concerns['Redness'], 30);
      expect(result.concerns['Rosacea'], 40);
    });

    test('the photo path and date are not sent back to storage', () {
      final result = parse({'overallScore': 80}).copyWith(analyzedAt: DateTime(2026, 9, 1));

      expect(result.toJson().containsKey('imagePath'), isFalse);
      expect(result.toJson().containsKey('analyzedAt'), isFalse);
      expect(result.toJson()['overallScore'], 80);
    });

    test('copyWith only changes the photo and the date', () {
      final original = SkinAnalysisResult.fallback(imagePath: 'old.jpg');
      final moved = original.copyWith(imagePath: 'new.jpg', analyzedAt: DateTime(2026, 9, 1));

      expect(moved.imagePath, 'new.jpg');
      expect(moved.analyzedAt, DateTime(2026, 9, 1));
      expect(moved.overallScore, original.overallScore);
      expect(moved.skinType, original.skinType);
      expect(moved.concerns, original.concerns);
    });
  });

  group('SkinAnalysisStorage', () {
    final photos = Directory('/data/skin_analysis');

    test('only the photo file name is stored, never its full path', () {
      final result = SkinAnalysisResult.fallback(imagePath: '/cache/camera/IMG_01.jpg')
          .copyWith(analyzedAt: DateTime(2026, 9, 15, 10));

      final stored = SkinAnalysisStorage.encode(result, imageFileName: 'scan.jpg');

      expect(stored['imageFileName'], 'scan.jpg');
      expect(stored['analyzedAt'], DateTime(2026, 9, 15, 10).millisecondsSinceEpoch);
      expect(stored.values, isNot(contains('/cache/camera/IMG_01.jpg')));
    });

    test('a stored analysis reads back with the photo in the app folder', () {
      final original = SkinAnalysisResult.fallback(imagePath: 'camera.jpg')
          .copyWith(analyzedAt: DateTime(2026, 9, 15, 10));
      final stored = SkinAnalysisStorage.encode(original, imageFileName: 'scan.jpg');

      final copy = SkinAnalysisStorage.decode(stored, photos)!;

      expect(copy.imagePath, '${photos.path}/scan.jpg');
      expect(copy.analyzedAt, original.analyzedAt);
      expect(copy.overallScore, original.overallScore);
      expect(copy.skinType, original.skinType);
      expect(copy.concerns, original.concerns);
    });

    test('loosely typed Firestore maps are still read', () {
      final raw = <dynamic, dynamic>{
        'overallScore': 70,
        'concerns': <dynamic, dynamic>{'Acne': 55},
      };

      final copy = SkinAnalysisStorage.decode(raw, photos)!;

      expect(copy.overallScore, 70);
      expect(copy.concerns['Acne'], 55);
      expect(copy.imagePath, '');
      expect(copy.analyzedAt, isNull);
    });

    test('anything other than a map is not an analysis', () {
      expect(SkinAnalysisStorage.decode(null, photos), isNull);
      expect(SkinAnalysisStorage.decode('analysis', photos), isNull);
    });
  });

  group('SkinProgressStorage', () {
    test('one scan per month, keyed year then month', () {
      expect(SkinProgressStorage.monthKey(DateTime(2026, 3, 15)), '2026-03');
      expect(SkinProgressStorage.monthKey(DateTime(2026, 12, 31, 23, 59)), '2026-12');
      expect(SkinProgressStorage.monthKey(DateTime(2026, 3, 1)),
          SkinProgressStorage.monthKey(DateTime(2026, 3, 31)));
    });
  });
}
