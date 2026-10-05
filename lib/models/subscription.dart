/// Abonnement mensuel qui ouvre l'accès aux dermatologues : demandes de
/// consultation et discussion.
///
/// Stocké dans le champ `subscription` du document `users/{uid}`. Seule
/// l'échéance compte : l'abonnement est actif tant qu'elle n'est pas passée.
class Subscription {
  /// Prix d'un mois d'abonnement, en francs CFA
  static const int price = 1000;
  static const String currency = 'XAF';
  static const Duration period = Duration(days: 30);

  final DateTime expiresAt;

  const Subscription({required this.expiresAt});

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt);
  bool get isActive => isActiveAt(DateTime.now());

  /// Échéance après un paiement reçu à [paidAt]. Un abonnement encore actif
  /// est prolongé depuis son échéance : payer en avance ne fait perdre aucun jour.
  static DateTime renewedExpiry(Subscription? current, DateTime paidAt) {
    final start =
        current != null && current.isActiveAt(paidAt) ? current.expiresAt : paidAt;
    return start.add(period);
  }

  Map<String, dynamic> toJson() => {
        'expiresAt': expiresAt.millisecondsSinceEpoch,
      };

  /// Reconstruit l'abonnement depuis Firestore, ou null s'il n'y en a jamais eu
  static Subscription? fromMap(Object? raw) {
    if (raw is! Map) return null;

    final expiresAt = raw['expiresAt'];
    if (expiresAt is! int) return null;

    return Subscription(expiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt));
  }

  /// Abonnement actif à cette date, absent ou expiré
  static bool activeIn(Subscription? subscription, [DateTime? now]) =>
      subscription != null && subscription.isActiveAt(now ?? DateTime.now());
}
