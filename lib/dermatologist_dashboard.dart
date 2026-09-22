import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import 'app_colors.dart';
import 'appointments.dart';
import 'chat_derma.dart';
import 'derma_profil.dart';
import 'pages/profile_page.dart';
import 'models/app_notification.dart';
import 'models/consultation.dart';
import 'notifications_page.dart';
import 'services/notification_log.dart';
import 'patients.dart';
import 'services/chat_activity.dart';
import 'services/consultation_service.dart';
import 'services/message_notifier.dart';
import 'services/notification_service.dart';
import 'user_avatar.dart';

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

  // Flux créés une seule fois : les recréer à chaque build relance la lecture Firestore
  late final Stream<List<AppNotification>> _notifications = NotificationLog.watch();
  late final Stream<List<Consultation>> _consultations =
      ConsultationService.watchForDermatologist();
  late final Stream<List<ChatSummary>> _chats =
      ChatActivity.watch(asDermatologist: true);

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

  /// Cloche du tableau de bord : le point ne s'affiche que s'il reste des
  /// notifications non lues, et disparaît dès que la page les a marquées lues.
  Widget _buildNotificationBell() {
    return StreamBuilder<List<AppNotification>>(
      stream: _notifications,
      builder: (context, snapshot) {
        final unread = snapshot.data?.where((n) => !n.read).length ?? 0;

        return IconButton(
          tooltip: 'Notifications',
          icon: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded,
                  size: 28, color: AppColors.terracotta),
              if (unread > 0)
                Positioned(
                  right: 2,
                  top: 2,
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
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsPage(
                emptyMessage:
                    'Consultation requests and messages from your patients '
                    'will show up here.',
              ),
            ),
          ),
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
                  _buildNotificationBell(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Summary Grid
          LayoutBuilder(
            builder: (context, constraints) {
              double cardWidth = (constraints.maxWidth - 15) / 2;
              return StreamBuilder<List<Consultation>>(
                // Les demandes reçues par ce dermatologue, pas toutes celles de l'app
                stream: _consultations,
                builder: (context, snapshot) {
                  final consultations = snapshot.data ?? const <Consultation>[];
                  final patients = consultations.where((c) => c.isAccepted).length;
                  final pending = consultations.where((c) => c.isPending).length;

                  return Wrap(
                    spacing: 15,
                    runSpacing: 15,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _currentIndex = 1),
                        child: _buildSummaryCard(
                          'Total patients',
                          patients.toString(),
                          Icons.people_rounded,
                          AppColors.lightPurple,
                          cardWidth,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _currentIndex = 2),
                        child: _buildSummaryCard(
                          'Pending requests',
                          pending.toString(),
                          Icons.inbox_rounded,
                          AppColors.softPurple,
                          cardWidth,
                        ),
                      ),
                      StreamBuilder<List<ChatSummary>>(
                        stream: _chats,
                        builder: (context, chats) {
                          final unread = (chats.data ?? const <ChatSummary>[])
                              .fold(0, (total, chat) => total + chat.unread);
                          return GestureDetector(
                            onTap: () => setState(() => _currentIndex = 3),
                            child: _buildSummaryCard(
                              'Unread messages',
                              unread.toString(),
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
              );
            },
          ),
          const SizedBox(height: 35),

          // Frequent patients
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Frequent patients',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkPurple,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _currentIndex = 3),
                child: const Text(
                  'View all',
                  style: TextStyle(color: AppColors.greyText, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<ChatSummary>>(
            stream: _chats,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Les trois conversations les plus récentes : un patient accepté
              // mais avec qui rien n'a encore été échangé n'a pas sa place ici.
              final recent = (snapshot.data ?? const <ChatSummary>[])
                  .where((chat) => chat.hasMessages)
                  .take(3)
                  .toList();

              if (recent.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: AppColors.softGrey.withAlpha(50),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Center(
                    child: Text(
                      'No conversation yet',
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
                  itemCount: recent.length,
                  separatorBuilder: (context, index) => const Divider(
                      height: 30, color: AppColors.softGrey),
                  itemBuilder: (context, index) => _buildPatientItem(recent[index]),
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

  /// Patient de la liste des conversations récentes : ouvrir la ligne ouvre le
  /// chat, ce que « View all » fait pour l'ensemble.
  Widget _buildPatientItem(ChatSummary chat) {
    final preview = chat.lastMessage.isEmpty
        ? 'Conversation opened'
        : chat.lastMessageIsMine
            ? 'You: ${chat.lastMessage}'
            : chat.lastMessage;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DermaDetailedChatPage(
            patientId: chat.peerId,
            patientName: chat.peerName,
            isAi: false,
          ),
        ),
      ),
      child: Row(
        children: [
          UserAvatar(
            userId: chat.peerId,
            backgroundColor: AppColors.lightPurple,
            radius: 20,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat.peerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkPurple,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.greyText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatChatDate(chat.lastMessageAt),
                style: const TextStyle(fontSize: 11, color: AppColors.greyText),
              ),
              const SizedBox(height: 6),
              if (chat.unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.terracotta,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    chat.unread.toString(),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// L'heure pour aujourd'hui, la date au-delà : dans une liste des
  /// conversations récentes, « 14:05 » ne veut rien dire trois jours plus tard.
  static String _formatChatDate(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
    return DateFormat(sameDay ? 'HH:mm' : 'MMM d').format(date);
  }
}