import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'landing_page.dart';
import 'screen_manage.dart';
import 'services/auth_service.dart';
import 'splash_screen.dart';

/// Passerelle d'authentification garantissant la persistance de connexion.
/// - Au démarrage à froid : Affiche le splash screen animé (~2.2s), vérifie la session persistée par Firebase Auth.
/// - Si l'utilisateur est déjà connecté : Redirige vers ScreenManage.
/// - Si l'utilisateur n'est pas connecté : Redirige vers LandingPage.
/// - Réagit en temps réel aux changements d'état d'authentification (connexion, déconnexion).
class AuthGate extends StatefulWidget {
  final bool skipSplash;

  const AuthGate({super.key, this.skipSplash = false});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _splashCompleted = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipSplash) {
      _splashCompleted = true;
    } else {
      _initSession();
    }
  }

  Future<void> _initSession() async {
    // Laisser le temps à l'animation du SplashScreen de se terminer (~2000ms)
    final splashFuture = Future.delayed(const Duration(milliseconds: 2200));

    // Valider la session Firebase en arrière-plan si un utilisateur est en cache
    final validateFuture = AuthService().validateSession();

    await Future.wait([splashFuture, validateFuture]);

    if (mounted) {
      setState(() {
        _splashCompleted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écran de chargement/animation au lancement initial
    if (!_splashCompleted) {
      return const SplashScreen();
    }

    // Écoute de l'état d'authentification persistant
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      initialData: AuthService().currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SplashScreen();
        }

        final user = snapshot.data;

        if (user != null) {
          // L'utilisateur est connecté (session persistée retrouvée avec succès)
          final displayName = user.displayName?.trim();
          final firstName = (displayName != null && displayName.isNotEmpty)
              ? displayName.split(' ')[0]
              : null;
          return ScreenManage(userName: firstName);
        }

        // Aucun utilisateur connecté -> Page d'accueil / onboarding
        return const LandingPage();
      },
    );
  }
}
