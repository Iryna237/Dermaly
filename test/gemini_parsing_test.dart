import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/services/gemini_service.dart';
import 'package:ziskin/services/questionnaire_storage.dart';

void main() {
  Map<String, dynamic> response(String json) => jsonDecode(json) as Map<String, dynamic>;

  group('Gemini reply text', () {
    test('the text parts are joined and trimmed', () {
      final text = GeminiService.textFrom(response('''
        {"candidates": [{"content": {"parts": [
          {"text": "  Hello "},
          {"text": "world  "}
        ]}}]}'''));

      expect(text, 'Hello world');
    });

    test("the model's thinking is left out", () {
      final text = GeminiService.textFrom(response('''
        {"candidates": [{"content": {"parts": [
          {"text": "Let me look at the photo...", "thought": true},
          {"text": "{\\"overallScore\\": 80}"}
        ]}}]}'''));

      expect(text, '{"overallScore": 80}');
    });

    test('a reply without candidates is an error', () {
      expect(() => GeminiService.textFrom(response('{}')), throwsA(isA<GeminiException>()));
      expect(() => GeminiService.textFrom(response('{"candidates": []}')),
          throwsA(isA<GeminiException>()));
    });

    test('a reply with only thinking is an empty reply', () {
      expect(
        () => GeminiService.textFrom(response('''
          {"candidates": [{"content": {"parts": [
            {"text": "Thinking...", "thought": true}
          ]}}]}''')),
        throwsA(isA<GeminiException>().having(
          (e) => e.message,
          'message',
          'Gemini returned an empty response.',
        )),
      );
    });
  });

  group('Gemini reply JSON', () {
    test('plain JSON is read as is', () {
      expect(GeminiService.decodeJsonObject('{"skinType": "Oily"}'), {'skinType': 'Oily'});
    });

    test('markdown code fences around the JSON are removed', () {
      expect(GeminiService.decodeJsonObject('```json\n{"acne": 40}\n```'), {'acne': 40});
      expect(GeminiService.decodeJsonObject('```\n{"acne": 40}\n```'), {'acne': 40});
    });

    test('unreadable or non-object replies give a friendly error', () {
      final unreadable = throwsA(isA<GeminiException>().having(
        (e) => e.message,
        'message',
        'Gemini sent back something unreadable. Please try again.',
      ));

      expect(() => GeminiService.decodeJsonObject('Sorry, I cannot help.'), unreadable);
      expect(() => GeminiService.decodeJsonObject('[1, 2, 3]'), unreadable);
    });
  });

  group('GeminiException', () {
    test('only quota and server errors are worth retrying', () {
      expect(const GeminiException('quota', statusCode: 429).isTransient, isTrue);
      expect(const GeminiException('overloaded', statusCode: 503).isTransient, isTrue);
      expect(const GeminiException('bad request', statusCode: 400).isTransient, isFalse);
      expect(const GeminiException('offline').isTransient, isFalse);
    });

    test('no face on the photo is not worth retrying', () {
      const error = NoFaceDetectedException('No face detected.');

      expect(error, isA<GeminiException>());
      expect(error.isTransient, isFalse);
      expect(error.toString(), 'No face detected.');
    });
  });

  group('questionnaire answers', () {
    const answers = {
      'Which products do you use?': ['Cleanser', 'Sunscreen'],
      'Any allergies?': ['Fragrance'],
    };

    test('one line per question', () {
      expect(
        QuestionnaireStorage.format(answers),
        '- Which products do you use? Cleanser, Sunscreen\n- Any allergies? Fragrance',
      );
      expect(QuestionnaireStorage.format(const {}), '');
    });

    test('no questionnaire adds nothing to the prompt', () {
      expect(GeminiService.declaredContext(null), '');
      expect(GeminiService.declaredContext(const {}), '');
    });

    test('answers reach the prompt as self-reported statements', () {
      final context = GeminiService.declaredContext(answers);

      expect(context, contains('self-reported'));
      expect(context, contains('- Which products do you use? Cleanser, Sunscreen'));
      expect(context, contains('- Any allergies? Fragrance'));
    });
  });
}
