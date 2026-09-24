import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'models/routine_product.dart';
import 'product_image.dart';
import 'routine.dart';
import 'services/gemini_service.dart';
import 'services/notification_service.dart';
import 'services/product_image_service.dart';
import 'services/questionnaire_storage.dart';
import 'services/routine_storage.dart';

/// Produits proposés par Gemini à partir de la dernière analyse de peau.
///
/// Les produits retenus deviennent la routine de l'utilisateur : ils sont
/// enregistrés dès leur réception, et la page Routine les affiche répartis
/// entre matin et soir.
///
/// Avec [RecommendedProductsPage.saved], la page relit la routine enregistrée
/// au lieu d'en demander une nouvelle : c'est la consultation des produits déjà
/// proposés, sans rappeler Gemini ni remplacer la routine en cours.
class RecommendedProductsPage extends StatefulWidget {
  /// Analyse à partir de laquelle recommander, ou null pour relire la routine
  /// déjà enregistrée.
  final SkinAnalysisResult? analysis;

  const RecommendedProductsPage({super.key, required this.analysis});

  const RecommendedProductsPage.saved({super.key}) : analysis = null;

  @override
  State<RecommendedProductsPage> createState() => _RecommendedProductsPageState();
}

/// Filtre du bandeau de puces
enum _Filter { all, morning, night }

class _RecommendedProductsPageState extends State<RecommendedProductsPage> {
  _Filter _filter = _Filter.all;

  bool _isLoading = true;
  String? _errorMessage;
  bool _saveFailed = false;
  List<RoutineProduct> _products = const [];

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _saveFailed = false;
    });

    final analysis = widget.analysis;
    if (analysis == null) {
      await _loadSavedRoutine();
      return;
    }

    try {
      // Allergies et produits déjà utilisés : sans eux, une recommandation peut
      // proposer un actif que l'utilisateur a déclaré ne pas supporter
      Map<String, List<String>>? questionnaire;
      try {
        questionnaire = await QuestionnaireStorage.load();
      } catch (e) {
        debugPrint('Erreur chargement du questionnaire: $e');
      }

      final recommended = await GeminiService.recommendRoutine(
        analysis,
        questionnaire: questionnaire,
      );

      // Photos des vrais produits quand une base ouverte en possède. Résolues
      // une fois ici, pour que la routine les porte sans nouvelle recherche.
      final products = await ProductImageService.resolve(recommended);

      // La recommandation devient la routine de l'utilisateur. Un échec de
      // sauvegarde n'empêche pas de consulter les produits, il est juste signalé.
      var saveFailed = false;
      try {
        await RoutineStorage.save(products, imagesResolved: true);
      } catch (e) {
        debugPrint('Erreur sauvegarde routine: $e');
        saveFailed = true;
      }

      // Une routine existe désormais : activer les rappels matin et soir
      if (!saveFailed) await NotificationService.refreshSchedules();

      if (!mounted) return;
      setState(() {
        _products = products;
        _saveFailed = saveFailed;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur recommandation produits: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  /// Relit la routine enregistrée, sans rien demander ni rien réécrire
  Future<void> _loadSavedRoutine() async {
    List<RoutineProduct>? saved;
    String? error;
    try {
      saved = await RoutineStorage.load();
    } catch (e) {
      debugPrint('Erreur chargement routine: $e');
      error = 'Your products could not be loaded. Check your connection.';
    }

    if (!mounted) return;
    setState(() {
      _products = saved ?? const [];
      _errorMessage = error ??
          (saved == null
              ? 'No products yet. Run a skin analysis to get your routine.'
              : null);
      _isLoading = false;
    });
  }

  List<RoutineProduct> get _filteredProducts => switch (_filter) {
        _Filter.all => _products,
        _Filter.morning => _products.where((p) => p.isMorning).toList(),
        _Filter.night => _products.where((p) => p.isEvening).toList(),
      };

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
          'Recommended Products',
          style: TextStyle(
            color: AppColors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Personalized for You ',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    Text('💜', style: TextStyle(fontSize: 22)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoading && widget.analysis != null
                      ? 'Building a routine for your ${widget.analysis!.skinType.toLowerCase()}...'
                      : 'Products selected for your skin type and concerns.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.greyText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: _LoadingState())
          else if (_errorMessage != null)
            Expanded(child: _buildError())
          else ...[
            const SizedBox(height: 10),
            _buildFilterChips(),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredProducts.length,
                itemBuilder: (context, index) => _buildProductCard(_filteredProducts[index]),
              ),
            ),
            _buildRoutineFooter(),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const labels = {
      _Filter.all: 'All',
      _Filter.morning: 'Morning',
      _Filter.night: 'Night',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: labels.entries.map((entry) {
          final isSelected = _filter == entry.key;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (_) => setState(() => _filter = entry.key),
              selectedColor: AppColors.primaryPurple,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.white : AppColors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: AppColors.softPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProductCard(RoutineProduct product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.softGrey),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.softPurple.withAlpha(50),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(child: ProductImage(product: product, iconSize: 50)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.description,
                  style: const TextStyle(fontSize: 13, color: AppColors.greyText, height: 1.3),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildTag(product.category),
                    _buildTag(product.timeLabel, icon: product.isMorning && product.isEvening
                        ? Icons.brightness_6
                        : (product.isMorning ? Icons.wb_sunny : Icons.nights_stay)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.softPurple,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.primaryPurple),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primaryPurple,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineFooter() {
    final morning = _products.where((p) => p.isMorning).length;
    final night = _products.where((p) => p.isEvening).length;
    // En consultation, la routine est déjà la leur : rien n'a été ajouté à
    // l'instant, et le bouton renverrait vers la page d'où ils viennent.
    final isSaved = widget.analysis == null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.softPurple.withAlpha(100),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _saveFailed ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
            color: AppColors.primaryPurple,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _saveFailed
                  ? 'These products could not be saved to your routine. Check your connection and try again.'
                  : isSaved
                      ? 'Your routine: $morning in the morning, $night at night.'
                      : 'Added to your routine: $morning in the morning, $night at night.',
              style: const TextStyle(fontSize: 12, color: AppColors.darkPurple),
            ),
          ),
          if (!_saveFailed && !isSaved)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RoutinePage()),
              ),
              child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.terracotta, size: 48),
            const SizedBox(height: 15),
            Text(
              _errorMessage ?? 'Unable to build your routine.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.greyText, height: 1.4),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loadRecommendations,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primaryPurple),
          SizedBox(height: 20),
          Text(
            'Choosing products for your concerns',
            style: TextStyle(fontSize: 13, color: AppColors.greyText),
          ),
        ],
      ),
    );
  }
}
