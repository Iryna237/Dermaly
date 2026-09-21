import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Avatar d'un utilisateur dont on n'a que l'identifiant : lit son document
/// Firestore et retombe sur [fallbackIcon] tant qu'il n'a pas de photo.
class UserAvatar extends StatelessWidget {
  final String userId;
  final double radius;
  final IconData fallbackIcon;
  final Color backgroundColor;

  const UserAvatar({
    super.key,
    required this.userId,
    required this.backgroundColor,
    this.radius = 25,
    this.fallbackIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final photo = userAvatarImage(snapshot.data?.data());

        return CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor,
          backgroundImage: photo,
          child: photo == null ? Icon(fallbackIcon, color: Colors.white) : null,
        );
      },
    );
  }
}
