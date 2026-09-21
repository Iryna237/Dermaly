import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'models/consultation.dart';
import 'services/consultation_service.dart';
import 'user_avatar.dart';

/// Choix du dermatologue à qui envoyer une demande de consultation.
///
/// Seuls les dermatologues validés par un administrateur sont proposés, et ceux
/// avec qui une demande est déjà en cours ou acceptée ne sont pas re-sollicitables.
class RequestConsultationPage extends StatefulWidget {
  const RequestConsultationPage({super.key});

  @override
  State<RequestConsultationPage> createState() => _RequestConsultationPageState();
}

class _RequestConsultationPageState extends State<RequestConsultationPage> {
  // Flux créés une seule fois : les recréer à chaque build relance les lectures
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _dermatologists =
      FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'dermatologist')
          .where('status', isEqualTo: 'accepted')
          .snapshots();

  late final Stream<List<Consultation>> _mine = ConsultationService.watchForPatient();

  String? _sendingTo;

  Future<void> _request(String dermatologistId, String dermatologistName) async {
    if (_sendingTo != null) return;
    setState(() => _sendingTo = dermatologistId);

    try {
      await ConsultationService.request(
        dermatologistId: dermatologistId,
        dermatologistName: dermatologistName,
        patientName: _patientName(),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent to $dermatologistName. '
              'The chat opens once they accept.'),
          backgroundColor: AppColors.primaryPurple,
        ),
      );
    } catch (e) {
      debugPrint('Erreur envoi demande de consultation: $e');
      if (!mounted) return;
      setState(() => _sendingTo = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _patientName() {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    return name == null || name.isEmpty ? 'Patient' : name;
  }

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
        title: const Text(
          'Request consultation',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Consultation>>(
        stream: _mine,
        builder: (context, mineSnapshot) {
          // Demandes en cours ou acceptées : on ne redemande pas au même médecin
          final taken = {
            for (final consultation in mineSnapshot.data ?? const <Consultation>[])
              if (consultation.isPending || consultation.isAccepted)
                consultation.dermatologistId: consultation,
          };

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _dermatologists,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _buildMessage(
                  'Unable to load dermatologists',
                  snapshot.error.toString(),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryPurple),
                );
              }

              final doctors = snapshot.data!.docs;
              if (doctors.isEmpty) {
                return _buildMessage(
                  'No dermatologist available',
                  'No verified dermatologist has joined Dermaly yet. Please try again later.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: doctors.length,
                itemBuilder: (context, index) {
                  final data = doctors[index].data();
                  final id = (data['uid'] as Object?)?.toString() ?? doctors[index].id;
                  final name = 'Dr. ${data['fullName'] ?? 'Expert'}';

                  return _buildDoctorTile(
                    id: id,
                    name: name,
                    city: (data['city'] as Object?)?.toString(),
                    photo: userAvatarImage(data),
                    existing: taken[id],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDoctorTile({
    required String id,
    required String name,
    String? city,
    ImageProvider? photo,
    Consultation? existing,
  }) {
    final isSending = _sendingTo == id;

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.softGrey),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.lightPurple,
            backgroundImage: photo,
            child: photo == null ? const Icon(Icons.person, color: Colors.white) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkPurple),
                ),
                const SizedBox(height: 2),
                Text(
                  city == null || city.isEmpty ? 'Clinical Dermatology' : city,
                  style: const TextStyle(fontSize: 12, color: AppColors.greyText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildAction(id, name, existing, isSending),
        ],
      ),
    );
  }

  Widget _buildAction(String id, String name, Consultation? existing, bool isSending) {
    if (existing != null) {
      return Text(
        existing.isAccepted ? 'Accepted' : 'Pending',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.greyText,
        ),
      );
    }

    if (isSending) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryPurple),
      );
    }

    return ElevatedButton(
      onPressed: _sendingTo == null ? () => _request(id, name) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryPurple,
        foregroundColor: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: const Text('Request'),
    );
  }

  Widget _buildMessage(String title, String details) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkPurple,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              details,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.greyText, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
