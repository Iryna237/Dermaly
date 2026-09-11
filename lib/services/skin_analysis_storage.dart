import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'gemini_service.dart';

/// Sauvegarde et récupère la dernière analyse de peau de l'utilisateur.
/// - Le résultat est stocké dans Firestore (champ `lastSkinAnalysis` du document `users/{uid}`).
/// - La photo est copiée dans le dossier documents de l'app (la photo caméra est dans le cache).
/// Une nouvelle sauvegarde écrase l'analyse précédente.
class SkinAnalysisStorage {
  static const String _field = 'lastSkinAnalysis';
  static const String _imageDirName = 'skin_analysis';

  static DocumentReference<Map<String, dynamic>>? _userDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  static Future<Directory> _imageDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/$_imageDirName');
  }

  /// Retourne la dernière analyse sauvegardée, ou null s'il n'y en a pas
  static Future<SkinAnalysisResult?> load() async {
    final docRef = _userDoc();
    if (docRef == null) return null;

    final doc = await docRef.get();
    final raw = doc.data()?[_field];
    if (raw is! Map) return null;

    final data = Map<String, dynamic>.from(raw);
    if (data['concerns'] is Map) {
      data['concerns'] = Map<String, dynamic>.from(data['concerns'] as Map);
    }

    // On ne stocke que le nom du fichier : le chemin absolu du dossier documents
    // peut changer (ex. mise à jour de l'app sur iOS)
    final imageFileName = data['imageFileName'] as String?;
    final imagePath = imageFileName != null
        ? '${(await _imageDir()).path}/$imageFileName'
        : '';

    final analyzedAtMs = data['analyzedAt'];
    return SkinAnalysisResult.fromJson(data, imagePath: imagePath).copyWith(
      analyzedAt: analyzedAtMs is int
          ? DateTime.fromMillisecondsSinceEpoch(analyzedAtMs)
          : null,
    );
  }

  /// Sauvegarde [result] en écrasant l'analyse précédente.
  /// Retourne le résultat avec le chemin de la photo persistée et la date d'analyse.
  static Future<SkinAnalysisResult> save(SkinAnalysisResult result) async {
    final analyzedAt = DateTime.now();
    final docRef = _userDoc();
    if (docRef == null) return result.copyWith(analyzedAt: analyzedAt);

    final dir = await _imageDir();
    await dir.create(recursive: true);

    final imageFileName = 'analysis_${analyzedAt.millisecondsSinceEpoch}.jpg';
    final persistedPath = '${dir.path}/$imageFileName';
    await File(result.imagePath).copy(persistedPath);

    final saved = result.copyWith(imagePath: persistedPath, analyzedAt: analyzedAt);

    try {
      // mergeFields remplace entièrement le champ sans toucher au reste du profil
      await docRef.set(
        {
          _field: {
            ...saved.toJson(),
            'imageFileName': imageFileName,
            'analyzedAt': analyzedAt.millisecondsSinceEpoch,
          },
        },
        SetOptions(mergeFields: [_field]),
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // Hors ligne : l'écriture est gardée en cache par Firestore et sera synchronisée plus tard
      debugPrint('Sauvegarde de l\'analyse en attente de synchronisation');
    }

    // Supprimer les anciennes photos d'analyse
    await for (final entity in dir.list()) {
      if (entity is File && entity.path != persistedPath) {
        try {
          await entity.delete();
        } catch (e) {
          debugPrint('Impossible de supprimer l\'ancienne photo: $e');
        }
      }
    }

    return saved;
  }
}
