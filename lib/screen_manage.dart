import 'package:flutter/material.dart';
import 'package:ziskin/app_colors.dart';
import 'package:ziskin/homepage.dart';
import 'package:ziskin/make_skin_analysis.dart';
import 'package:ziskin/questionnaire.dart';

class ScreenManage extends StatefulWidget {
  const ScreenManage({super.key});

  @override
  State<ScreenManage> createState() => _ScreenManageState();
}
int _currentIndex = 0;
final List<Widget> _pages = [
  SkinCareHomePage(),
  QuestionnairePage(),
  MakeSkinAnalysisPage(),
  SkinCareHomePage(),
  SkinCareHomePage(),
];

class _ScreenManageState extends State<ScreenManage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: _pages[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        onTap: (page){
          setState(() {
            _currentIndex = page;
          });
        },
        currentIndex: _currentIndex,
          selectedItemColor: AppColors.terracotta,
          unselectedItemColor: AppColors.greyText,
          unselectedLabelStyle: TextStyle(color: AppColors.greyText ),
          showUnselectedLabels: true,
          items: [
        BottomNavigationBarItem(icon: Icon(Icons.home,),label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart,),label: "Progress"),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt,),label: "Scan"),
        BottomNavigationBarItem(icon: Icon(Icons.chat,),label: "Chat"),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded,),label: "Profile"),
      ]),

    );
  }
}
