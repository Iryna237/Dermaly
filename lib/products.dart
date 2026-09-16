import 'package:flutter/material.dart';
import 'app_colors.dart';

class Product {
  final String name;
  final String category;
  final String skinType;
  final List<String> tags;
  final double rating;
  final String imagePath;
  bool isFavorite;

  Product({
    required this.name,
    required this.category,
    required this.skinType,
    required this.tags,
    required this.rating,
    required this.imagePath,
    this.isFavorite = false,
  });
}

class RecommendedProductsPage extends StatefulWidget {
  const RecommendedProductsPage({super.key});

  @override
  State<RecommendedProductsPage> createState() => _RecommendedProductsPageState();
}

class _RecommendedProductsPageState extends State<RecommendedProductsPage> {
  String selectedCategory = 'All';
  final List<String> categories = ['All', 'Cleanser', 'Serum', 'Moisturizer', 'Sunscreen'];

  final List<Product> allProducts = [
    Product(
      name: 'CeraVe Foaming Facial Cleanser',
      category: 'Cleanser',
      skinType: 'For combination & oily skin',
      tags: ['Combination', 'Oil Control'],
      rating: 4.8,
      imagePath: 'assets/images/logo.png', // Placeholder
    ),
    Product(
      name: 'La Roche-Posay Hydrating Cleanser',
      category: 'Cleanser',
      skinType: 'For normal to dry skin',
      tags: ['Dry Skin', 'Gentle'],
      rating: 4.9,
      imagePath: 'assets/images/logo.png', // Placeholder
    ),
    Product(
      name: 'The Ordinary Niacinamide 10%',
      category: 'Serum',
      skinType: 'Helps reduce dark spots & pores',
      tags: ['Blemish Control', 'Brightening'],
      rating: 4.7,
      imagePath: 'assets/images/logo.png', // Placeholder
    ),
    Product(
      name: 'SkinCeuticals C E Ferulic',
      category: 'Serum',
      skinType: 'Advanced antioxidant treatment',
      tags: ['Anti-aging', 'Vitamin C'],
      rating: 4.9,
      imagePath: 'assets/images/logo.png', // Placeholder
    ),
    Product(
      name: 'Neutrogena Hydro Boost Water Gel',
      category: 'Moisturizer',
      skinType: 'Hydrates & balances moisture',
      tags: ['Hydration', 'Lightweight'],
      rating: 4.7,
      imagePath: 'assets/images/logo.png', // Placeholder
    ),
    Product(
      name: 'Kiehl\'s Ultra Facial Cream',
      category: 'Moisturizer',
      skinType: '24-hour daily moisturizer',
      tags: ['All Skin Types', 'Nourishing'],
      rating: 4.8,
      imagePath: 'assets/images/logo.png', // Placeholder
    ),
    Product(
      name: 'EltaMD UV Clear SPF 46',
      category: 'Sunscreen',
      skinType: 'Protects from UV & calms acne',
      tags: ['Acne-prone', 'SPF 46'],
      rating: 4.9,
      imagePath: 'assets/images/logo.png', // Placeholder
    ),
    Product(
      name: 'La Roche-Posay Anthelios SPF 60',
      category: 'Sunscreen',
      skinType: 'Broad spectrum protection',
      tags: ['SPF 60', 'Water Resistant'],
      rating: 4.8,
      imagePath: 'assets/images/logo.png', // Placeholder
    ),
  ];

  List<Product> get filteredProducts {
    if (selectedCategory == 'All') return allProducts;
    return allProducts.where((p) => p.category == selectedCategory).toList();
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
                    Text(
                      '💜',
                      style: TextStyle(fontSize: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Products selected for your skin type and concerns.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.greyText,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: categories.map((cat) {
                final isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        selectedCategory = cat;
                      });
                    },
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
          ),
          const SizedBox(height: 15),
          // Product List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return _buildProductCard(product);
              },
            ),
          ),
          // Info Box
          _buildInfoFooter(),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
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
          // Product Image
          Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.softPurple.withAlpha(50),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Image.asset(
                product.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.medication_outlined,
                  size: 50,
                  color: AppColors.primaryPurple,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        product.isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: product.isFavorite ? AppColors.brandPink : AppColors.greyText,
                      ),
                      onPressed: () {
                        setState(() {
                          product.isFavorite = !product.isFavorite;
                        });
                      },
                    ),
                  ],
                ),
                Text(
                  product.skinType,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.greyText,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: product.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.softPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orangeAccent, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          product.rating.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'View Details',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoFooter() {
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
          Icon(Icons.info, color: AppColors.primaryPurple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'These products are suitable for all skin tones.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.darkPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
