import 'package:flutter/material.dart';
import 'app_colors.dart';

class MakeSkinAnalysisPage extends StatefulWidget {
  const MakeSkinAnalysisPage({super.key});

  @override
  State<MakeSkinAnalysisPage> createState() => _MakeSkinAnalysisPageState();
}

class _MakeSkinAnalysisPageState extends State<MakeSkinAnalysisPage> with SingleTickerProviderStateMixin {
  late AnimationController _scannerController;
  late Animation<double> _scannerAnimation;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _scannerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _startScanning() {
    setState(() {
      _isScanning = true;
    });
    // Simulate scan process
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        // Show completion or navigate to results
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandPink, // Dark background for scanner feel
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryPurple, AppColors.lightPurple],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: AppColors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      'Skin Analysis',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer for centering
                  ],
                ),
              ),
              
              const Text(
                'Position your face within the frame',
                style: TextStyle(color: AppColors.white, fontSize: 14),
              ),
              
              const Spacer(),
              
              // Scanner UI
              Stack(
                alignment: Alignment.center,
                children: [
                  // Oval Frame (Camera Placeholder)
                  Container(
                    width: 280,
                    height: 400,
                    decoration: BoxDecoration(
                      color: AppColors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(140),
                      border: Border.all(color: AppColors.white.withOpacity(0.5), width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(140),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.black.withOpacity(0.3),
                        ),
                        // Replace Icon with CameraPreview in real implementation
                        child: Image.asset("assets/images/logo.png")
                      ),
                    ),
                  ),
                  
                  // Scanning Brackets
                  const SizedBox(
                    width: 310,
                    height: 430,
                    child: CustomPaint(painter: ScannerBracketsPainter()),
                  ),
                  
                  // Moving Scan Line
                  if (_isScanning)
                    AnimatedBuilder(
                      animation: _scannerAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: 40 + (_scannerAnimation.value * 320),
                          child: Container(
                            width: 240,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.terracotta,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.terracotta.withOpacity(0.6),
                                  blurRadius: 15,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    
                  // "Face ID" style status text
                  if (_isScanning)
                    Positioned(
                      bottom: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Scanning ...',
                          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Instructions Icons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primaryPurple.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoIcon(Icons.wb_sunny_rounded, 'Good lighting'),
                      _buildInfoIcon(Icons.remove_red_eye_rounded, 'No glasses'),
                      _buildInfoIcon(Icons.auto_awesome_rounded, 'No filter'),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Scan Button
              GestureDetector(
                onTap: _isScanning ? null : _startScanning,
                child: Container(
                  width: 85,
                  height: 85,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 3),
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isScanning ? Icons.sync_rounded : Icons.camera_alt_rounded,
                      color: AppColors.primaryPurple,
                      size: 38,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoIcon(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: AppColors.white, size: 26),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class ScannerBracketsPainter extends CustomPainter {
  const ScannerBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white.withOpacity(0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const cornerSize = 30.0;

    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerSize, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerSize), paint);

    // Top-right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerSize, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerSize), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, size.height), Offset(cornerSize, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerSize), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerSize, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerSize), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
