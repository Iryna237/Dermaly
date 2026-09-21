import 'dart:convert';
import 'package:flutter/material.dart';

/// Photo de profil lue depuis le document Firestore d'un utilisateur.
///
/// Les photos sont stockées en base64 dans `photoBase64` (voir
/// `AuthService.uploadProfilePicture`) ; `photoUrl` ne subsiste que pour les
/// comptes créés avant ce changement, d'où le repli sur une URL distante.
/// Retourne null quand aucune photo n'est exploitable : l'appelant affiche
/// alors son icône par défaut.
ImageProvider? userAvatarImage(Map<String, dynamic>? data) {
  if (data == null) return null;

  final base64Photo = data['photoBase64'];
  if (base64Photo is String && base64Photo.isNotEmpty) {
    try {
      return MemoryImage(base64Decode(base64Photo));
    } catch (e) {
      debugPrint('Photo de profil illisible: $e');
    }
  }

  final url = data['photoUrl'];
  return url is String && url.isNotEmpty ? NetworkImage(url) : null;
}
