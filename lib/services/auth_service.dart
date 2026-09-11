import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service centralisé pour gérer l'authentification et la persistance de session
class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Stream réactif émettant l'utilisateur à chaque changement d'état d'authentification
  /// (connexion, déconnexion, restauration automatique de session depuis le stockage local)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Utilisateur actuellement connecté (restauré automatiquement par Firebase Auth)
  User? get currentUser => _auth.currentUser;

  /// Vérifie si une session utilisateur est active
  bool get isAuthenticated => _auth.currentUser != null;

  /// Identifiant unique de l'utilisateur connecté
  String? get currentUserId => _auth.currentUser?.uid;

  /// Récupère le prénom ou nom d'affichage de l'utilisateur
  /// Priorité : FirebaseAuth displayName > Firestore fullName > Email prefix > 'Utilisateur'
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
        final fullName = (data['fullName'] ?? data['name'] ?? '').toString().trim();
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

  /// Récupère le profil complet de l'utilisateur stocké dans Firestore
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

  /// Met à jour le profil de l'utilisateur dans Firestore
  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update(data);
      
      // Si on met à jour le nom, on le met aussi dans Firebase Auth
      if (data.containsKey('fullName')) {
        await user.updateDisplayName(data['fullName']);
      }
      if (data.containsKey('photoUrl')) {
        await user.updatePhotoURL(data['photoUrl']);
      }
    } catch (e) {
      debugPrint("Erreur mise à jour profil Firestore: $e");
      rethrow;
    }
  }

  /// Télécharge une image de profil vers Firebase Storage et retourne l'URL
  Future<String?> uploadProfilePicture(File imageFile) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final ref = _storage.ref().child('profile_pics').child('${user.uid}.jpg');
      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();
      
      // Mettre à jour le profil avec la nouvelle URL
      await updateUserProfile({'photoUrl': url});
      
      return url;
    } catch (e) {
      debugPrint("Erreur upload photo de profil: $e");
      return null;
    }
  }

  /// Vérifie la validité de la session en arrière-plan (par exemple si le compte a été supprimé)
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
      // Si problème réseau, on conserve la session locale persistée
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Déconnexion de l'utilisateur et suppression de la session persistée
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint("Erreur lors de la déconnexion: $e");
      rethrow;
    }
  }
}
