import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';
import 'skin_analysis_storage.dart';

/// Historique des scans mensuels (Skin Progress), indépendant de la Skin Analysis.
/// - Un document par mois : `users/{uid}/skinScans/{yyyy-MM}`.
///   Un seul scan par mois : l'écran Skin Progress ne propose un nouveau scan
///   qu'une fois le mois terminé.
/// - La photo de chaque mois est conservée dans le dossier documents de l'app (`skin_progress/`).
class SkinProgressStorage {
  static const String _collection = 'skinScans';
  static const String _imageDirName = 'skin_progress';

  static CollectionReference<Map<String, dynamic>>? _scans() {
    return SkinAnalysisStorage.userDoc()?.collection(_collection);
  }

  /// Clé du mois (date locale), utilisée comme identifiant du document
  static String monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  static Future<List<SkinAnalysisResult>> _decodeAll(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final dir = await SkinAnalysisStorage.imageDir(_imageDirName);
    final scans = snapshot.docs
        .map((doc) => SkinAnalysisStorage.decode(doc.data(), dir))
        .whereType<SkinAnalysisResult>()
        .where((scan) => scan.analyzedAt != null)
        .toList()
      ..sort((a, b) => a.analyzedAt!.compareTo(b.analyzedAt!));

    // Un seul point par mois : le scan le plus récent représente son mois.
    // Regroupe aussi les anciens scans quotidiens, qui restent en base.
    final byMonth = <String, SkinAnalysisResult>{};
    for (final scan in scans) {
      byMonth[monthKey(scan.analyzedAt!)] = scan;
    }
    return byMonth.values.toList();
  }

  /// Historique trié du plus ancien au plus récent
  static Future<List<SkinAnalysisResult>> loadHistory() async {
    final scans = _scans();
    if (scans == null) return [];
    return _decodeAll(await scans.get());
  }

  /// Historique en temps réel : émet d'abord le cache local puis se met à jour
  /// (réponse du serveur, nouveau scan du mois)
  static Stream<List<SkinAnalysisResult>> watchHistory() {
    final scans = _scans();
    if (scans == null) return Stream.value(const []);
    return scans.snapshots().asyncMap(_decodeAll);
  }

  /// Enregistre le scan du mois.
  /// Retourne le scan avec le chemin de la photo persistée et la date du scan.
  static Future<SkinAnalysisResult> saveMonthScan(SkinAnalysisResult result) async {
    final analyzedAt = DateTime.now();
    final scans = _scans();
    if (scans == null) return result.copyWith(analyzedAt: analyzedAt);

    final month = monthKey(analyzedAt);
    final dir = await SkinAnalysisStorage.imageDir(_imageDirName);
    final imageFileName = 'scan_${month}_${analyzedAt.millisecondsSinceEpoch}.jpg';
    // Sur le web, pas de copie : on garde le chemin fourni par le sélecteur de photo
    var imagePath = result.imagePath;
    if (dir != null) {
      imagePath = '${dir.path}/$imageFileName';
      await SkinAnalysisStorage.persistImage(result.imagePath, dir, imageFileName);
    }

    final saved = result.copyWith(imagePath: imagePath, analyzedAt: analyzedAt);

    await SkinAnalysisStorage.writeWithTimeout(
      scans.doc(month).set(SkinAnalysisStorage.encode(saved, imageFileName: imageFileName)),
    );

    // Supprimer les photos des scans déjà faits ce mois-ci (remplacés, anciens scans
    // quotidiens compris) ; les photos des autres mois sont gardées
    if (dir == null) return saved;
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && name.startsWith('scan_$month') && name != imageFileName) {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint('Impossible de supprimer l\'ancienne photo du mois: $e');
        }
      }
    }

    return saved;
  }
}
