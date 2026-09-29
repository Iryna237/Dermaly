import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'unread_badge.dart';

/// Un onglet de [PillNavBar].
class NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Point rouge : il reste quelque chose à lire derrière cet onglet.
  final bool dot;

  const NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.dot = false,
  });
}

/// Barre de navigation en pilule flottante, avec l'onglet du milieu en bouton
/// rond qui dépasse.
///
/// Le patient y met le scan, le dermatologue les demandes : l'action pour
/// laquelle on ouvre l'app se trouve sans chercher. Le bouton reste dans la
/// hauteur de la barre : la page au-dessus n'est jamais recouverte, et le
/// déclencheur de la page Scan reste entièrement visible.
class PillNavBar extends StatelessWidget {
  /// Nombre impair d'onglets : celui du milieu devient le bouton rond.
  final List<NavTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Couleur de l'onglet actif.
  final Color accent;

  /// Fond de la pastille derrière l'icône active, et bord de la pilule.
  final Color accentSoft;

  /// Dégradé du bouton rond.
  final List<Color> centerGradient;

  const PillNavBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    required this.accent,
    required this.accentSoft,
    required this.centerGradient,
  }) : assert(tabs.length % 2 == 1);

  static const double _pillHeight = 66;
  static const double _centerSize = 64;
  // Ce qui dépasse de la pilule.
  static const double _centerRise = 24;

  int get _centerIndex => tabs.length ~/ 2;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: SizedBox(
          height: _pillHeight + _centerRise,
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
              _centerButton(),
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
        border: Border.all(color: accentSoft),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(31), // 0.12 * 255
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(child: i == _centerIndex ? _centerLabel() : _item(i)),
        ],
      ),
    );
  }

  Widget _item(int index) {
    final tab = tabs[index];
    final selected = index == currentIndex;
    final color = selected ? accent : AppColors.greyText;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () => onTap(index),
        radius: 32,
        highlightColor: accentSoft,
        splashColor: accentSoft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? accentSoft : AppColors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: unreadDot(
                Icon(selected ? tab.activeIcon : tab.icon, color: color, size: 24),
                show: tab.dot,
              ),
            ),
            const SizedBox(height: 3),
            _label(tab.label, selected),
          ],
        ),
      ),
    );
  }

  /// Libellé posé sous le bouton rond, à la hauteur de ceux des autres onglets.
  Widget _centerLabel() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _label(tabs[_centerIndex].label, currentIndex == _centerIndex),
      ),
    );
  }

  Widget _label(String text, bool selected) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: TextStyle(
        color: selected ? accent : AppColors.greyText,
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  Widget _centerButton() {
    final tab = tabs[_centerIndex];
    final selected = currentIndex == _centerIndex;

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onTap(_centerIndex),
        child: AnimatedScale(
          scale: selected ? 1.06 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Container(
            width: _centerSize,
            height: _centerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: centerGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: accent.withAlpha(selected ? 115 : 77), // 0.45 / 0.3
                  blurRadius: selected ? 18 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: unreadDot(
              Icon(tab.activeIcon, color: AppColors.white, size: 28),
              show: tab.dot,
            ),
          ),
        ),
      ),
    );
  }
}
