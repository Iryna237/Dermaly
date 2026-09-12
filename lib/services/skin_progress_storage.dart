import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';
import 'skin_analysis_storage.dart';

/// Historique des scans quotidiens (Skin Progress), indépendant de la Skin Analysis.
/// - Un document par jour : `users/{uid}/skinScans/{yyyy-MM-dd}`.
///   Un nouveau scan le même jour remplace celui du jour.
/// - La photo de chaque jour est conservée dans le dossier documents de l'app (`skin_progress/`).
class SkinProgressStorage {
  static const String _collection = 'skinScans';
  static const String _imageDirName = 'skin_progress';

  static CollectionReference<Map<String, dynamic>>? _scans() {
    return SkinAnalysisStorage.userDoc()?.collection(_collection);
  }

  /// Clé du jour (date locale), utilisée comme identifiant du document
  static String dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static Future<List<SkinAnalysisResult>> _decodeAll(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) async {
    final dir = await SkinAnalysisStorage.imageDir(_imageDirName);
    return snapshot.docs
        .map((doc) => SkinAnalysisStorage.decode(doc.data(), dir))
        .whereType<SkinAnalysisResult>()
        .where((scan) => scan.analyzedAt != null)
        .toList()
      ..sort((a, b) => a.analyzedAt!.compareTo(b.analyzedAt!));
  }

  /// Historique trié du plus ancien au plus récent
  static Future<List<SkinAnalysisResult>> loadHistory() async {
    final scans = _scans();
    if (scans == null) return [];
    return _decodeAll(await scans.get());
  }

  /// Historique en temps réel : émet d'abord le cache local puis se met à jour
  /// (réponse du serveur, nouveau scan du jour)
  static Stream<List<SkinAnalysisResult>> watchHistory() {
    final scans = _scans();
    if (scans == null) return Stream.value(const []);
    return scans.snapshots().asyncMap(_decodeAll);
  }

  /// Enregistre le scan du jour (remplace un éventuel scan déjà fait aujourd'hui).
  /// Retourne le scan avec le chemin de la photo persistée et la date du scan.
  static Future<SkinAnalysisResult> saveTodayScan(SkinAnalysisResult result) async {
    final analyzedAt = DateTime.now();
    final scans = _scans();
    if (scans == null) return result.copyWith(analyzedAt: analyzedAt);

    final today = dayKey(analyzedAt);
    final dir = await SkinAnalysisStorage.imageDir(_imageDirName);
    final imageFileName = 'scan_${today}_${analyzedAt.millisecondsSinceEpoch}.jpg';
    await SkinAnalysisStorage.persistImage(result.imagePath, dir, imageFileName);

    final saved = result.copyWith(
      imagePath: '${dir.path}/$imageFileName',
      analyzedAt: analyzedAt,
    );

    await SkinAnalysisStorage.writeWithTimeout(
      scans.doc(today).set(SkinAnalysisStorage.encode(saved, imageFileName: imageFileName)),
    );

    // Supprimer la photo d'un scan déjà fait aujourd'hui (remplacé) ; les photos des autres jours sont gardées
    await for (final entity in dir.list()) {
      final name = entity.uri.pathSegments.last;
      if (entity is File && name.startsWith('scan_${today}_') && name != imageFileName) {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint('Impossible de supprimer l\'ancienne photo du jour: $e');
        }
      }
    }

    return saved;
  }
}
