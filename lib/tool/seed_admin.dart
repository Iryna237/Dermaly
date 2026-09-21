// lib/tool/seed_admin.dart
//
// À exécuter UNE SEULE FOIS. Appelle `seedAdminIfNeeded()` dans main()
// avant runApp(), puis supprime l'appel.
//
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const String kAdminEmail = 'admin@dermascan.com';
const String kAdminPassword = 'Admin123!';
const String kAdminFullName = 'Admin Principal';

Future<void> seedAdminIfNeeded() async {
  // Vérifier si un admin existe déjà
  final existing = await FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'admin')
      .limit(1)
      .get();

  if (existing.docs.isNotEmpty) {
    debugPrint('ℹ️ Un admin existe déjà, seed ignoré.');
    return;
  }

  debugPrint('🌱 Aucun admin trouvé, création...');

  try {
    // Créer l'utilisateur
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
      email: kAdminEmail,
      password: kAdminPassword,
    );

    final user = credential.user!;
    await user.updateDisplayName(kAdminFullName);

    // Créer son doc Firestore
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'fullName': kAdminFullName,
      'email': kAdminEmail,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
    });

    debugPrint('✅ Admin créé : ${user.uid}');
    debugPrint('   Email    : $kAdminEmail');
    debugPrint('   Password : $kAdminPassword');

    // IMPORTANT : se déconnecter pour ne pas rester connecté en admin
    // au prochain lancement de l'app
    await FirebaseAuth.instance.signOut();
  } on FirebaseAuthException catch (e) {
    if (e.code == 'email-already-in-use') {
      debugPrint('ℹ️ L\'email admin existe déjà dans Firebase Auth.');
      // L'utilisateur existe dans Auth mais pas dans Firestore ?
      // On peut tenter de retrouver son UID via signIn
      try {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: kAdminEmail,
          password: kAdminPassword,
        );
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'uid': cred.user!.uid,
          'fullName': kAdminFullName,
          'email': kAdminEmail,
          'role': 'admin',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await FirebaseAuth.instance.signOut();
        debugPrint('✅ Doc Firestore admin créé/mis à jour.');
      } catch (e2) {
        debugPrint('❌ Impossible de finaliser : $e2');
      }
    } else {
      debugPrint('❌ Erreur seed admin : ${e.code} - ${e.message}');
    }
  }
}