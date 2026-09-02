import 'package:flutter/material.dart';
import 'app_colors.dart';

class RoutineProduct {
  final String category;
  final String name;
  final String description;
  final IconData icon;
  final String imagePath;

  RoutineProduct({
    required this.category,
    required this.name,
    required this.description,
    required this.icon,
    required this.imagePath,
  });
}

class RoutinePage extends StatefulWidget {
  const RoutinePage({super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> {
  bool isMorning = true;
  int _currentIndex = 2; // Routine is the center item

  final List<RoutineProduct> morningProducts = [
    RoutineProduct(
      category: 'Cleanse',
      name: 'Foaming Cleanser',
      description: 'Gentle foaming cleanser with niacinamide and ceramides to regulate oil.',
      icon: Icons.bubble_chart_outlined,
      imagePath: 'assets/images/cleanser.png',
    ),
    RoutineProduct(
      category: 'Protect',
      name: 'Oil Control SPF 50',
      description: 'Oil-free sunscreen to prevent scars and dark spots.',
      icon: Icons.wb_sunny_outlined,
      imagePath: 'assets/images/sunscreen.png',
    ),
  ];

  final List<RoutineProduct> nightProducts = [
    RoutineProduct(
      category: 'Cleanse',
      name: 'Hydrating Cleanser',
      description: 'Deeply cleanses while maintaining skin moisture barrier.',
      icon: Icons.water_drop_outlined,
      imagePath: 'assets/images/cleanser.png',
    ),
    RoutineProduct(
      category: 'Treat',
      name: 'Retinol Serum',
      description: 'Helps resurface skin and minimize the appearance of pores.',
      icon: Icons.science_outlined,
      imagePath: 'assets/images/serum.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    List<RoutineProduct> currentProducts = isMorning ? morningProducts : nightProducts;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.darkPurple, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your skincare routine',
              style: TextStyle(
                color: AppColors.darkPurple,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.opacity, color: AppColors.brandPink, size: 18),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Morning/Night Toggle
            Row(
              children: [
                Expanded(
                  child: _buildToggleButton(
                    label: 'Morning',
                    icon: Icons.wb_sunny,
                    isSelected: isMorning,
                    onTap: () => setState(() => isMorning = true),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildToggleButton(
                    label: 'Night',
                    icon: Icons.nights_stay,
                    isSelected: !isMorning,
                    onTap: () => setState(() => isMorning = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            
            // Weekly Progress Section
            _buildWeeklyProgress(),
            
            const SizedBox(height: 25),
            
            // Routine Items
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentProducts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 20),
              itemBuilder: (context, index) {
                final product = currentProducts[index];
                return _buildRoutineCard(product);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPink.withAlpha(40) : AppColors.softPurple,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.brandPink : AppColors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.darkPurple : AppColors.greyText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              color: isSelected ? Colors.orangeAccent : AppColors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgress() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(25),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkPurple,
                ),
              ),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: '0 ',
                      style: TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextSpan(
                      text: 'day streak',
                      style: TextStyle(color: AppColors.greyText, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDayItem('Tue', false, false),
              _buildDayItem('Wed', false, false),
              _buildDayItem('Thu', false, false),
              _buildDayItem('Fri', false, false),
              _buildDayItem('Sat', false, false),
              _buildDayItem('Sun', true, true),
              _buildDayItem('Mon', true, false),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusLegend(AppColors.terracotta, 'Complete'),
              const SizedBox(width: 15),
              _buildStatusLegend(AppColors.terracotta.withAlpha(100), 'Partial'),
              const SizedBox(width: 15),
              _buildStatusLegend(AppColors.softPurple, 'Missed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayItem(String day, bool isHighlighted, bool isComplete) {
    return Column(
      children: [
        Text(day, style: const TextStyle(color: AppColors.greyText, fontSize: 11)),
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isHighlighted 
              ? (isComplete ? AppColors.terracotta : AppColors.terracotta.withAlpha(100))
              : AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.softPurple),
          ),
          child: isHighlighted 
            ? const Center(child: Text('~', style: TextStyle(color: AppColors.white, fontSize: 18)))
            : null,
        ),
      ],
    );
  }

  Widget _buildStatusLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.greyText, fontSize: 11)),
      ],
    );
  }

  Widget _buildRoutineCard(RoutineProduct product) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.terracotta.withAlpha(50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(product.icon, color: AppColors.terracotta, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      product.category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkPurple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  product.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkPurple),
                ),
                const SizedBox(height: 6),
                Text(
                  product.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.greyText, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 70,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.softPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                product.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.medication_outlined, color: AppColors.terracotta.withAlpha(100), size: 30),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.terracotta.withAlpha(180),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check, color: AppColors.white, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [BoxShadow(color: AppColors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(0, Icons.search, 'care'),
            _buildBottomNavItem(1, Icons.add, 'routine', isCenter: true),
            _buildBottomNavItem(2, Icons.access_time, 'evolution'),
            _buildBottomNavItem(3, Icons.calendar_today, 'daily'),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label, {bool isCenter = false}) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index != 1) {
          setState(() => _currentIndex = index);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCenter)
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.brandPink,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: AppColors.white, size: 28),
            )
          else ...[
            Icon(
              icon,
              color: isSelected ? AppColors.terracotta : AppColors.greyText,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.terracotta : AppColors.greyText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
