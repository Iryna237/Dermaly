import 'package:flutter/material.dart';
import 'package:ziskin/register.dart';
import 'package:ziskin/splash_screen.dart';
import 'app_colors.dart';
import 'landing_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> isLoggedIn() async {
    await Future.delayed(Duration(seconds: 8));
    return true;
  }

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
      home: FutureBuilder(
        future:
        isLoggedIn(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const SplashScreen();
          }

          if (snapshot.data == true) {
            LandingPage();
          }

          if (snapshot.hasError) {
            return const RegisterPage();
          }

          return const RegisterPage();
        },
      ),
    );
  }
}
