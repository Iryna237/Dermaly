import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_colors.dart';
import 'skin_analysis_progress.dart';

class MakeSkinAnalysisPage extends StatefulWidget {
  final ScanPurpose purpose;

  /// Retour quand la page est un onglet : il n'y a pas de route à dépiler, c'est
  /// ScreenManage qui revient à l'accueil. Null quand la page est empilée.
  final VoidCallback? onBack;

  const MakeSkinAnalysisPage({super.key, this.purpose = ScanPurpose.skinAnalysis, this.onBack});

  @override
  State<MakeSkinAnalysisPage> createState() => _MakeSkinAnalysisPageState();
}

class _MakeSkinAnalysisPageState extends State<MakeSkinAnalysisPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _scannerController;
  late final Animation<double> _scannerAnimation;
  bool _isScanning = false;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  final FlashMode _flashMode = FlashMode.off;
  // Accès caméra refusé : on explique au lieu d'afficher un cadre vide
  bool _permissionDenied = false;
  // Refus définitif : seuls les réglages peuvent rendre l'accès
  bool _permanentlyDenied = false;
  // La boîte de dialogue de permission met l'app en pause : ne pas relancer
  // la caméra au retour pendant que la demande est encore en cours
  bool _requestingPermission = false;




  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // La ligne de scan balaie en continu tant que l'aperçu caméra est affiché
    _scannerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scannerAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;
    });
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

      // La caméra reste vivante sous la page d'analyse : rendre la main au
      // déclencheur, sinon il reste désactivé au retour
      setState(() => _isScanning = false);

      // 2. Page de progression empilée AU-DESSUS de la caméra (pushReplacement
      //    remplacerait l'onglet Scan, donc tout le ScreenManage, et un retour
      //    depuis l'analyse dépilerait la dernière route : écran noir).
      //    Les écrans de résultat retirent ensuite la caméra de la pile.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SkinAnalysisProgressPage(imagePath: photo.path, purpose: widget.purpose),
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
    if (_requestingPermission) return;
    _requestingPermission = true;
    final PermissionStatus cameraPermission;
    try {
      cameraPermission = await Permission.camera.request();
    } finally {
      _requestingPermission = false;
    }
    if (!mounted) return;

    if (!cameraPermission.isGranted) {
      setState(() {
        _permissionDenied = true;
        _permanentlyDenied = cameraPermission.isPermanentlyDenied || cameraPermission.isRestricted;
      });
      return;
    }
    if (_permissionDenied) {
      setState(() {
        _permissionDenied = false;
        _permanentlyDenied = false;
      });
    }

    final cameras = await availableCameras();
    // Page fermée pendant la demande de permission : ne pas ouvrir une caméra qui ne serait jamais libérée
    if (!mounted || cameras.isEmpty) return;
    _cameras = cameras;
    // Au retour d'arrière-plan, on rouvre la caméra choisie avant la pause
    if (_selectedCameraIndex >= cameras.length) _selectedCameraIndex = 0;
    _initCameraController(cameras[_selectedCameraIndex]);
  }

  void _initCameraController(CameraDescription cameraDescription) {
    if (_cameraController != null) {
      _cameraController?.dispose();
    }
    final controller = CameraController(
      cameraDescription,
      //ResolutionPreset.ultraHigh,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _cameraController = controller;
    controller
        .initialize()
        .then((_) {
      // Page fermée ou caméra relâchée pendant l'initialisation
      if (!mounted || _cameraController != controller) return;
      controller.setFlashMode(_flashMode);
      setState(() {});
    })
        .catchError((e) {
      debugPrint('Erreur caméra: $e');
    });
  }

  /// Libère la caméra quand l'app passe en arrière-plan : Android la reprend
  /// aux autres apps, et un contrôleur gardé ouvert rend un aperçu noir au retour.
  void _releaseCamera() {
    final controller = _cameraController;
    if (controller == null) return;
    _cameraController = null;
    controller.dispose();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // Sur le web, inactive veut seulement dire que la fenêtre a perdu le
      // focus : on attend que l'onglet soit masqué
      case AppLifecycleState.inactive when !kIsWeb:
      case AppLifecycleState.hidden:
        _releaseCamera();
      case AppLifecycleState.resumed:
        if (_cameraController == null) _resumeCamera();
      default:
        break;
    }
  }

  /// Au retour au premier plan, rouvre la caméra si l'accès est accordé, y
  /// compris quand il vient de l'être dans les réglages. On lit seulement le
  /// statut : redemander ici rouvrirait la boîte de dialogue qu'on vient de
  /// refuser, puisque sa fermeture ramène elle-même l'app au premier plan.
  Future<void> _resumeCamera() async {
    if (_requestingPermission) return;
    final status = await Permission.camera.status;
    if (!mounted || _cameraController != null) return;
    if (status.isGranted) _initCamera();
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    // Null si la permission caméra a été refusée
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = widget.onBack != null || Navigator.canPop(context);

    // En onglet, le bouton retour d'Android revient à l'accueil au lieu de
    // fermer l'app
    return PopScope(
      canPop: widget.onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack?.call();
      },
      child: Scaffold(
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
                    children: [
                      if (canGoBack)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white, size: 20),
                          tooltip: widget.onBack != null ? 'Home' : 'Back',
                          onPressed: _goBack,
                        )
                      else
                        const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          widget.purpose == ScanPurpose.monthlyProgress ? 'Monthly Scan' : 'Skin Analysis',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                    SizedBox(
                      //width: 400,
                      height: 420,

                      child: (_cameraController != null &&
                          _cameraController!
                              .value
                              .isInitialized)
                          ? ClipRRect(borderRadius: BorderRadiusGeometry.circular(40),child: CameraPreview(_cameraController!))
                          : _permissionDenied
                              ? _buildPermissionDenied()
                              : Image.asset("assets/images/logo.png",width: 100,),
                    ),

                    if (!_permissionDenied)
                      IconButton(onPressed: _switchCamera, icon: Icon(Icons.cameraswitch)),

                    // Moving Scan Line
                    if (_cameraController != null && _cameraController!.value.isInitialized)                    AnimatedBuilder(
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
      ),
    );
  }

  /// Accès caméra refusé : dire pourquoi l'aperçu manque et comment le rendre.
  Widget _buildPermissionDenied() {
    // Sur le web, l'accès se règle dans le navigateur : pas de réglages à ouvrir
    final openSettings = _permanentlyDenied && !kIsWeb;
    final String message;
    if (kIsWeb) {
      message = 'Allow camera access for this site in your browser, then try again.';
    } else if (_permanentlyDenied) {
      message = 'Camera access is turned off for Dermaly. Turn it on in Settings to scan your skin.';
    } else {
      message = 'Dermaly needs the camera to take a photo of your skin.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded, color: AppColors.white, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Camera access needed',
              style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.white, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              // Au retour des réglages, didChangeAppLifecycleState revérifie l'accès
              onPressed: openSettings ? openAppSettings : _initCamera,
              icon: Icon(openSettings ? Icons.settings_rounded : Icons.photo_camera_rounded),
              label: Text(openSettings ? 'Open Settings' : 'Allow Camera'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.white,
                foregroundColor: AppColors.primaryPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
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
