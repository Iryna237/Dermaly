import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Data model representing the skin analysis results
class SkinAnalysisResult {
  final String imagePath;
  final int overallScore;
  final int hydrationLevel;
  final String skinType;
  final String skinTypeDetails;
  final Map<String, int> concerns;
  final String recommendationSummary;

  SkinAnalysisResult({
    required this.imagePath,
    required this.overallScore,
    required this.hydrationLevel,
    required this.skinType,
    required this.skinTypeDetails,
    required this.concerns,
    required this.recommendationSummary,
  });

  /// Factory constructor to parse the JSON response from Gemini
  factory SkinAnalysisResult.fromJson(
    Map<String, dynamic> json, {
    required String imagePath,
  }) {
    // Parse concerns map safely
    final Map<String, int> parsedConcerns = {};
    if (json['concerns'] is Map) {
      final rawConcerns = json['concerns'] as Map<String, dynamic>;
      rawConcerns.forEach((key, value) {
        if (value is num) {
          parsedConcerns[key] = value.toInt().clamp(0, 100);
        } else if (value is String) {
          parsedConcerns[key] = (int.tryParse(value) ?? 30).clamp(0, 100);
        }
      });
    }

    // Ensure all standard concerns are present
    const defaultConcernKeys = [
      'Dark Spots',
      'Acne',
      'Redness',
      'Pores',
      'Texture / Unevenness',
      'Fine Lines',
    ];

    for (final key in defaultConcernKeys) {
      if (!parsedConcerns.containsKey(key)) {
        parsedConcerns[key] = 30;
      }
    }

    int parseNum(dynamic value, int fallback) {
      if (value is num) return value.toInt().clamp(0, 100);
      if (value is String) return (int.tryParse(value) ?? fallback).clamp(0, 100);
      return fallback;
    }

    return SkinAnalysisResult(
      imagePath: imagePath,
      overallScore: parseNum(json['overallScore'], 78),
      hydrationLevel: parseNum(json['hydrationLevel'], 65),
      skinType: (json['skinType'] as String?)?.trim().isNotEmpty == true
          ? json['skinType'] as String
          : 'Combination Skin',
      skinTypeDetails: (json['skinTypeDetails'] as String?)?.trim().isNotEmpty == true
          ? json['skinTypeDetails'] as String
          : 'Normal on cheeks with slight oiliness in the T-zone',
      concerns: parsedConcerns,
      recommendationSummary:
          (json['recommendationSummary'] as String?)?.trim().isNotEmpty == true
              ? json['recommendationSummary'] as String
              : 'Your skin is in good overall health. Maintain gentle cleansing and hydration.',
    );
  }

  /// Convert model to JSON map
  Map<String, dynamic> toJson() {
    return {
      'overallScore': overallScore,
      'hydrationLevel': hydrationLevel,
      'skinType': skinType,
      'skinTypeDetails': skinTypeDetails,
      'concerns': concerns,
      'recommendationSummary': recommendationSummary,
    };
  }

  /// Default fallback data in case of offline testing or API issue
  factory SkinAnalysisResult.fallback({required String imagePath}) {
    return SkinAnalysisResult(
      imagePath: imagePath,
      overallScore: 82,
      hydrationLevel: 70,
      skinType: 'Combination Skin',
      skinTypeDetails: 'Mild shine on forehead and nose, normal hydration on cheeks',
      concerns: {
        'Dark Spots': 35,
        'Acne': 25,
        'Redness': 18,
        'Pores': 50,
        'Texture / Unevenness': 40,
        'Fine Lines': 15,
      },
      recommendationSummary:
          'Your skin barrier is healthy. Consider a gentle foaming cleanser, a niacinamide serum for pore control, and daily broad-spectrum SPF.',
    );
  }
}

/// Service class handling communications with the Gemini Multimodal API
class GeminiService {
  static const String _defaultModel = 'gemini-3.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Returns the configured API key from .env
  /// Returns the configured API key from .env
  static String get apiKey {
    final key = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (key.trim().isEmpty) {
      throw Exception(
        'GEMINI_API_KEY is not configured in your .env file.',
      );
    }
    return key.trim();
  }

  /// Analyzes a facial photo and returns a structured [SkinAnalysisResult]
  static Future<SkinAnalysisResult> analyzeSkin(String imagePath) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw Exception(
        'Gemini API key is not configured. Please set GEMINI_API_KEY in your .env file.',
      );
    }

    // 1. Read image bytes (either local file or asset)
    final Uint8List imageBytes;
    final String mimeType;

    if (imagePath.startsWith('assets/')) {
      final byteData = await rootBundle.load(imagePath);
      imageBytes = byteData.buffer.asUint8List();
      mimeType = imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    } else {
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found at path: $imagePath');
      }
      imageBytes = await file.readAsBytes();
      final ext = imagePath.split('.').last.toLowerCase();
      mimeType = (ext == 'png') ? 'image/png' : 'image/jpeg';
    }

    final base64Image = base64Encode(imageBytes);

    // 2. Prepare structured system prompt for Gemini
    const prompt = '''
You are a certified professional dermatologist and skincare expert AI for Dermaly.
Carefully examine this facial image and perform a detailed skin diagnosis.

Evaluate the following metrics:
1. overallScore: An overall skin health score from 0 to 100 (where 100 is flawless health).
2. hydrationLevel: Skin moisture/hydration percentage from 0 to 100.
3. skinType: Primary skin type (e.g. "Combination Skin", "Oily Skin", "Dry Skin", "Normal Skin", or "Sensitive Skin").
4. skinTypeDetails: A precise 1-sentence explanation of the skin characteristics (e.g. "Slightly oily in T-zone, balanced cheeks").
5. concerns: Estimated severity from 0 to 100 (0 = none, 100 = severe) for EACH of these exact keys:
   - "Dark Spots"
   - "Acne"
   - "Redness"
   - "Pores"
   - "Texture / Unevenness"
   - "Fine Lines"
6. recommendationSummary: A professional, clear and encouraging skincare recommendation summary (2 to 3 sentences) tailored to the observed skin conditions.

Return ONLY a valid JSON object matching this exact format:
{
  "overallScore": 78,
  "hydrationLevel": 68,
  "skinType": "Combination Skin",
  "skinTypeDetails": "Oily in T-zone, normal on cheeks",
  "concerns": {
    "Dark Spots": 40,
    "Acne": 25,
    "Redness": 20,
    "Pores": 55,
    "Texture / Unevenness": 35,
    "Fine Lines": 15
  },
  "recommendationSummary": "Your skin has good overall elasticity and tone. We suggest a balancing cleanser and a gentle moisturizer to maintain barrier hydration."
}
''';

    // 3. Make HTTP request to Gemini API
    final url = Uri.parse('$_baseUrl/$_defaultModel:generateContent?key=$key');

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
      }
    });

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode != 200) {
        debugPrint('Gemini API Error Status: ${response.statusCode}');
        debugPrint('Gemini API Error Body: ${response.body}');
        
        // Parse error message if available
        String errorMessage = 'HTTP ${response.statusCode}';
        try {
          final errJson = jsonDecode(response.body);
          if (errJson['error']?['message'] != null) {
            errorMessage = errJson['error']['message'];
          }
        } catch (_) {}

        throw Exception('Gemini API Error ($errorMessage)');
      }

      // 4. Parse Gemini response
      final Map<String, dynamic> responseData = jsonDecode(response.body);
      final candidates = responseData['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini returned no candidates in response.');
      }

      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null || parts.isEmpty) {
        throw Exception('Gemini response contains no parts.');
      }

      final String rawText = parts.first['text'] as String? ?? '';
      
      // Clean possible markdown code fences (```json ... ```)
      String cleanJson = rawText.trim();
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson
            .replaceFirst(RegExp(r'^```json\s*'), '')
            .replaceFirst(RegExp(r'^```\s*'), '')
            .replaceAll(RegExp(r'\s*```$'), '');
      }

      final Map<String, dynamic> parsedJson = jsonDecode(cleanJson);
      return SkinAnalysisResult.fromJson(parsedJson, imagePath: imagePath);
    } on SocketException catch (e) {
      throw Exception('Network error: please check your internet connection ($e)');
    } catch (e) {
      debugPrint('Error analyzing skin with Gemini: $e');
      rethrow;
    }
  }
}
