import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'models/consultation.dart';
import 'services/consultation_service.dart';
import 'user_avatar.dart';

/// Patients du dermatologue connecté : uniquement ceux dont la demande de
/// consultation a été acceptée, comme dans sa messagerie.
/// Patients du dermatologue connecté : ceux dont la demande de consultation a
/// été acceptée.
///
/// La liste est bâtie à partir des consultations, pas d'une requête sur le rôle :
/// certains comptes n'ont pas de champ `role` et disparaissaient de l'onglet.
class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});

  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  // Flux créé une seule fois : le recréer à chaque build relance la lecture Firestore
  late final Stream<List<Consultation>> _consultations =
      ConsultationService.watchForDermatologist();

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
      body: StreamBuilder<List<Consultation>>(
        stream: _consultations,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildMessage('Unable to load your patients.\n${snapshot.error}');
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final patients = snapshot.data!.where((c) => c.isAccepted).toList();
          if (patients.isEmpty) {
            return _buildMessage(
              'No patient yet.\nAccept a consultation request to see a patient here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            itemCount: patients.length,
            itemBuilder: (context, index) => _buildPatientTile(patients[index]),
          );
        },
      ),
    );
  }

  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.greyText, fontSize: 13, height: 1.5),
        ),
      ),
    );
  }

  /// Une seule lecture du profil par patient, pour la photo comme pour l'email.
  /// Le nom de la consultation sert de repli tant que le profil n'est pas chargé.
  Widget _buildPatientTile(Consultation consultation) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(consultation.patientId)
          .get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final name = (data?['fullName'] as Object?)?.toString() ?? consultation.patientName;
        final email = (data?['email'] as Object?)?.toString() ?? '';
        final photo = userAvatarImage(data);

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
                  builder: (context) => PatientDetailsPage(
                    patientId: consultation.patientId,
                    patientName: name,
                  ),
                ),
              );
            },
          ),
        );
      },
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
