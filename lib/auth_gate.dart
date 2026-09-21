import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_dash.dart';
import 'dermatologist_dashboard.dart';
import 'landing_page.dart';
import 'pages/auth/register.dart';
import 'screen_manage.dart';
import 'services/auth_service.dart';
import 'splash_screen.dart';

/// Passerelle d'authentification garantissant la persistance de connexion.
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
    final splashFuture = Future.delayed(const Duration(milliseconds: 2200));
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
    if (!_splashCompleted) {
      return const SplashScreen();
    }

    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      initialData: AuthService().currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SplashScreen();
        }

        final user = snapshot.data;

        if (user != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }

              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final role = userData['role'];
                final status = userData['status'];
                
                final displayName = user.displayName?.trim();
                final firstName = (displayName != null && displayName.isNotEmpty)
                    ? displayName.split(' ')[0]
                    : null;

                if (role == 'admin') {
                  return const AdminDashboard();
                }

                if (role == 'dermatologist') {
                  if (status == 'pending') {
                    return const PendingVerificationPage();
                  }
                  if (status == 'rejected') {
                    return const LandingPage();
                  }
                  return DermatologistDashboard(doctorName: firstName ?? 'Doctor');
                }

                return ScreenManage(userName: firstName);
              }
              
              return const LandingPage();
            },
          );
        }

        return const LandingPage();
      },
    );
  }
}
