import 'dart:io';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'routine.dart';
import 'services/gemini_service.dart';

class SkinResultPage extends StatelessWidget {
  final String imagePath;
  final int overallScore;
  final int hydrationLevel;
  final Map<String, int> concerns;
  final String skinType;
  final String skinTypeDetails;
  final String recommendationSummary;

  const SkinResultPage({
    super.key,
    required this.imagePath,
    required this.overallScore,
    required this.hydrationLevel,
    required this.skinType,
    required this.skinTypeDetails,
    required this.concerns,
    required this.recommendationSummary,
  });

  // Constructeur depuis le résultat de l'analyse Gemini
  factory SkinResultPage.fromResult(SkinAnalysisResult result) {
    return SkinResultPage(
      imagePath: result.imagePath,
      overallScore: result.overallScore,
      hydrationLevel: result.hydrationLevel,
      skinType: result.skinType,
      skinTypeDetails: result.skinTypeDetails,
      concerns: result.concerns,
      recommendationSummary: result.recommendationSummary,
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  String _getFormattedTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  }

  String _getScoreRating() {
    if (overallScore >= 80) return 'Excellent ';
    if (overallScore >= 65) return 'Good ';
    if (overallScore >= 50) return 'Fair ';
    return 'Needs Care ';
  }

  Color _getScoreRatingColor() {
    if (overallScore >= 80) return Colors.green;
    if (overallScore >= 65) return Colors.orangeAccent;
    return AppColors.terracotta;
  }

  String _getHydrationDescription() {
    if (hydrationLevel >= 75) return 'Your skin is well hydrated and moisturized.';
    if (hydrationLevel >= 55) return 'Your skin has balanced hydration.';
    return 'Your skin is slightly dehydrated. Focus on hydrating serums.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analysis Result',
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share, color: AppColors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              const Text(
                'Your Skin Analysis Result 🎉',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Analyzed on ${_getFormattedDate()} • ${_getFormattedTime()}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.greyText,
                ),
              ),
              const SizedBox(height: 25),

              // Photo et Score Global
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: SizedBox(
                      width: 140,
                      height: 180,
                      child: imagePath.startsWith('assets/')
                          ? Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      )
                          : Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: CircularProgressIndicator(
                              value: overallScore / 100,
                              strokeWidth: 10,
                              backgroundColor: AppColors.softPurple,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Overall\nSkin Score',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkPurple,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '$overallScore%',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getScoreRating(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _getScoreRatingColor(),
                                    ),
                                  ),
                                  Icon(Icons.auto_awesome, color: _getScoreRatingColor(), size: 14),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // Type de Peau
              _buildResultCard(
                icon: Icons.opacity,
                iconColor: AppColors.primaryPurple,
                title: 'Skin Type',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skinType,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skinTypeDetails,
                      style: const TextStyle(color: AppColors.greyText, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Préoccupations
              _buildResultCard(
                icon: Icons.spa,
                iconColor: AppColors.brandPink,
                title: 'Skin Concerns',
                child: Column(
                  children: concerns.entries.map((entry) {
                    return _buildConcernProgress(entry.key, entry.value);
                  }).toList(),
                ),
              ),
              const SizedBox(height: 15),

              // Niveau d'Hydratation
              _buildResultCard(
                icon: Icons.water_drop,
                iconColor: Colors.blue,
                title: 'Hydration Level',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: hydrationLevel / 100,
                            minHeight: 8,
                            backgroundColor: AppColors.softPurple,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Text(
                          '$hydrationLevel%',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getHydrationDescription(),
                      style: const TextStyle(color: AppColors.greyText, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // Recommandation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.softPurple.withAlpha(100),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info, color: AppColors.primaryPurple, size: 24),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        recommendationSummary,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.darkPurple,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Bouton d'action
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RoutinePage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Recommended Products',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 15),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.softPurple,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 50, color: AppColors.primaryPurple),
          SizedBox(height: 5),
          Text('No Image', style: TextStyle(fontSize: 12, color: AppColors.greyText)),
        ],
      ),
    );
  }

  Widget _buildResultCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.softGrey),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  Widget _buildConcernProgress(String label, int value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: AppColors.black),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 4,
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 6,
              backgroundColor: AppColors.softPurple,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 15),
          SizedBox(
            width: 35,
            child: Text(
              '$value%',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}