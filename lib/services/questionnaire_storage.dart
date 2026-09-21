import 'package:cloud_firestore/cloud_firestore.dart';

import 'skin_analysis_storage.dart';

/// Réponses du questionnaire rempli avant une analyse de peau.
///
/// Stockées dans le champ `questionnaire` du document `users/{uid}`, à côté de
/// `lastSkinAnalysis` et `routine`. Elles décrivent ce que la photo ne montre
/// pas : produits utilisés, allergies, réactivité, poussées d'acné.
///
/// Un nouveau questionnaire remplace le précédent.
class QuestionnaireStorage {
  static const String _field = 'questionnaire';

  /// Réponses enregistrées, indexées par intitulé de question.
  /// Null si l'utilisateur n'a jamais rempli le questionnaire.
  static Future<Map<String, List<String>>?> load() async {
    final docRef = SkinAnalysisStorage.userDoc();
    if (docRef == null) return null;

    final doc = await docRef.get();
    final raw = doc.data()?[_field];
    if (raw is! Map) return null;

    final answers = raw['answers'];
    if (answers is! Map) return null;

    final decoded = <String, List<String>>{};
    answers.forEach((question, value) {
      if (value is List) {
        final options = [
          for (final option in value)
            if (option != null) option.toString(),
        ];
        if (options.isNotEmpty) decoded['$question'] = options;
      }
    });

    return decoded.isEmpty ? null : decoded;
  }

  /// Remplace les réponses enregistrées par [answers].
  static Future<void> save(Map<String, List<String>> answers) async {
    final docRef = SkinAnalysisStorage.userDoc();
    if (docRef == null) return;

    // mergeFields remplace entièrement le champ sans toucher au reste du profil
    await SkinAnalysisStorage.writeWithTimeout(docRef.set(
      {
        _field: {
          'answers': answers,
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      },
      SetOptions(mergeFields: [_field]),
    ));
  }

  /// Mise en forme pour un prompt ou pour l'affichage : une ligne par question.
  static String format(Map<String, List<String>> answers) {
    return [
      for (final entry in answers.entries) '- ${entry.key} ${entry.value.join(', ')}',
    ].join('\n');
  }
}
