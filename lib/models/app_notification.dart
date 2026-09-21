/// Notification affichée dans le centre de notifications (la cloche de l'accueil).
///
/// L'identifiant est déterministe (`routine_morning_2026-09-21`, `scan_2026-09`)
/// pour qu'un même rappel ne soit jamais journalisé deux fois, quel que soit le
/// nombre d'ouvertures de l'application.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime date;
  final bool read;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.read = false,
  });

  /// Vrai pour un rappel de scan mensuel, faux pour un rappel de routine
  bool get isScan => id.startsWith('scan_');

  /// Vrai pour un rappel du matin (sert à choisir l'icône)
  bool get isMorning => id.startsWith('routine_morning');

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'date': date.millisecondsSinceEpoch,
        'read': read,
      };

  /// Reconstruit une notification depuis Firestore, ou null si le document
  /// n'a pas de date exploitable : sans date, impossible de l'ordonner.
  static AppNotification? fromDoc(String id, Map<String, dynamic>? data) {
    if (data == null) return null;

    final date = data['date'];
    if (date is! int) return null;

    return AppNotification(
      id: id,
      title: (data['title'] as Object?)?.toString() ?? '',
      body: (data['body'] as Object?)?.toString() ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(date),
      read: data['read'] == true,
    );
  }
}
