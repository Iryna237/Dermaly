import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'services/gemini_service.dart';
import 'services/skin_analysis_storage.dart';
import 'skin_result.dart';

class SkinAnalysisProgressPage extends StatefulWidget {
  final String imagePath;
  const SkinAnalysisProgressPage({super.key, this.imagePath = 'assets/images/logo.png'});

  @override
  State<SkinAnalysisProgressPage> createState() => _SkinAnalysisProgressPageState();
}

class _SkinAnalysisProgressPageState extends State<SkinAnalysisProgressPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotsController;
  int _dotCount = 0;
  int _statusStepIndex = 0;
  Timer? _statusTimer;
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _statusSteps = [
    'Dermaly is analyzing your facial skin...',
    'Evaluating skin texture & concerns...',
    'Measuring hydration balance...',
    'Consulting Gemini AI skincare model...',
  ];

  @override
  void initState() {
    super.initState();
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) {
            setState(() {
              _dotCount = (_dotCount % 4) + 1; // Cycle 1, 2, 3, 4 dots
            });
            _dotsController.forward(from: 0);
          }
        }
      });
    _dotsController.forward();

    // Rotate status text every 2.5 seconds
    _statusTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted && _isLoading) {
        setState(() {
          _statusStepIndex = (_statusStepIndex + 1) % _statusSteps.length;
        });
      }
    });

    _performAnalysis();
  }

  Future<void> _performAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var result = await GeminiService.analyzeSkin(widget.imagePath);

      var saveFailed = false;
      try {
        result = await SkinAnalysisStorage.save(result);
      } catch (e) {
        debugPrint('Erreur sauvegarde analyse: $e');
        saveFailed = true;
      }

      if (!mounted) return;

      if (saveFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your analysis result could not be saved.')),
        );
      }

      // Retirer questionnaire/caméra de la pile : le retour ramène à l'accueil
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => SkinResultPage.fromResult(result),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      debugPrint('Analysis error: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _useDemoFallback() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SkinResultPage.fromResult(
          SkinAnalysisResult.fallback(imagePath: widget.imagePath),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
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
                Stack(
                  children: [
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.lightPurple, width: 4),
                      ),
                      child: ClipOval(
                        child: widget.imagePath.startsWith('assets/')
                            ? Image.asset(
                                widget.imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.face_retouching_natural,
                                  size: 80,
                                  color: AppColors.terracotta,
                                ),
                              )
                            : Image.file(
                                File(widget.imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.face_retouching_natural,
                                  size: 80,
                                  color: AppColors.terracotta,
                                ),
                              ),
                      ),
                    ),
                    CircularProgressIndicator(
                      constraints: BoxConstraints(
                        minWidth: 160,
                        minHeight: 160
                      ),
                      color: AppColors.primary,
                    )
                  ],
                ),
                const SizedBox(height: 30),

                if (_isLoading) ...[
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusSteps[_statusStepIndex],
                      key: ValueKey<int>(_statusStepIndex),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.greyText,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
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
                  const SizedBox(height: 25),
                  const Text(
                    'Gemini AI is processing your facial image',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.greyText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.terracotta,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Analysis Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkPurple,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _errorMessage ?? 'Unable to complete skin analysis.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.greyText,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _performAnalysis,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry Analysis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _useDemoFallback,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryPurple,
                        side: const BorderSide(color: AppColors.primaryPurple),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Preview Demo Results',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Camera'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
