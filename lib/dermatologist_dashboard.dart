import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'appointments.dart';
import 'chat_derma.dart';
import 'derma_profil.dart';
import 'pages/profile_page.dart';
import 'models/consultation.dart';
import 'patients.dart';
import 'services/consultation_service.dart';
import 'services/message_notifier.dart';
import 'services/notification_service.dart';

class DermatologistDashboard extends StatefulWidget {
  final String doctorName;
  const DermatologistDashboard({super.key, this.doctorName = 'Iryna'});

  @override
  State<DermatologistDashboard> createState() =>
      _DermatologistDashboardState();
}

class _DermatologistDashboardState extends State<DermatologistDashboard> {
  int _currentIndex = 0;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Permission demandée à l'ouverture plutôt qu'au premier message reçu
    NotificationService.init();
    MessageNotifier.start(asDermatologist: true);

    _pages = [
      _buildHomeContent(),
      const PatientsPage(),
      const AppointmentsPage(),
      const DermatologistChatListPage(),
      const DermatologistProfilePage(),
    ];
  }

  @override
  void dispose() {
    MessageNotifier.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.softGrey, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.primaryPurple,
          unselectedItemColor: AppColors.greyText,
          selectedLabelStyle:
          const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.people_alt_outlined), label: 'Patients'),
            BottomNavigationBarItem(
                icon: Icon(Icons.inbox_rounded), label: 'Requests'),
            BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline_rounded), label: 'Chat'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  // ✅ Avatar temps réel basé sur le document Firestore
  Widget _buildHeaderAvatar() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .snapshots(),
      builder: (context, snapshot) {
        Uint8List? bytes;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final base64Str = data?['photoBase64'] as String?;
          if (base64Str != null && base64Str.isNotEmpty) {
            try {
              bytes = base64Decode(base64Str);
            } catch (e) {
              debugPrint('Erreur décodage photo header: $e');
            }
          }
        }

        return CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.lightPurple,
          backgroundImage: bytes != null ? MemoryImage(bytes) : null,
          child: bytes == null
              ? Text(
            widget.doctorName.substring(0, 2).toUpperCase(),
            style: const TextStyle(
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          )
              : null,
        );
      },
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning, Dr. ${widget.doctorName}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkPurple,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Here\'s your dermatology overview today.',
                    style:
                    TextStyle(fontSize: 14, color: AppColors.greyText),
                  ),
                ],
              ),
              Row(
                children: [
                  // ✅ Avatar avec photo
                  _buildHeaderAvatar(),
                  const SizedBox(width: 12),
                  Stack(
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          size: 28, color: AppColors.terracotta),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Summary Grid
          LayoutBuilder(
            builder: (context, constraints) {
              double cardWidth = (constraints.maxWidth - 15) / 2;
              return Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  StreamBuilder<List<Consultation>>(
                    // Les patients de ce dermatologue, pas tous les clients de l'app
                    stream: ConsultationService.watchForDermatologist(),
                    builder: (context, snapshot) {
                      final count = (snapshot.data ?? const <Consultation>[])
                          .where((c) => c.isAccepted)
                          .length;
                      return GestureDetector(
                        onTap: () => setState(() => _currentIndex = 1),
                        child: _buildSummaryCard(
                          'Total patients',
                          count.toString(),
                          Icons.people_rounded,
                          AppColors.lightPurple,
                          cardWidth,
                        ),
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('appointments')
                        .where('doctorId', isEqualTo: _uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count =
                      snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return _buildSummaryCard(
                        'Upcoming appts',
                        count.toString(),
                        Icons.event_available_rounded,
                        AppColors.softPurple,
                        cardWidth,
                      );
                    },
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(_uid)
                        .collection('messages')
                        .where('sender', isEqualTo: 'user')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count =
                      snapshot.hasData ? snapshot.data!.docs.length : 0;
                      return GestureDetector(
                        onTap: () => setState(() => _currentIndex = 3),
                        child: _buildSummaryCard(
                          'Recent messages',
                          count.toString(),
                          Icons.chat_rounded,
                          const Color(0xFFF1F1F1),
                          constraints.maxWidth,
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 35),

          // Today's appointments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s appointments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkPurple,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'View all',
                  style: TextStyle(color: AppColors.greyText, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('doctorId', isEqualTo: _uid)
                .orderBy('time')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: AppColors.softGrey.withAlpha(50),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Center(
                    child: Text(
                      'No appointments scheduled for today',
                      style: TextStyle(
                          color: AppColors.greyText,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: AppColors.softGrey),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withAlpha(5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(
                      height: 30, color: AppColors.softGrey),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    return _buildAppointmentItem(
                      data['time'] ?? '--:--',
                      data['patientName'] ?? 'Unknown Patient',
                      data['type'] ?? 'Consultation',
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.darkPurple.withAlpha(180), size: 24),
          const SizedBox(height: 15),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.greyText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkPurple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(String time, String patient, String type) {
    return Row(
      children: [
        Text(
          time,
          style: const TextStyle(
            color: AppColors.greyText,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 15, color: AppColors.darkPurple),
              children: [
                TextSpan(
                    text: patient,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' — '),
                TextSpan(text: type),
              ],
            ),
          ),
        ),
        const Icon(Icons.chevron_right_rounded,
            color: AppColors.softGrey, size: 20),
      ],
    );
  }
}