import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'pages/auth/login.dart';
import 'services/auth_service.dart';

/// Demande confirmation, puis deconnecte et renvoie a l'ecran de connexion.
///
/// Se deconnecter se fait d'un bouton et se paie d'un mot de passe a ressaisir :
/// la question vaut d'etre posee, cote patient comme cote dermatologue, et elle
/// merite d'etre posee de la meme facon.
Future<void> confirmSignOut(BuildContext context) async {
  final shouldLogout = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.logout, color: AppColors.terracotta),
          SizedBox(width: 10),
          Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
      content: const Text(
        'Are you sure you want to logout of your Dermaly account ?',
        style: TextStyle(fontSize: 15, color: AppColors.greyText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.greyText)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.terracotta,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Logout'),
        ),
      ],
    ),
  );

  if (shouldLogout != true || !context.mounted) return;

  try {
    await AuthService().signOut();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have been successfully logged out.'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error occured while logging out: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
