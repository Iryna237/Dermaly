import 'package:flutter/material.dart';
import 'package:ziskin/homepage.dart';
import 'app_colors.dart';
import 'make_skin_analysis.dart';

class QuestionnairePage extends StatefulWidget {
  const QuestionnairePage({super.key});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // State for answers
  final Map<int, List<String>> _answers = {};

  // Pour suivre les questions déjà répondues
  final Set<int> _answeredQuestions = {};

  void _onOptionSelected(int questionIndex, String option, bool multiple) {
    setState(() {
      if (!multiple) {
        _answers[questionIndex] = [option];
        // Marquer comme répondue
        _answeredQuestions.add(questionIndex);
      } else {
        final current = _answers[questionIndex] ?? [];
        if (current.contains(option)) {
          current.remove(option);
          // Si plus aucune option sélectionnée, retirer des répondues
          if (current.isEmpty) {
            _answeredQuestions.remove(questionIndex);
          }
        } else {
          current.add(option);
          // Marquer comme répondue
          _answeredQuestions.add(questionIndex);
        }
        _answers[questionIndex] = current;
      }
    });
  }

  bool _isOptionSelected(int questionIndex, String option) {
    return _answers[questionIndex]?.contains(option) ?? false;
  }

  // Vérifier si une question a été répondue
  bool _isQuestionAnswered(int questionIndex) {
    // Pour les questions de l'intro (0) et outro (12), toujours true
    if (questionIndex == 0 || questionIndex == 12) return true;

    // Vérifier si la question a été répondue
    final answer = _answers[questionIndex];
    return answer != null && answer.isNotEmpty;
  }

  // Vérifier si toutes les questions ont été répondues
  bool _areAllQuestionsAnswered() {
    // Liste des indices des questions (1 à 11)
    for (int i = 1; i <= 11; i++) {
      if (!_isQuestionAnswered(i)) {
        return false;
      }
    }
    return true;
  }

  // Gérer la navigation vers la page suivante
  void _goToNextPage() {
    // Pour la page d'intro (page 0)
    if (_currentPage == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Pour les questions (pages 1 à 11)
    if (_currentPage >= 1 && _currentPage <= 11) {
      if (!_isQuestionAnswered(_currentPage)) {
        // Afficher un message d'erreur
        _showErrorSnackBar('Veuillez sélectionner une réponse avant de continuer');
        return;
      }

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Pour la page de fin (page 12)
    if (_currentPage == 12) {
      // Vérifier que toutes les questions ont été répondues
      if (!_areAllQuestionsAnswered()) {
        _showErrorSnackBar('Veuillez répondre à toutes les questions');
        return;
      }

      // Naviguer vers l'analyse
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MakeSkinAnalysisPage()),
      );
    }
  }

  // Afficher un message d'erreur
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softPurple,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.darkPurple, size: 20),
          onPressed: () {
           Navigator.pop(context);
          },
        ),
        title: Text(
          _currentPage == 0 ? '' : 'Step $_currentPage of 11',
          style: const TextStyle(color: AppColors.greyText, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (int page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: [
          _buildIntroPage(),
          _buildQuestionPage(
            1,
            'How would you describe your skin?',
            ['Dry', 'Oily', 'Normal', 'Combination', 'Sensitive', 'Mature'],
            multiple: true,
          ),
          _buildQuestionPage(
            2,
            'Which skincare products do you currently use?',
            ['Cleanser', 'Moisturizer', 'SPF', 'Serum', 'Toner', 'Exfoliator'],
            multiple: true,
          ),
          _buildQuestionPage(
            3,
            'Are you using suncream protection?',
            ['Every day', 'Sometimes', 'Never', 'Only in summer'],
            multiple: false,
          ),
          _buildQuestionPage(
            4,
            'How sensitive is your skin?',
            ['Not sensitive', 'Slightly sensitive', 'Moderately sensitive', 'Very sensitive'],
            multiple: false,
          ),
          _buildQuestionPage(
            5,
            'What are your main skin concerns?',
            ['Acne', 'Aging', 'Dullness', 'Dark spots', 'Redness', 'Texture'],
            multiple: true,
          ),
          _buildQuestionPage(
            6,
            'Are you allergic to certain cosmetic product?',
            ['Yes', 'No', 'Not sure'],
            multiple: false,
          ),
          _buildQuestionPage(
            7,
            'If yes, which products or ingredients cause it?',
            ['Fragrance', 'Preservatives', 'Specific oils', 'Retinol', 'Vitamin C', 'Other'],
            multiple: true,
          ),
          _buildQuestionPage(
            8,
            'During the day, which part of your face becomes the shiniest?',
            ['T-zone', 'Cheeks', 'Forehead', 'Whole face', 'None'],
            multiple: false,
          ),
          _buildQuestionPage(
            9,
            'Do you experience redness or irritation on your face?',
            ['Frequently', 'Sometimes', 'Rarely', 'Never'],
            multiple: false,
          ),
          _buildQuestionPage(
            10,
            'Do you frequently get pimples or breakouts?',
            ['Yes', 'No', 'Only during hormonal cycles'],
            multiple: false,
          ),
          _buildQuestionPage(
            11,
            'Does your skin react quickly when you try a new product?',
            ['Yes, always', 'Sometimes', 'Rarely', 'Never'],
            multiple: false,
          ),
          _buildOutroPage(),
        ],
      ),
    );
  }

  Widget _buildIntroPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Image.asset("assets/images/logo.png"),
          ),
          const SizedBox(height: 40),
          const Text(
            "Let's get to know\nyour skin",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkPurple,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Answer a few questions to help us better understand your skin and personalize your skincare experience",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.greyText,
              height: 1.5,
            ),
          ),
          const Spacer(),
          _buildNextButton("START ASSESSMENT", _goToNextPage),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(int index, String question, List<String> options, {required bool multiple}) {
    final isAnswered = _isQuestionAnswered(index);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$index. $question',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkPurple,
                  ),
                ),
              ),
              if (isAnswered)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 24,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            multiple ? 'You can select multiple answers' : 'Select one answer',
            style: const TextStyle(color: AppColors.greyText, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: options.length,
              itemBuilder: (context, i) {
                final option = options[i];
                final isSelected = _isOptionSelected(index, option);
                return GestureDetector(
                  onTap: () => _onOptionSelected(index, option, multiple),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.lightPurple : AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryPurple : AppColors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withAlpha(5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? AppColors.primaryPurple : AppColors.darkPurple,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppColors.primaryPurple, size: 22),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage > 0) {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.terracotta,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Icon(Icons.arrow_back_ios, size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: _buildNextButton("NEXT", _goToNextPage),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNextButton(String text, VoidCallback onPressed) {
    return SizedBox(
      height: 60,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isQuestionAnswered(_currentPage) ? AppColors.terracotta: Colors.grey.shade500,
          foregroundColor: _isQuestionAnswered(_currentPage) ? AppColors.white:Colors.white70,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutroPage() {
    final allAnswered = _areAllQuestionsAnswered();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Image.asset("assets/images/logo.png"),
          ),
          const SizedBox(height: 40),
          const Text(
            "Your questionnaire\nis complete",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkPurple,
            ),
          ),
          const SizedBox(height: 20),
          if (!allAnswered)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚠️ Please answer all questions before proceeding',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const Text(
              "Now let's analyze your skin",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: AppColors.greyText,
              ),
            ),
          const Spacer(),
          _buildNextButton("START SKIN ANALYSIS", _goToNextPage),
          const SizedBox(height: 50),
        ],
      ),
    );
  }
}