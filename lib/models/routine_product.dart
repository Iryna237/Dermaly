import 'package:flutter/material.dart';

/// Moment de la journée où un produit s'applique.
enum RoutineTime { morning, evening, both }

/// Produit d'une routine de soin, proposé par Gemini à partir de l'analyse de peau.
///
/// L'icône et l'illustration ne viennent pas du modèle : elles sont déduites de
/// la catégorie, pour que la carte de routine garde exactement son apparence.
class RoutineProduct {
  final String category;
  final String name;
  final String description;
  final RoutineTime time;

  const RoutineProduct({
    required this.category,
    required this.name,
    required this.description,
    this.time = RoutineTime.both,
  });

  /// Vrai si le produit s'applique le matin (matin seul ou matin et soir)
  bool get isMorning => time != RoutineTime.evening;

  /// Vrai si le produit s'applique le soir (soir seul ou matin et soir)
  bool get isEvening => time != RoutineTime.morning;

  /// Libellé du moment, affiché sur la fiche produit
  String get timeLabel => switch (time) {
        RoutineTime.morning => 'Morning',
        RoutineTime.evening => 'Night',
        RoutineTime.both => 'Morning & Night',
      };

  IconData get icon {
    final key = category.toLowerCase();
    if (key.contains('cleans')) return Icons.bubble_chart_outlined;
    if (key.contains('protect') || key.contains('spf') || key.contains('sun')) {
      return Icons.wb_sunny_outlined;
    }
    if (key.contains('hydrat') || key.contains('moistur')) return Icons.water_drop_outlined;
    if (key.contains('treat') || key.contains('serum')) return Icons.science_outlined;
    if (key.contains('exfoli')) return Icons.auto_awesome_outlined;
    if (key.contains('mask')) return Icons.spa_outlined;
    if (key.contains('eye')) return Icons.visibility_outlined;
    return Icons.medication_outlined;
  }

  String get imagePath {
    final key = category.toLowerCase();
    if (key.contains('cleans')) return 'assets/images/cleanser.png';
    if (key.contains('protect') || key.contains('spf') || key.contains('sun')) {
      return 'assets/images/sunscreen.png';
    }
    if (key.contains('hydrat') || key.contains('moistur')) {
      return 'assets/images/moisturizer.png';
    }
    return 'assets/images/serum.png';
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'name': name,
        'description': description,
        'time': time.name,
      };

  /// Reconstruit un produit depuis une map Gemini ou Firestore.
  /// Retourne null si le produit n'a pas de nom : une fiche vide n'a rien à faire
  /// dans une routine.
  static RoutineProduct? fromJson(Object? raw) {
    if (raw is! Map) return null;

    final name = (raw['name'] as Object?)?.toString().trim() ?? '';
    if (name.isEmpty) return null;

    final category = (raw['category'] as Object?)?.toString().trim();
    final description = (raw['description'] as Object?)?.toString().trim();

    return RoutineProduct(
      category: category == null || category.isEmpty ? 'Care' : category,
      name: name,
      description: description == null || description.isEmpty
          ? 'Recommended for your skin.'
          : description,
      time: _timeFrom(raw['time']),
    );
  }

  /// Un moment non reconnu vaut « matin et soir » : mieux vaut proposer le produit
  /// aux deux moments que de le faire disparaître de la routine.
  static RoutineTime _timeFrom(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    if (value == 'morning' || value == 'am') return RoutineTime.morning;
    if (value == 'evening' || value == 'night' || value == 'pm') {
      return RoutineTime.evening;
    }
    return RoutineTime.both;
  }
}
