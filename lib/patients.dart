import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'user_avatar.dart';

class PatientsPage extends StatelessWidget {
  const PatientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Patients List',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.terracotta),
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'client')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final patients = snapshot.data?.docs ?? [];

          if (patients.isEmpty) {
            return const Center(
              child: Text('No patients found', style: TextStyle(color: AppColors.greyText)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final data = patients[index].data() as Map<String, dynamic>;
              final name = data['fullName'] ?? 'Anonymous Patient';
              final email = data['email'] ?? '';
              final photo = userAvatarImage(data);
              final uid = data['uid'];

              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.softGrey),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withAlpha(5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.lightPurple,
                    backgroundImage: photo,
                    child: photo == null ? const Icon(Icons.person, color: AppColors.primaryPurple) : null,
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
                  subtitle: Text(email, style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.softGrey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientDetailsPage(patientId: uid, patientName: name),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PatientDetailsPage extends StatelessWidget {
  final String patientId;
  final String patientName;

  const PatientDetailsPage({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.darkPurple, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          patientName,
          style: const TextStyle(color: AppColors.darkPurple, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clinical Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
            ),
            const SizedBox(height: 20),
            
            // Patient Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.softPurple,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                children: [
                  Text(
                    'No detailed history yet',
                    style: TextStyle(color: AppColors.greyText),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
            ),
            const SizedBox(height: 15),
            
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'No recent skin analyses or messages',
                  style: TextStyle(color: AppColors.greyText, fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
