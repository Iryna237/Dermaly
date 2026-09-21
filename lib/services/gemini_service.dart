import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/routine_product.dart';

/// Data model representing the skin analysis results
class SkinAnalysisResult {
  final String imagePath;
  final int overallScore;
  final int hydrationLevel;
  final String skinType;
  final String skinTypeDetails;
  final Map<String, int> concerns;
  final String recommendationSummary;

  /// Date de l'analyse (renseignée lors de la sauvegarde)
  final DateTime? analyzedAt;

  SkinAnalysisResult({
    required this.imagePath,
    required this.overallScore,
    required this.hydrationLevel,
    required this.skinType,
    required this.skinTypeDetails,
    required this.concerns,
    required this.recommendationSummary,
    this.analyzedAt,
  });

  SkinAnalysisResult copyWith({String? imagePath, DateTime? analyzedAt}) {
    return SkinAnalysisResult(
      imagePath: imagePath ?? this.imagePath,
      overallScore: overallScore,
      hydrationLevel: hydrationLevel,
      skinType: skinType,
      skinTypeDetails: skinTypeDetails,
      concerns: concerns,
      recommendationSummary: recommendationSummary,
      analyzedAt: analyzedAt ?? this.analyzedAt,
    );
  }

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

    // Ordre d'affichage fixe : Firestore ne conserve pas l'ordre des clés d'une map
    final orderedConcerns = <String, int>{
      for (final key in defaultConcernKeys) key: parsedConcerns[key] ?? 30,
    };
    parsedConcerns.forEach((key, value) => orderedConcerns.putIfAbsent(key, () => value));

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
      concerns: orderedConcerns,
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

/// Erreur renvoyée par l'API Gemini. Le code HTTP permet de distinguer une panne
/// passagère (surcharge, quota momentané) d'une vraie erreur de configuration.
class GeminiException implements Exception {
  final String message;
  final int? statusCode;

  const GeminiException(this.message, {this.statusCode});

  /// 429 (quota) et 5xx (surcharge/panne) : une nouvelle tentative a des chances d'aboutir.
  bool get isTransient =>
      statusCode == 429 || (statusCode != null && statusCode! >= 500);

  @override
  String toString() => message;
}

/// Photo inutilisable : aucun visage humain exploitable dessus.
/// L'utilisateur doit reprendre une photo, réessayer avec la même ne sert à rien.
class NoFaceDetectedException extends GeminiException {
  const NoFaceDetectedException(super.message);
}

/// Service class handling communications with the Gemini Multimodal API
class GeminiService {
  static const String _defaultModel = 'gemini-3.5-flash';
  static const String _defaultFallbackModels =
      'gemini-3.6-flash,gemini-3.5-flash-lite';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const Duration _requestTimeout = Duration(seconds: 40);

  /// Temps maximum consacré aux nouvelles tentatives : évite de faire patienter
  /// l'utilisateur plusieurs minutes quand l'API ne repond plus du tout.
  static const Duration _retryBudget = Duration(seconds: 90);

  /// Pauses entre deux tentatives (backoff exponentiel) sur erreur passagère.
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  /// Message montré à l'utilisateur quand tous les modèles restent saturés.
  static const String _overloadedMessage =
      'Our AI is very busy right now. Please try again in a few moments.';

  static String _envOrDefault(String key, String fallback) {
    final value = dotenv.env[key]?.trim();
    return (value == null || value.isEmpty) ? fallback : value;
  }

  /// Modèle utilisé en priorité, surchargeable via `GEMINI_MODEL` dans .env
  static String get model => _envOrDefault('GEMINI_MODEL', _defaultModel);

  /// Modèles essayés si le principal reste indisponible, du plus au moins capable.
  /// Surchargeable via `GEMINI_FALLBACK_MODEL` (liste séparée par des virgules).
  static List<String> get fallbackModels => [
        for (final name
            in _envOrDefault('GEMINI_FALLBACK_MODEL', _defaultFallbackModels)
                .split(','))
          if (name.trim().isNotEmpty) name.trim(),
      ];

  /// Returns the configured API key from .env
  static String get apiKey {
    final key = dotenv.env['GEMINI_API_KEY']?.trim() ?? '';
    if (key.isEmpty) {
      throw const GeminiException(
        'Gemini API key is not configured. Please set GEMINI_API_KEY in your .env file.',
      );
    }
    return key;
  }

  /// Extrait le message d'erreur renvoyé par l'API, sinon le code HTTP.
  static String _errorMessageFrom(http.Response response) {
    try {
      final message = (jsonDecode(response.body))['error']?['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
    } catch (_) {}
    return 'HTTP ${response.statusCode}';
  }

  /// Appelle `generateContent` et renvoie la réponse JSON décodée.
  ///
  /// Les erreurs passagères (429/5xx, très fréquentes quand le modèle est saturé)
  /// sont réessayées avec un backoff exponentiel ; si le modèle principal reste
  /// indisponible, la requête est rejouée sur les [fallbackModels]. Les autres erreurs
  /// (clé invalide, modèle inconnu, requête malformée) échouent immédiatement.
  static Future<Map<String, dynamic>> _generateContent(
    Map<String, dynamic> payload,
  ) async {
    final key = apiKey;
    final body = jsonEncode(payload);
    final models = <String>{model, ...fallbackModels};

    GeminiException? lastError;
    final deadline = DateTime.now().add(_retryBudget);

    attempts:
    for (final modelName in models) {
      for (var attempt = 0; attempt <= _retryDelays.length; attempt++) {
        http.Response? response;
        try {
          response = await http
              .post(
                Uri.parse('$_baseUrl/$modelName:generateContent'),
                // Clé dans l'en-tête plutôt que dans l'URL pour qu'elle n'apparaisse pas dans les logs
                headers: {
                  'Content-Type': 'application/json',
                  'x-goog-api-key': key,
                },
                body: body,
              )
              .timeout(_requestTimeout);
        } on SocketException {
          throw const GeminiException(
            'Network error: please check your internet connection.',
          );
        } on TimeoutException {
          lastError = const GeminiException(
            'Gemini took too long to respond.',
            statusCode: 504,
          );
        }

        if (response != null) {
          if (response.statusCode == 200) {
            return jsonDecode(response.body) as Map<String, dynamic>;
          }

          debugPrint(
            'Gemini $modelName error ${response.statusCode}: ${response.body}',
          );
          final error = GeminiException(
            _errorMessageFrom(response),
            statusCode: response.statusCode,
          );
          // Modèle absent ou indisponible pour cette clé : passer au modèle suivant
          if (error.statusCode == 404) {
            lastError = error;
            break;
          }
          // Clé invalide, requête refusée... : réessayer ne changera rien
          if (!error.isTransient) throw error;
          lastError = error;
        }

        // Budget épuisé : inutile d'immobiliser l'écran plus longtemps
        if (!DateTime.now().isBefore(deadline)) break attempts;

        if (attempt < _retryDelays.length) {
          await Future.delayed(_retryDelays[attempt]);
        }
      }
      debugPrint('Gemini: $modelName still unavailable, trying the next model.');
    }

    final error = lastError;
    if (error == null || error.isTransient) {
      // Tous les modèles sont saturés : message clair plutôt que le jargon de l'API
      throw GeminiException(_overloadedMessage, statusCode: error?.statusCode);
    }
    throw error;
  }

  /// Concatène le texte des `parts`, en ignorant les parties de réflexion du modèle.
  static String _textFrom(Map<String, dynamic> responseData) {
    final candidates = responseData['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const GeminiException('Gemini returned no candidates in response.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final text = [
      for (final part in content?['parts'] as List? ?? const [])
        if (part is Map && part['thought'] != true && part['text'] is String)
          part['text'] as String,
    ].join().trim();

    if (text.isEmpty) {
      throw const GeminiException('Gemini returned an empty response.');
    }
    return text;
  }

  /// Décode la réponse JSON du modèle, en retirant les éventuelles balises de
  /// code markdown que Gemini ajoute parfois autour du JSON.
  static Map<String, dynamic> _decodeJsonObject(String text) {
    var clean = text.trim();
    if (clean.startsWith('```')) {
      clean = clean
          .replaceFirst(RegExp(r'^```json\s*'), '')
          .replaceFirst(RegExp(r'^```\s*'), '')
          .replaceAll(RegExp(r'\s*```$'), '');
    }

    const unreadable = GeminiException(
      'Gemini sent back something unreadable. Please try again.',
    );

    final Object? parsed;
    try {
      parsed = jsonDecode(clean);
    } on FormatException catch (e) {
      debugPrint('Gemini returned invalid JSON: $e');
      throw unreadable;
    }
    if (parsed is! Map<String, dynamic>) throw unreadable;
    return parsed;
  }

  /// Analyzes a facial photo and returns a structured [SkinAnalysisResult]
  static Future<SkinAnalysisResult> analyzeSkin(String imagePath) async {
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

STEP 1 - Check whether the image can be used at all.
It is usable ONLY if it shows the skin of a real, living human face, photographed
directly, close enough, sharp enough and lit well enough to judge the skin.
It is NOT usable if it shows anything else (an object, an animal, a landscape, text,
a body part other than a face), a drawing, a cartoon, a 3D render, a photo of a screen
or of a printed picture, a face fully covered by a mask, or a face too dark, too
blurry, too small or too far away to assess the skin.
Judge only what is in the image: never assume a face is there because you were asked
for a skin analysis.
If the image is NOT usable, reply with ONLY this JSON object and nothing else:
{"faceDetected": false, "reason": "<one short sentence naming what the image shows instead>"}

STEP 2 - Only if the image IS usable, perform a detailed skin diagnosis.

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
  "faceDetected": true,
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

    // 3. Send the request (retries and model fallback handled by _generateContent)
    final responseData = await _generateContent({
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

    // 4. Parse Gemini response
    final parsed = _decodeJsonObject(_textFrom(responseData));

    // Gemini valide la photo avant de diagnostiquer. Strict : sans `faceDetected: true`
    // explicite, on refuse plutôt que d'inventer un diagnostic sur une photo
    // qui ne montre pas de visage
    if (parsed['faceDetected'] != true) {
      debugPrint('Gemini rejected the photo: ${parsed['reason']}');
      throw const NoFaceDetectedException(
        'We could not find a face to analyze in this photo. Take a new one with '
        'your whole face visible, centered, close to the camera and well lit.',
      );
    }

    return SkinAnalysisResult.fromJson(parsed, imagePath: imagePath);
  }

  /// Propose une routine de soin adaptée à [analysis] : quels produits utiliser,
  /// et à quel moment de la journée.
  ///
  /// Chaque produit porte son moment d'application ; ceux du matin ET du soir
  /// reviennent dans les deux listes de la routine.
  static Future<List<RoutineProduct>> recommendRoutine(
    SkinAnalysisResult analysis,
  ) async {
    final concerns = [
      for (final entry in analysis.concerns.entries) '- ${entry.key}: ${entry.value}/100',
    ].join('\n');

    final prompt = '''
You are a certified dermatologist building a skincare routine for a Dermaly user.

Their latest skin analysis:
- Skin type: ${analysis.skinType} (${analysis.skinTypeDetails})
- Overall skin health: ${analysis.overallScore}/100
- Hydration: ${analysis.hydrationLevel}/100
- Concerns, 0 = none and 100 = severe:
$concerns

Recommend 4 to 6 real, widely available products that treat THESE concerns,
worst ones first. Cover cleansing, treatment, hydration and daytime sun
protection. Never recommend two products that conflict (for example retinol and
a strong exfoliating acid in the same evening).

For each product give:
- "category": one word among "Cleanse", "Treat", "Hydrate", "Protect", "Exfoliate"
- "name": the actual product name, brand included
- "description": one short sentence saying what it does for THIS skin
- "time": "morning" if it belongs to the morning routine only, "evening" if it
  belongs to the evening routine only, "both" if it is applied morning and
  evening. Sunscreen is always "morning". Retinol and other actives that
  increase sun sensitivity are always "evening". A cleanser or a moisturizer
  used twice a day is "both".

Return ONLY a valid JSON object matching this exact format:
{
  "products": [
    {
      "category": "Cleanse",
      "name": "CeraVe Foaming Facial Cleanser",
      "description": "Removes excess oil without stripping the skin barrier.",
      "time": "both"
    }
  ]
}
''';

    final responseData = await _generateContent({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.4,
      }
    });

    final parsed = _decodeJsonObject(_textFrom(responseData));
    final products = [
      for (final item in parsed['products'] as List? ?? const [])
        ?RoutineProduct.fromJson(item),
    ];

    if (products.isEmpty) {
      throw const GeminiException(
        'No routine could be built from this analysis. Please try again.',
      );
    }
    return products;
  }

  /// Envoie une conversation à Gemini et retourne le texte de la réponse (utilisé par le chat).
  /// [contents] : tours de conversation au format de l'API (`role` : `user` ou `model`).
  static Future<String> generateText({
    required List<Map<String, dynamic>> contents,
    String? systemInstruction,
    double temperature = 0.7,
  }) async {
    final responseData = await _generateContent({
      if (systemInstruction != null)
        'system_instruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
      'contents': contents,
      'generationConfig': {'temperature': temperature},
    });

    return _textFrom(responseData);
  }
}
