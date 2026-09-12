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
///
/// Les méthodes publiques de conversion et de stockage des photos sont réutilisées par [SkinProgressStorage].
class SkinAnalysisStorage {
  static const String _field = 'lastSkinAnalysis';
  static const String _imageDirName = 'skin_analysis';

  static DocumentReference<Map<String, dynamic>>? userDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  static Future<Directory> imageDir(String dirName) async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/$dirName');
  }

  /// Convertit un résultat en map Firestore.
  /// On ne stocke que le nom du fichier photo : le chemin absolu du dossier documents
  /// peut changer (ex. mise à jour de l'app sur iOS)
  static Map<String, dynamic> encode(SkinAnalysisResult result, {required String imageFileName}) {
    return {
      ...result.toJson(),
      'imageFileName': imageFileName,
      'analyzedAt': result.analyzedAt?.millisecondsSinceEpoch,
    };
  }

  /// Reconstruit un résultat depuis une map Firestore, ou null si [raw] n'est pas une analyse
  static SkinAnalysisResult? decode(Object? raw, Directory imageDir) {
    if (raw is! Map) return null;

    final data = Map<String, dynamic>.from(raw);
    if (data['concerns'] is Map) {
      data['concerns'] = Map<String, dynamic>.from(data['concerns'] as Map);
    }

    final imageFileName = data['imageFileName'] as String?;
    final imagePath = imageFileName != null ? '${imageDir.path}/$imageFileName' : '';

    final analyzedAtMs = data['analyzedAt'];
    return SkinAnalysisResult.fromJson(data, imagePath: imagePath).copyWith(
      analyzedAt: analyzedAtMs is int
          ? DateTime.fromMillisecondsSinceEpoch(analyzedAtMs)
          : null,
    );
  }

  /// Copie la photo [sourcePath] dans [dir] sous le nom [fileName]
  static Future<void> persistImage(String sourcePath, Directory dir, String fileName) async {
    await dir.create(recursive: true);
    await File(sourcePath).copy('${dir.path}/$fileName');
  }

  /// Attend l'écriture Firestore sans bloquer indéfiniment hors ligne
  static Future<void> writeWithTimeout(Future<void> write) async {
    try {
      await write.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      // Hors ligne : l'écriture est gardée en cache par Firestore et sera synchronisée plus tard
      debugPrint('Sauvegarde en attente de synchronisation');
    }
  }

  /// Retourne la dernière analyse sauvegardée, ou null s'il n'y en a pas
  static Future<SkinAnalysisResult?> load() async {
    final docRef = userDoc();
    if (docRef == null) return null;

    final doc = await docRef.get();
    return decode(doc.data()?[_field], await imageDir(_imageDirName));
  }

  /// Sauvegarde [result] en écrasant l'analyse précédente.
  /// Retourne le résultat avec le chemin de la photo persistée et la date d'analyse.
  static Future<SkinAnalysisResult> save(SkinAnalysisResult result) async {
    final analyzedAt = DateTime.now();
    final docRef = userDoc();
    if (docRef == null) return result.copyWith(analyzedAt: analyzedAt);

    final dir = await imageDir(_imageDirName);
    final imageFileName = 'analysis_${analyzedAt.millisecondsSinceEpoch}.jpg';
    final persistedPath = '${dir.path}/$imageFileName';
    await persistImage(result.imagePath, dir, imageFileName);

    final saved = result.copyWith(imagePath: persistedPath, analyzedAt: analyzedAt);

    // mergeFields remplace entièrement le champ sans toucher au reste du profil
    await writeWithTimeout(docRef.set(
      {_field: encode(saved, imageFileName: imageFileName)},
      SetOptions(mergeFields: [_field]),
    ));

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
