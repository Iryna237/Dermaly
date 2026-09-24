import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'models/routine_product.dart';
import 'product_image.dart';
import 'products.dart';
import 'services/routine_log_storage.dart';
import 'services/product_image_service.dart';
import 'services/routine_storage.dart';

class RoutinePage extends StatefulWidget {
  const RoutinePage({super.key});

  @override
  State<RoutinePage> createState() => _RoutinePageState();
}

class _RoutinePageState extends State<RoutinePage> with WidgetsBindingObserver {
  bool isMorning = true;
  int _currentIndex = 1; // Routine is the center item

  bool _isLoading = true;
  List<RoutineProduct> _products = _sampleRoutine;

  /// Produits coches, par jour. La journee en cours y est absente tant que rien
  /// n'a ete coche : les cases repartent donc vides a chaque nouvelle journee.
  Map<String, RoutineDayLog> _logs = const {};
  DateTime _today = _dateOnly(DateTime.now());

  static const List<String> _weekdayLabels = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  /// Routine d'exemple affichee tant que l'utilisateur n'a pas lance d'analyse
  static const List<RoutineProduct> _sampleRoutine = [
    RoutineProduct(
      category: 'Cleanse',
      name: 'Foaming Cleanser',
      description: 'Gentle foaming cleanser with niacinamide and ceramides to regulate oil.',
      time: RoutineTime.both,
    ),
    RoutineProduct(
      category: 'Protect',
      name: 'Oil Control SPF 50',
      description: 'Oil-free sunscreen to prevent scars and dark spots.',
      time: RoutineTime.morning,
    ),
    RoutineProduct(
      category: 'Treat',
      name: 'Retinol Serum',
      description: 'Helps resurface skin and minimize the appearance of pores.',
      time: RoutineTime.evening,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRoutine();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// L'app laissee ouverte puis reprise le lendemain doit montrer une journee
  /// vierge, pas les cases de la veille.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDay();
  }

  void _refreshDay() {
    final today = _dateOnly(DateTime.now());
    if (today == _today) return;
    setState(() => _today = today);
  }

  Future<void> _loadRoutine() async {
    List<RoutineProduct>? saved;
    try {
      final stored = await RoutineStorage.loadSaved();
      saved = stored?.products;

      // Routine enregistrée avant la recherche de photos : la compléter une
      // fois, puis marquer pour ne plus y revenir
      if (saved != null && stored?.imagesResolved != true) {
        final resolved = await ProductImageService.resolve(saved);
        saved = resolved;
        await RoutineStorage.save(resolved, imagesResolved: true);
      }
    } catch (e) {
      debugPrint('Erreur chargement routine: $e');
    }

    var logs = const <String, RoutineDayLog>{};
    try {
      logs = await RoutineLogStorage.loadSince(
        _today.subtract(const Duration(days: RoutineLogStorage.historyDays)),
      );
    } catch (e) {
      debugPrint('Erreur chargement journal routine: $e');
    }

    if (!mounted) return;
    setState(() {
      // Aucune routine enregistree : on garde l'exemple plutot qu'une page vide
      if (saved != null) _products = saved;
      _logs = logs;
      _isLoading = false;
    });
  }

  /// Produits attendus au moment demande de la journee
  Set<String> _idsFor({required bool morning}) => {
        for (final product in _products)
          if (morning ? product.isMorning : product.isEvening) product.id,
      };

  /// Journee en cours, ramenee a la routine actuelle : un produit retire de la
  /// routine ne doit plus etre attendu ni compte comme applique.
  RoutineDayLog get _todayLog =>
      (_logs[RoutineLogStorage.dayKey(_today)] ?? RoutineDayLog.empty).withRoutine(
        morningIds: _idsFor(morning: true),
        eveningIds: _idsFor(morning: false),
      );

  RoutineDayLog _logFor(DateTime day) {
    if (day == _today) return _todayLog;
    return _logs[RoutineLogStorage.dayKey(day)] ?? RoutineDayLog.empty;
  }

  /// Les sept derniers jours, du plus ancien a aujourd'hui
  List<DateTime> get _weekDays => [
        for (var i = 6; i >= 0; i--)
          DateTime(_today.year, _today.month, _today.day - i),
      ];

  /// Jours complets enchaines jusqu'a aujourd'hui. La journee en cours ne casse
  /// pas la serie tant qu'elle n'est pas finie : on repart alors de la veille.
  int get _dayStreak {
    var day = _today;
    if (_logFor(day).status != RoutineDayStatus.complete) {
      day = DateTime(day.year, day.month, day.day - 1);
    }

    var streak = 0;
    while (_logFor(day).status == RoutineDayStatus.complete) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  /// Coche ou decoche un produit pour le moment affiche (matin ou soir)
  Future<void> _toggleProduct(RoutineProduct product) async {
    _refreshDay();

    final day = _today;
    final updated = _todayLog.toggle(product.id, morning: isMorning);
    setState(() => _logs = {..._logs, RoutineLogStorage.dayKey(day): updated});

    // La case reste cochee meme si l'enregistrement echoue : Firestore garde
    // l'ecriture en cache, l'utilisateur n'a rien a recocher.
    try {
      await RoutineLogStorage.saveDay(day, updated);
    } catch (e) {
      debugPrint('Erreur sauvegarde de la journee: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your progress could not be saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Un produit du matin ET du soir apparait dans les deux listes
    final currentProducts = _products
        .where((p) => isMorning ? p.isMorning : p.isEvening)
        .toList();

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
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(color: AppColors.primaryPurple),
              )
            else if (currentProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  isMorning
                      ? 'No product in your morning routine yet.'
                      : 'No product in your evening routine yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.greyText),
                ),
              )
            else
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
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$_dayStreak ',
                      style: const TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const TextSpan(
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
            children: [for (final day in _weekDays) _buildDayItem(day)],
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

  Widget _buildDayItem(DateTime day) {
    final status = _logFor(day).status;
    final isToday = day == _today;

    // La journee en cours n'est pas un jour manque tant qu'elle n'est pas finie
    final color = switch (status) {
      RoutineDayStatus.complete => AppColors.terracotta,
      RoutineDayStatus.partial => AppColors.terracotta.withAlpha(100),
      RoutineDayStatus.missed => isToday ? AppColors.white : AppColors.softPurple,
    };

    return Column(
      children: [
        Text(
          _weekdayLabels[day.weekday - 1],
          style: TextStyle(
            color: isToday ? AppColors.darkPurple : AppColors.greyText,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isToday ? AppColors.terracotta : AppColors.softPurple,
              width: isToday ? 1.5 : 1,
            ),
          ),
          child: switch (status) {
            RoutineDayStatus.complete =>
              const Icon(Icons.check, color: AppColors.white, size: 18),
            RoutineDayStatus.partial =>
              const Icon(Icons.remove, color: AppColors.white, size: 18),
            RoutineDayStatus.missed => null,
          },
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
    final isDone = _todayLog.isDone(product.id, morning: isMorning);

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
              child: ProductImage(product: product, iconSize: 30),
            ),
          ),
          const SizedBox(width: 12),
          // Coche du jour : vide par defaut, elle marque le produit applique
          Semantics(
            button: true,
            checked: isDone,
            label: 'Mark ${product.name} as applied',
            child: GestureDetector(
              onTap: () => _toggleProduct(product),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone ? AppColors.terracotta.withAlpha(180) : AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.terracotta.withAlpha(isDone ? 180 : 80),
                    width: 1.5,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check, color: AppColors.white, size: 18)
                    : null,
              ),
            ),
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
        // Care ouvre les produits proposes pour la routine en cours
        if (index == 0) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RecommendedProductsPage.saved()),
          );
          return;
        }
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
