import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_colors.dart';
import 'skin_analysis_progress.dart';

class MakeSkinAnalysisPage extends StatefulWidget {
  const MakeSkinAnalysisPage({super.key});

  @override
  State<MakeSkinAnalysisPage> createState() => _MakeSkinAnalysisPageState();
}

class _MakeSkinAnalysisPageState extends State<MakeSkinAnalysisPage> with WidgetsBindingObserver {
  late AnimationController _scannerController;
  late Animation<double> _scannerAnimation;
  bool _isScanning = false;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  final FlashMode _flashMode = FlashMode.off;




  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();

    /*_scannerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );*/
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    _initCameraController(_cameras![_selectedCameraIndex]);
  }

  // Méthode pour capturer la vraie photo
  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La caméra n\'est pas prête.')),
      );
      return;
    }

    if (_cameraController!.value.isTakingPicture || _isScanning) return;

    try {
      setState(() {
        _isScanning = true;
      });

      // 1. Capture de la photo réelle depuis le flux caméra
      final XFile photo = await _cameraController!.takePicture();

      if (!mounted) return;

      // 2. Redirection vers la page de progression en lui passant le chemin de la VRAIE photo
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SkinAnalysisProgressPage(imagePath: photo.path),
        ),
      );
    } catch (e) {
      debugPrint('Erreur lors de la prise de photo : $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la capture : $e')),
        );
      }
    }
  }

  Future<void> _initCamera() async {
    final cameraPermission = await Permission.camera.request();
    if (cameraPermission != PermissionStatus.granted) {
      return;
    }

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameras = cameras;
    _selectedCameraIndex = 0;
    _initCameraController(cameras[_selectedCameraIndex]);
  }

  void _initCameraController(CameraDescription cameraDescription) {
    if (_cameraController != null) {
      _cameraController?.dispose();
    }
    _cameraController = CameraController(
      cameraDescription,
      //ResolutionPreset.ultraHigh,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _cameraController
        ?.initialize()
        .then((_) {
      if (!mounted) return;
      _cameraController?.setFlashMode(_flashMode);
      setState(() {});
    })
        .catchError((e) {
      debugPrint('Erreur caméra: $e');
    });
  }


  @override
  void dispose() {
    _scannerController.dispose();
    _cameraController!.dispose();
    super.dispose();
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
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    /*IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: AppColors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),*/
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
                  Container(
                    //width: 400,
                    height: 420,
                    decoration: BoxDecoration(
                      color: AppColors.black.withAlpha(51), // 0.2 * 255
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: AppColors.white.withAlpha(128), width: 1.5),
                    ),
                    child: (_cameraController != null &&
                        _cameraController!
                            .value
                            .isInitialized)
                        ? CameraPreview(_cameraController!) : Image.asset("assets/images/logo.png"),
                  ),

                 /* Container(
                    width: 40,
                    height: 420,
                    decoration: BoxDecoration(
                      color: AppColors.black.withAlpha(51), // 0.2 * 255
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: AppColors.white.withAlpha(128), width: 1.5),
                    ),
                  ),*/

                  // Scanning Brackets
                  const SizedBox(
                    width: 310,
                    height: 430,
                    child: CustomPaint(painter: ScannerBracketsPainter()),
                  ),
                  IconButton(onPressed: _switchCamera, icon: Icon(Icons.cameraswitch)),

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
                                  color: AppColors.terracotta.withAlpha(153), // 0.6 * 255
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
                          color: AppColors.black.withAlpha(128), // 0.5 * 255
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withAlpha(77), // 0.3 * 255
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryPurple.withAlpha(26)), // 0.1 * 255
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

              const SizedBox(height: 20),

              // Scan Button
// Mettre à jour le GestureDetector du bouton de scan
              GestureDetector(
                onTap: _isScanning ? null : _captureAndAnalyze,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoIcon(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: AppColors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
      ..color = AppColors.white.withAlpha(204) // 0.8 * 255
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

    // Bottom-right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerSize, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerSize), paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
