import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Point rouge pose sur une icone : la cloche s'en sert pour les notifications
/// non lues, l'onglet Chat pour les messages qui attendent une reponse.
///
/// Le meme signe pour la meme chose : ce qui est marque ici n'a pas ete lu.
Widget unreadDot(Widget icon, {required bool show}) {
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      icon,
      if (show)
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ),
    ],
  );
}

/// Nombre de messages non lus d'une conversation.
///
/// Le point dit qu'il reste quelque chose a lire, la pastille dit combien :
/// dans une liste de conversations, la difference entre un message et dix
/// change l'ordre dans lequel on les ouvre.
class UnreadCount extends StatelessWidget {
  final int count;

  const UnreadCount({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      constraints: const BoxConstraints(minWidth: 22),
      decoration: BoxDecoration(
        color: AppColors.terracotta,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
