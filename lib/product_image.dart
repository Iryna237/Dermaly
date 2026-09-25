import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'models/routine_product.dart';

/// Visuel d'un produit de routine, avec trois niveaux de repli.
///
/// La photo réelle si une base ouverte en possède une, sinon l'illustration de
/// la catégorie, sinon l'icône de la catégorie. Une carte n'est donc jamais vide,
/// même hors ligne ou si l'image distante disparaît.
class ProductImage extends StatelessWidget {
  final RoutineProduct product;
  final double iconSize;

  const ProductImage({super.key, required this.product, this.iconSize = 40});

  @override
  Widget build(BuildContext context) {
    final url = product.imageUrl;
    if (url == null || url.isEmpty) return _categoryImage();

    return Image.network(
      url,
      fit: BoxFit.contain,
      // Photo indisponible ou lien mort : on retombe sur la catégorie
      errorBuilder: (context, error, stackTrace) => _categoryImage(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _categoryImage(),
    );
  }

  Widget _categoryImage() {
    return Image.asset(
      product.imagePath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        product.icon,
        size: iconSize,
        color: AppColors.primaryPurple,
      ),
    );
  }
}
