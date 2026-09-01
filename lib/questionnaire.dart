import 'package:flutter/material.dart';
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

  // State for answers (simplified for this UI example)
  final Map<int, List<String>> _answers = {};

  void _onOptionSelected(int questionIndex, String option, bool multiple) {
    setState(() {
      if (!multiple) {
        _answers[questionIndex] = [option];
      } else {
        final current = _answers[questionIndex] ?? [];
        if (current.contains(option)) {
          current.remove(option);
        } else {
          current.add(option);
        }
        _answers[questionIndex] = current;
      }
    });
  }

  bool _isOptionSelected(int questionIndex, String option) {
    return _answers[questionIndex]?.contains(option) ?? false;
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
            if (_currentPage > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              Navigator.pop(context);
            }
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
          _buildNextButton("START ASSESSMENT", () {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(int index, String question, List<String> options, {required bool multiple}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            '$index. $question',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkPurple,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            multiple ? 'You can select multiple answers' : 'Select one answer',
            style: const TextStyle(color: AppColors.greyText, fontSize: 14),
          ),
          const SizedBox(height: 30),
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
                          color: AppColors.black.withOpacity(0.02),
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
          _buildNextButton("NEXT", () {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOutroPage() {
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
          const Text(
            "Now let's analyze your skin",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: AppColors.greyText,
            ),
          ),
          const Spacer(),
          _buildNextButton("START SKIN ANALYSIS", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MakeSkinAnalysisPage()),
            );
          }),
          const SizedBox(height: 50),

        ],
      ),
    );
  }

  Widget _buildNextButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.terracotta,
          foregroundColor: AppColors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
