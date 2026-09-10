import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ziskin/pages/auth/login.dart';
import '../app_colors.dart';
import '../auth_gate.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String _fullName = '';
  String _email = '';
  int? _age;
  String _skinType = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      _email = user.email ?? '';
      _fullName = user.displayName ?? '';

      final profile = await _authService.getUserProfile();
      if (mounted && profile != null) {
        setState(() {
          _fullName = (profile['fullName'] ?? profile['name'] ?? _fullName).toString().trim();
          _email = (profile['email'] ?? _email).toString().trim();
          if (profile['age'] != null) {
            _age = int.tryParse(profile['age'].toString());
          }
          _skinType = (profile['skinType'] ?? '').toString().trim();
          _isLoading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmSignOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppColors.terracotta),
            SizedBox(width: 10),
            Text(
              'Déconnexion',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter de votre compte Dermaly ?',
          style: TextStyle(fontSize: 15, color: AppColors.greyText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: AppColors.greyText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.terracotta,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        await _authService.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Vous avez été déconnecté avec succès."),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur lors de la déconnexion: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final displayName = _fullName.isNotEmpty
        ? _fullName
        : (user?.displayName ?? (user?.email?.split('@')[0] ?? 'Utilisateur'));

    return Scaffold(
      backgroundColor: AppColors.softPurple,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Mon Profil',
          style: TextStyle(
            color: AppColors.darkPurple,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.terracotta),
            tooltip: 'Se déconnecter',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Avatar et infos principales
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.lightPurple,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/iryna.jpeg',
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Icon(
                                Icons.person,
                                color: AppColors.terracotta,
                                size: 55,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkPurple,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email.isNotEmpty ? _email : (user?.email ?? ''),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.greyText,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Carte Détails du profil
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withAlpha(12),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informations personnelles',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkPurple,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(Icons.person_outline, 'Nom complet', displayName),
                        const Divider(height: 24),
                        _buildInfoRow(Icons.email_outlined, 'Email', _email.isNotEmpty ? _email : 'Non renseigné'),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.cake_outlined,
                          'Âge',
                          _age != null ? '$_age ans' : 'Non renseigné',
                        ),
                        const Divider(height: 24),
                        _buildInfoRow(
                          Icons.spa_outlined,
                          'Type de peau',
                          _skinType.isNotEmpty ? _skinType : 'Non défini (Faire le test)',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Carte Paramètres & Sécurité
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withAlpha(12),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sécurité & Session',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkPurple,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.lightPurple,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shield_outlined, color: AppColors.primaryPurple, size: 20),
                          ),
                          title: const Text('Persistance de connexion', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: const Text('Session active et sécurisée par Firebase', style: TextStyle(fontSize: 12, color: AppColors.greyText)),
                          trailing: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Bouton Déconnexion
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _confirmSignOut,
                      icon: const Icon(Icons.logout, color: AppColors.white),
                      label: const Text(
                        'SE DÉCONNECTER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.terracotta,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.terracotta, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.greyText),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.darkPurple,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
