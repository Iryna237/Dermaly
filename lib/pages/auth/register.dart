import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_colors.dart';
import '../../screen_manage.dart';
import '../../services/auth_service.dart'; // adapte le chemin
import 'login.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  final _formKey = GlobalKey<FormState>();
  final _dermaFormKey = GlobalKey<FormState>();

  // Client Controllers
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Dermatologist Controllers
  final _dermaNameController = TextEditingController();
  final _dermaEmailController = TextEditingController();
  final _dermaPasswordController = TextEditingController();
  final _dermaConfirmPasswordController = TextEditingController();
  final _dermaOnmcController = TextEditingController();
  final _dermaDegreeController = TextEditingController();
  final _dermaEstablishmentController = TextEditingController();
  final _dermaCityController = TextEditingController();

  File? _professionalDoc;
  final ImagePicker _picker = ImagePicker();

  final List<String> _cameroonCities = [
    'Douala', 'Yaoundé', 'Garoua', 'Bamenda', 'Maroua',
    'Bafoussam', 'Kousseri', 'Ngaoundéré', 'Kumba', 'Loum'
  ];

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dermaNameController.dispose();
    _dermaEmailController.dispose();
    _dermaPasswordController.dispose();
    _dermaConfirmPasswordController.dispose();
    _dermaOnmcController.dispose();
    _dermaDegreeController.dispose();
    _dermaEstablishmentController.dispose();
    _dermaCityController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200, // compression automatique
      imageQuality: 70,
    );
    if (image != null) {
      setState(() => _professionalDoc = File(image.path));
    }
  }

  Future<void> _registerClient() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(_nameController.text.trim());

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'fullName': _nameController.text.trim(),
          'age': int.parse(_ageController.text.trim()),
          'email': _emailController.text.trim(),
          'role': 'client',
          'skinType': '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration successful!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ScreenManage(
              userName: _nameController.text.trim().isNotEmpty
                  ? _nameController.text.trim().split(' ')[0]
                  : 'User',
            ),
          ),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = "An error occurred during the registration.";
      if (e.code == 'weak-password') errorMessage = "The password is weak.";
      else if (e.code == 'email-already-in-use') {
        errorMessage = "An account already exists with this email.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email address.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerDermatologist() async {
    if (!_dermaFormKey.currentState!.validate()) return;
    if (_professionalDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please upload a professional supporting document"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _dermaEmailController.text.trim(),
        password: _dermaPasswordController.text.trim(),
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(_dermaNameController.text.trim());

        // 1) Créer le document Firestore d'abord (sans le base64)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'fullName': _dermaNameController.text.trim(),
          'email': _dermaEmailController.text.trim(),
          'onmcNumber': _dermaOnmcController.text.trim(),
          'degree': _dermaDegreeController.text.trim(),
          'establishment': _dermaEstablishmentController.text.trim(),
          'city': _dermaCityController.text.trim(),
          'role': 'dermatologist',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2) Uploader le document en base64 via AuthService
        //    (utilise la même logique que uploadProfilePicture)
        await _authService.uploadVerificationDocument(_professionalDoc!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration submitted for verification!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const PendingVerificationPage(),
          ),
              (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Registration failed"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Center(
                child: Image.asset("assets/images/logo.png", height: 150),
              ),
              const SizedBox(height: 25),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildAccountTypeBox(
                        title: "Client",
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _buildAccountTypeBox(
                        title: "Dermatologist",
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _selectedTab == 0
                  ? _buildClientForm()
                  : _buildDermatologistForm(),
              Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account? ",
                      style: TextStyle(color: AppColors.greyText),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: AppColors.terracotta,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountTypeBox({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPink : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.brandPink
                : AppColors.greyText.withAlpha(51),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: AppColors.brandPink.withAlpha(80),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ]
              : null,
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? AppColors.white : AppColors.greyText,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClientForm() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create Client Account',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.black87,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(Icons.person_outline,
                    color: AppColors.terracotta),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              validator: (v) =>
              v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Age',
                prefixIcon: const Icon(Icons.cake_outlined,
                    color: AppColors.terracotta),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              validator: (v) =>
              v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined,
                    color: AppColors.terracotta),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              validator: (v) =>
              v == null || !v.contains('@') ? 'Invalid email' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline,
                    color: AppColors.terracotta),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              validator: (v) =>
              v == null || v.length < 6 ? 'Too short' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline,
                    color: AppColors.terracotta),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(() =>
                  _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerClient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPink,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.white)
                    : const Text('REGISTER'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDermatologistForm() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Form(
        key: _dermaFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dermatologist Account',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black87),
            ),
            const SizedBox(height: 10),
            const Text(
              'Fill the form for verification.',
              style: TextStyle(fontSize: 14, color: AppColors.greyText),
            ),
            const SizedBox(height: 20),
            _buildDermaField(
                _dermaNameController, 'Full Name', Icons.person_outline),
            const SizedBox(height: 15),
            _buildDermaField(_dermaEmailController, 'Email Address',
                Icons.email_outlined,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 15),
            _buildDermaField(
                _dermaPasswordController, 'Password', Icons.lock_outline,
                obscure: true),
            const SizedBox(height: 15),
            TextFormField(
              controller: _dermaConfirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline,
                    color: AppColors.terracotta),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(() =>
                  _obscureConfirmPassword = !_obscureConfirmPassword),
                ),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _dermaPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 15),
            _buildDermaField(_dermaOnmcController,
                'ONMC Registration Number', Icons.app_registration),
            const SizedBox(height: 15),
            _buildDermaField(_dermaDegreeController,
                'Degree/Qualification', Icons.school_outlined),
            const SizedBox(height: 15),
            _buildDermaField(_dermaEstablishmentController,
                'Practice Address', Icons.business_outlined),
            const SizedBox(height: 15),
            LayoutBuilder(
              builder: (context, constraints) => DropdownMenu<String>(
                width: constraints.maxWidth,
                label: const Text('City'),
                hintText: 'Select or type your city',
                leadingIcon: const Icon(Icons.location_city,
                    color: AppColors.terracotta),
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                enableFilter: true,
                enableSearch: true,
                dropdownMenuEntries: _cameroonCities.map((String city) {
                  return DropdownMenuEntry<String>(
                      value: city, label: city);
                }).toList(),
                onSelected: (String? selection) {
                  if (selection != null) {
                    _dermaCityController.text = selection;
                  }
                },
                controller: _dermaCityController,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Professional Supporting Document',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickDocument,
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.greyText),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: _professionalDoc == null
                    ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file, size: 30),
                    Text('Upload from gallery'),
                  ],
                )
                    : const Center(
                    child: Text('Document selected ✅')),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _registerDermatologist,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.terracotta,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.white)
                    : const Text('SUBMIT FOR VERIFICATION'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDermaField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool obscure = false,
        TextInputType keyboardType = TextInputType.text,
      }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.terracotta),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}

class PendingVerificationPage extends StatelessWidget {
  const PendingVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty,
                  size: 80, color: AppColors.terracotta),
              const SizedBox(height: 30),
              const Text(
                'Account Under Verification',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkPurple),
              ),
              const SizedBox(height: 20),
              const Text(
                'Your dermatologist account is currently being verified by our administrators. This usually takes 24-48 hours.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.greyText),
              ),
              const SizedBox(height: 40),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final data =
                  snapshot.data!.data() as Map<String, dynamic>?;
                  if (data == null) return const Text("Error loading data");

                  if (data['status'] == 'accepted') {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScreenManage(
                              userName: data['fullName']),
                        ),
                            (route) => false,
                      );
                    });
                  }

                  // Image base64 au lieu de Image.network
                  final base64Str = data['professionalDocBase64'] as String?;
                  Uint8List? imageBytes;
                  if (base64Str != null && base64Str.isNotEmpty) {
                    try {
                      imageBytes = base64Decode(base64Str);
                    } catch (_) {}
                  }

                  return Column(
                    children: [
                      _buildInfo('ONMC Number', data['onmcNumber'] ?? ''),
                      _buildInfo('Establishment', data['establishment'] ?? ''),
                      const SizedBox(height: 20),
                      const Text('Supporting Document:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (imageBytes != null)
                        Image.memory(imageBytes,
                            height: 200, fit: BoxFit.contain)
                      else
                        const Text('Document not available'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () async {
                  await AuthService().signOut();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginPage()),
                        (route) => false,
                  );
                },
                child: const Text('LOGOUT'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(value),
      ]),
    );
  }
}