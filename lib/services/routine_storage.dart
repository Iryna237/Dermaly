import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/routine_product.dart';
import 'skin_analysis_storage.dart';

/// Routine de soin de l'utilisateur, telle que proposée par Gemini à partir de
/// sa dernière analyse de peau.
///
/// Stockée dans le champ `routine` du document `users/{uid}`, à côté de
/// `lastSkinAnalysis`. Une nouvelle recommandation remplace la précédente.
class RoutineStorage {
  static const String _field = 'routine';

  /// Retourne la routine sauvegardée, ou null si l'utilisateur n'en a pas encore.
  /// Une liste vide est traitée comme une absence de routine.
  static Future<List<RoutineProduct>?> load() async {
    return (await loadSaved())?.products;
  }

  /// Comme [load], mais avec la date d'enregistrement : les rappels s'en servent
  /// pour ne pas journaliser de notifications antérieures à la routine.
  static Future<({List<RoutineProduct> products, DateTime? updatedAt})?> loadSaved() async {
    final docRef = SkinAnalysisStorage.userDoc();
    if (docRef == null) return null;

    final doc = await docRef.get();
    final raw = doc.data()?[_field];
    if (raw is! Map) return null;

    final products = [
      for (final item in raw['products'] as List? ?? const [])
        ?RoutineProduct.fromJson(item),
    ];
    if (products.isEmpty) return null;

    final updatedAt = raw['updatedAt'];
    return (
      products: products,
      updatedAt: updatedAt is int
          ? DateTime.fromMillisecondsSinceEpoch(updatedAt)
          : null,
    );
  }

  /// Remplace la routine par [products].
  static Future<void> save(List<RoutineProduct> products) async {
    final docRef = SkinAnalysisStorage.userDoc();
    if (docRef == null) return;

    // mergeFields remplace entièrement le champ sans toucher au reste du profil
    await SkinAnalysisStorage.writeWithTimeout(docRef.set(
      {
        _field: {
          'products': [for (final product in products) product.toJson()],
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        },
      },
      SetOptions(mergeFields: [_field]),
    ));
  }
}
