import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/routine_product.dart';
import 'skin_analysis_storage.dart';

/// Cherche la photo d'un produit recommandé dans Open Beauty Facts.
///
/// Base communautaire, libre et sans clé d'API. Sa couverture est partielle :
/// les marques très diffusées y sont, d'autres non. Un produit sans photo garde
/// l'illustration de sa catégorie, il n'y a donc jamais de carte vide.
///
/// Les résultats sont mis en cache dans `productImages`, partagé par tous les
/// utilisateurs : un produit n'est cherché qu'une fois pour toute l'application.
class ProductImageService {
  static const String _collectionName = 'productImages';
  static const String _host = 'world.openbeautyfacts.org';

  /// Open Beauty Facts demande un agent identifiable
  static const Map<String, String> _headers = {
    'User-Agent': 'Dermaly/1.0 (Flutter skincare app)',
  };

  static const Duration _timeout = Duration(seconds: 12);

  /// Une recherche infructueuse est retentée après ce délai : la base grandit,
  /// un produit absent aujourd'hui peut y figurer dans un mois.
  static const Duration _missRetryAfter = Duration(days: 30);

  /// Mots qui désignent un type de produit. Si un candidat en porte un que le
  /// produit recherché n'a pas, c'est une autre référence de la même gamme :
  /// le nettoyant Hydro Boost n'est pas l'hydratant Hydro Boost.
  static const List<String> _typeWords = [
    'cleanser', 'cleansing', 'moisturizer', 'moisturiser', 'serum', 'sunscreen',
    'sunblock', 'exfoliant', 'exfoliator', 'toner', 'mask', 'shampoo', 'balm',
    'oil', 'scrub', 'lotion', 'gel', 'cream', 'water', 'wash', 'spray',
  ];

  /// Complète [products] avec l'URL de leur photo quand elle existe.
  /// Les produits sont retournés dans le même ordre, avec ou sans photo.
  static Future<List<RoutineProduct>> resolve(List<RoutineProduct> products) async {
    final resolved = <RoutineProduct>[];

    for (final product in products) {
      String? url;
      try {
        url = await _imageFor(product.name);
      } catch (e) {
        // Une photo manquante ne doit jamais faire échouer une recommandation
        debugPrint('Erreur recherche image pour ${product.name}: $e');
      }
      resolved.add(url == null ? product : product.withImage(url));
    }

    return resolved;
  }

  static Future<String?> _imageFor(String name) async {
    final cache = FirebaseFirestore.instance.collection(_collectionName).doc(_slug(name));

    final cached = await cache.get();
    if (cached.exists) {
      final data = cached.data();
      final url = data?['imageUrl'] as String?;
      if (url != null && url.isNotEmpty) return url;

      // Absence déjà constatée : ne pas réinterroger avant l'expiration
      final fetchedAt = data?['fetchedAt'];
      if (fetchedAt is int) {
        final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(fetchedAt));
        if (age < _missRetryAfter) return null;
      }
    }

    final url = await _search(name);

    await SkinAnalysisStorage.writeWithTimeout(cache.set({
      'name': name,
      'imageUrl': url,
      'fetchedAt': DateTime.now().millisecondsSinceEpoch,
    }));

    return url;
  }

  static Future<String?> _search(String name) async {
    final uri = Uri.https(_host, '/cgi/search.pl', {
      'search_terms': name,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '5',
      'fields': 'product_name,brands,image_front_small_url',
    });

    final response = await http.get(uri, headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) {
      debugPrint('Open Beauty Facts a répondu ${response.statusCode} pour $name');
      return null;
    }

    final body = jsonDecode(response.body);
    if (body is! Map) return null;

    for (final candidate in body['products'] as List? ?? const []) {
      if (candidate is! Map) continue;

      final url = (candidate['image_front_small_url'] as Object?)?.toString();
      if (url == null || url.isEmpty) continue;

      final label = '${candidate['brands'] ?? ''} ${candidate['product_name'] ?? ''}';
      if (_matches(name, label)) return url;
    }

    return null;
  }

  /// Vrai si [label] désigne bien le produit cherché.
  ///
  /// Deux conditions : l'essentiel des mots recherchés s'y retrouve, et le
  /// candidat n'ajoute pas un type de produit absent de la recherche.
  static bool _matches(String name, String label) {
    final wanted = _words(name);
    final found = _words(label);
    if (wanted.isEmpty || found.isEmpty) return false;

    final common = wanted.where(found.contains).length;
    if (common / wanted.length < 0.6) return false;

    for (final word in _typeWords) {
      if (found.contains(word) && !wanted.contains(word)) return false;
    }
    return true;
  }

  /// Mots significatifs : sans ponctuation, sans pourcentages, sans mots vides
  static Set<String> _words(String text) {
    const stopWords = {'the', 'and', 'for', 'with', 'a', 'of', 'spf', 'broad', 'spectrum'};

    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w) && int.tryParse(w) == null)
        .toSet();
  }

  static String _slug(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    // Firestore limite la taille d'un identifiant de document
    return slug.length > 120 ? slug.substring(0, 120) : slug;
  }
}
