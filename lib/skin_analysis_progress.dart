import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'skin_result.dart';

class SkinAnalysisProgressPage extends StatefulWidget {
  final String imagePath;
  const SkinAnalysisProgressPage({super.key, this.imagePath = 'assets/images/logo.png'});

  @override
  State<SkinAnalysisProgressPage> createState() => _SkinAnalysisProgressPageState();
}

class _SkinAnalysisProgressPageState extends State<SkinAnalysisProgressPage> with SingleTickerProviderStateMixin {
  late AnimationController _dotsController;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _dotCount = (_dotCount % 4) + 1; // Cycle 1, 2, 3, 4 dots
          });
          _dotsController.forward(from: 0);
        }
      });
    _dotsController.forward();
    
    // Simulate analysis completion and go to results
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SkinResultPage(imagePath: widget.imagePath)),
        );
      }
    });
  }

  @override
  void dispose() {
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String dots = '.' * _dotCount;
    
    return Scaffold(
      backgroundColor: AppColors.softPurple,
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 30),
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withAlpha(26), // 0.1 * 255
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image being analyzed
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.lightPurple, width: 4),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      widget.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.face_retouching_natural,
                        size: 80,
                        color: AppColors.terracotta,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                
                const Text(
                  'Analyzing your skin',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkPurple,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'Dermaly is analyzing your facial skin...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.greyText,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 35),
                
                // Loading dots animation
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Loading$dots',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryPurple,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                const Text(
                  'Please wait a moment',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.greyText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
