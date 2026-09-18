import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isAuthenticated => _auth.currentUser != null;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<String> getUserFirstName() async {
    final user = _auth.currentUser;
    if (user == null) return 'Utilisateur';

    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim().split(' ')[0];
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final fullName = (data['fullName'] ?? data['name'] ?? '')
            .toString()
            .trim();
        if (fullName.isNotEmpty) {
          return fullName.split(' ')[0];
        }
      }
    } catch (e) {
      debugPrint("Erreur récupération nom depuis Firestore: $e");
    }

    if (user.email != null && user.email!.trim().isNotEmpty) {
      return user.email!.trim().split('@')[0];
    }

    return 'Utilisateur';
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (e) {
      debugPrint("Erreur récupération profil Firestore: $e");
    }
    return null;
  }

  /// Met à jour le profil dans Firestore.
  /// ⚠️ N'envoie PAS de photoBase64 à FirebaseAuth (limite de longueur).
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Nettoyer : retirer photoBase64/photoUrl avant Firestore pour éviter
      // de polluer le document ou de déclencher updatePhotoURL
      final firestoreData = Map<String, dynamic>.from(data);

      // Si on met à jour le nom → Firestore + FirebaseAuth
      if (firestoreData.containsKey('fullName')) {
        await user.updateDisplayName(firestoreData['fullName']);
      }

      // photoUrl : on l'envoie à FirebaseAuth UNIQUEMENT si court (URL classique)
      final photoUrl = firestoreData['photoUrl'];
      if (photoUrl is String && photoUrl.length < 2000) {
        await user.updatePhotoURL(photoUrl);
      }

      // Écrire dans Firestore (tout, y compris photoBase64)
      await _firestore.collection('users').doc(user.uid).update(firestoreData);
    } catch (e) {
      debugPrint("Erreur mise à jour profil Firestore: $e");
      rethrow;
    }
  }

  /// Encode l'image en base64 et la stocke dans Firestore.
  /// Retourne la chaîne base64 ou null si l'utilisateur n'est pas connecté.
  Future<String?> uploadProfilePicture(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final bytes = await imageFile.readAsBytes();

      // Limite Firestore : 1 MB par document
      if (bytes.length > 900 * 1024) {
        debugPrint('❌ Image trop grosse : ${bytes.length} octets');
        throw Exception(
          'Image trop lourde (max 900 KB). Choisissez une autre photo.',
        );
      }

      final base64String = base64Encode(bytes);

      await _firestore.collection('users').doc(user.uid).update({
        'photoBase64': base64String,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '✅ Photo uploadée : ${(bytes.length / 1024).toStringAsFixed(1)} KB',
      );
      return base64String;
    } catch (e) {
      debugPrint("❌ Erreur upload photo de profil: $e");
      rethrow;
    }
  }

  /// Upload un document (image) en base64 dans Firestore.
  /// Compression pour respecter la limite de 1 Mo de Firestore.
  Future<String?> uploadVerificationDocument(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final bytes = await imageFile.readAsBytes();

      // Limite Firestore : ~1 Mo par document. On garde une marge.
      if (bytes.length > 900 * 1024) {
        // Compresser l'image si elle est trop lourde
        final compressed = await _compressImage(imageFile);
        if (compressed != null) {
          return await _storeBase64(user.uid, compressed);
        }
        throw Exception(
          'Document trop lourd (max 900 KB). Choisissez un fichier plus léger.',
        );
      }

      return await _storeBase64(user.uid, bytes);
    } catch (e) {
      debugPrint("❌ Erreur upload document: $e");
      rethrow;
    }
  }

  Future<String> _storeBase64(String uid, Uint8List bytes) async {
    final base64String = base64Encode(bytes);
    await _firestore.collection('users').doc(uid).update({
      'professionalDocBase64': base64String,
      'professionalDocUpdatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint('✅ Document uploadé: ${(bytes.length / 1024).toStringAsFixed(1)} KB');
    return base64String;
  }

  /// Compression basique avec image_picker (quality) — nécessite repick
  /// ou utiliser le package `image` si tu veux vraiment compresser.
  Future<Uint8List?> _compressImage(File file) async {
    // Option simple : re-picker avec qualité réduite n'est pas possible ici.
    // On peut utiliser package:image pour redimensionner.
    // Pour l'instant, on renvoie null pour forcer l'utilisateur à choisir
    // une image plus petite, OU on ajoute le package `image`.
    return null;
  }

  Future<bool> validateSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.reload();
      return _auth.currentUser != null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'user-disabled') {
        await signOut();
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint("Erreur lors de la déconnexion: $e");
      rethrow;
    }
  }
}