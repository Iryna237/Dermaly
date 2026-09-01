import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'landing_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dermaly',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryPurple,
          primary: AppColors.primaryPurple,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.white,
      ),
      home: const LandingPage(),
    );
  }
}
