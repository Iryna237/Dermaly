import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'unread_badge.dart';

/// Barre de navigation du patient : une pilule flottante, avec le scan au
/// centre en bouton rond qui dépasse.
///
/// Le scan est la raison d'ouvrir l'app, il doit se trouver sans chercher.
/// Le bouton reste dans la hauteur de la barre : la page au-dessus n'est jamais
/// recouverte, et le déclencheur de la page Scan reste entièrement visible.
class ClientNavBar extends StatelessWidget {
  static const int scanIndex = 2;

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool unreadChat;

  const ClientNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.unreadChat = false,
  });

  static const double _pillHeight = 66;
  static const double _scanSize = 64;
  // Ce qui dépasse de la pilule.
  static const double _scanRise = 24;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: SizedBox(
          height: _pillHeight + _scanRise,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _pillHeight,
                child: _pill(),
              ),
              _scanButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(_pillHeight / 2),
        border: Border.all(color: AppColors.softPink),
        boxShadow: [
          BoxShadow(
            color: AppColors.terracotta.withAlpha(31), // 0.12 * 255
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _item(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
          _item(1, Icons.insights_outlined, Icons.insights_rounded, 'Progress'),
          Expanded(child: _scanLabel()),
          _item(3, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat',
              dot: unreadChat),
          _item(4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
        ],
      ),
    );
  }

  Widget _item(int index, IconData icon, IconData activeIcon, String label, {bool dot = false}) {
    final selected = index == currentIndex;
    final color = selected ? AppColors.terracotta : AppColors.greyText;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: () => onTap(index),
          radius: 32,
          highlightColor: AppColors.softPink,
          splashColor: AppColors.softPink,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.softPink : AppColors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: unreadDot(
                  Icon(selected ? activeIcon : icon, color: color, size: 24),
                  show: dot,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Libellé posé sous le bouton rond, à la hauteur de ceux des autres onglets.
  Widget _scanLabel() {
    final selected = currentIndex == scanIndex;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Scan',
          style: TextStyle(
            color: selected ? AppColors.terracotta : AppColors.greyText,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _scanButton() {
    final selected = currentIndex == scanIndex;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Scan',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onTap(scanIndex),
        child: AnimatedScale(
          scale: selected ? 1.06 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Container(
            width: _scanSize,
            height: _scanSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.brandPink, AppColors.terracotta],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.terracotta.withAlpha(selected ? 115 : 77), // 0.45 / 0.3
                  blurRadius: selected ? 18 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.photo_camera_rounded, color: AppColors.white, size: 28),
          ),
        ),
      ),
    );
  }
}
