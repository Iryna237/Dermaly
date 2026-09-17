import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'app_colors.dart';
import 'pages/auth/login.dart';
import 'services/auth_service.dart';

class DermatologistProfilePage extends StatefulWidget {
  const DermatologistProfilePage({super.key});

  @override
  State<DermatologistProfilePage> createState() => _DermatologistProfilePageState();
}

class _DermatologistProfilePageState extends State<DermatologistProfilePage> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  
  // Data fields
  String _fullName = '';
  String _email = '';
  String _onmcNumber = '';
  String _degree = '';
  String _establishment = '';
  String _city = '';
  String _status = '';
  String? _photoUrl;
  String? _docUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _authService.currentUser;
    if (user != null) {
      final data = await _authService.getUserProfile();
      if (mounted && data != null) {
        setState(() {
          _fullName = data['fullName'] ?? user.displayName ?? '';
          _email = data['email'] ?? user.email ?? '';
          _onmcNumber = data['onmcNumber'] ?? '';
          _degree = data['degree'] ?? '';
          _establishment = data['establishment'] ?? '';
          _city = data['city'] ?? '';
          _status = data['status'] ?? 'pending';
          _photoUrl = data['photoUrl'] ?? user.photoURL;
          _docUrl = data['professionalDocUrl'];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() => _isLoading = true);
        final url = await _authService.uploadProfilePicture(File(image.path));
        if (mounted) {
          if (url != null) {
            setState(() {
              _photoUrl = url;
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softPurple,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text('My Professional Profile', style: TextStyle(color: AppColors.darkPurple, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.terracotta),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Profile Photo
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.lightPurple,
                        backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                        child: _photoUrl == null ? const Icon(Icons.person, size: 60, color: AppColors.primaryPurple) : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAndUploadImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(color: AppColors.terracotta, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(_fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(_status).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _status.toUpperCase(),
                    style: TextStyle(color: _getStatusColor(_status), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 30),

                // Info Cards
                _buildInfoCard(
                  title: 'Professional Details',
                  items: [
                    _buildInfoRow(Icons.badge_outlined, 'ONMC Number', _onmcNumber),
                    _buildInfoRow(Icons.school_outlined, 'Degree', _degree),
                    _buildInfoRow(Icons.business_outlined, 'Establishment', _establishment),
                    _buildInfoRow(Icons.location_city_outlined, 'City', _city),
                  ],
                ),
                const SizedBox(height: 20),
                _buildInfoCard(
                  title: 'Account Information',
                  items: [
                    _buildInfoRow(Icons.email_outlined, 'Email', _email),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Supporting Document Preview
                if (_docUrl != null)
                  _buildInfoCard(
                    title: 'Supporting Document',
                    items: [
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          _docUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const Text('Error loading document preview'),
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 40),
                TextButton(
                  onPressed: () {}, // Future: Edit profile logic
                  child: const Text('Request information update', style: TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildInfoCard({required String title, required List<Widget> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
          const SizedBox(height: 15),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.terracotta, size: 20),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.greyText)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkPurple)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }
}
