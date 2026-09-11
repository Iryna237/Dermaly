import 'package:flutter/material.dart';
import 'package:ziskin/ai_chat.dart';
import 'package:ziskin/app_colors.dart';
import 'package:ziskin/homepage.dart';
import 'package:ziskin/make_skin_analysis.dart';
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
      const MakeSkinAnalysisPage(),
      const AiChatPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        onTap: (page) {
          setState(() {
            _currentIndex = page;
          });
        },
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.terracotta,
        unselectedItemColor: AppColors.greyText,
        unselectedLabelStyle: const TextStyle(color: AppColors.greyText),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "Progress"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Scan"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: "Profile"),
        ],
      ),
    );
  }
}
