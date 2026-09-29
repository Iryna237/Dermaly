import 'package:flutter/material.dart';
import 'package:ziskin/ai_chat.dart';
import 'package:ziskin/app_colors.dart';
import 'package:ziskin/homepage.dart';
import 'package:ziskin/make_skin_analysis.dart';
import 'package:ziskin/services/chat_activity.dart';
import 'package:ziskin/services/message_notifier.dart';
import 'package:ziskin/pill_nav_bar.dart';
import 'package:ziskin/services/notification_service.dart';
import 'package:ziskin/skin_progress.dart';

import 'package:ziskin/pages/profile_page.dart';

class ScreenManage extends StatefulWidget {
  final String? userName;

  const ScreenManage({super.key, this.userName});

  @override
  State<ScreenManage> createState() => _ScreenManageState();
}

class _ScreenManageState extends State<ScreenManage> {
  int _currentIndex = 0;

  // Flux créé une seule fois : le recréer à chaque build relance la lecture Firestore
  late final Stream<List<ChatSummary>> _chats =
      ChatActivity.watch(asDermatologist: false);

  @override
  void initState() {
    super.initState();
    // Rappels reprogrammes a chaque ouverture : ils suivent l'etat reel de la
    // routine et du scan du mois, et survivent ainsi a un redemarrage du telephone
    NotificationService.refreshSchedules();
    // Prévient le patient des messages de son dermatologue tant que l'app tourne
    MessageNotifier.start();
  }

  @override
  void dispose() {
    MessageNotifier.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      SkinCareHomePage(
        userName: widget.userName,
        onProfileTap: () {
          setState(() {
            _currentIndex = 4;
          });
        },
      ),
      const SkinProgressPage(),
      MakeSkinAnalysisPage(
        onBack: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      const ClientChatListPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      // Le point de l'onglet Chat : un message du dermatologue se voit sans
      // avoir à ouvrir l'onglet pour le chercher.
      bottomNavigationBar: StreamBuilder<List<ChatSummary>>(
        stream: _chats,
        builder: (context, snapshot) {
          final unread = (snapshot.data ?? const <ChatSummary>[])
              .fold(0, (total, chat) => total + chat.unread);

          return PillNavBar(
            currentIndex: _currentIndex,
            onTap: (page) {
              setState(() {
                _currentIndex = page;
              });
            },
            accent: AppColors.terracotta,
            accentSoft: AppColors.softPink,
            centerGradient: const [AppColors.brandPink, AppColors.terracotta],
            tabs: [
              const NavTab(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
              const NavTab(
                  icon: Icons.insights_outlined, activeIcon: Icons.insights_rounded, label: 'Progress'),
              const NavTab(
                  icon: Icons.photo_camera_outlined, activeIcon: Icons.photo_camera_rounded, label: 'Scan'),
              NavTab(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                dot: unread > 0,
              ),
              const NavTab(
                  icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile'),
            ],
          );
        },
      ),
    );
  }
}
