class SkinAnalysisResult {
  final String imagePath;
  final int overallScore;
  final int hydrationLevel;
  final String skinType;
  final String skinTypeDetails;
  final Map<String, int> concerns;
  final String recommendationSummary;

  SkinAnalysisResult({
    required this.imagePath,
    required this.overallScore,
    required this.hydrationLevel,
    required this.skinType,
    required this.skinTypeDetails,
    required this.concerns,
    required this.recommendationSummary,
  });

  factory SkinAnalysisResult.fallback({required String imagePath}) {
    return SkinAnalysisResult(
      imagePath: imagePath,
      overallScore: 78,
      hydrationLevel: 68,
      skinType: 'Combination Skin',
      skinTypeDetails: 'Oily in T-zone, normal on cheeks',
      concerns: {
        'Dark Spots': 72,
        'Acne': 45,
        'Redness': 20,
        'Pores': 60,
        'Texture / Unevenness': 55,
        'Fine Lines': 15,
      },
      recommendationSummary:
      'Your skin is generating more oil in the T-zone. Focus on balancing, hydration and gentle care.',
    );
  }
}