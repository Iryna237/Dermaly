import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/routine_product.dart';
import 'notification_service.dart';
import 'skin_analysis_storage.dart';

/// Historique des rappels envoyés, consultable via la cloche de l'accueil.
///
/// Un rappel local est affiché par le système, pas par l'application : il n'y a
/// donc aucun moment où l'app pourrait l'enregistrer au vol. Le journal est
/// reconstitué à l'ouverture, à partir des rappels programmés dont l'heure est
/// passée. Les identifiants déterministes évitent les doublons.
class NotificationLog {
  static const String _collectionName = 'notifications';

  /// Fenêtre de reconstitution : au-delà, un rappel manqué n'a plus d'intérêt
  static const int _historyDays = 7;

  static CollectionReference<Map<String, dynamic>>? _collection() {
    return SkinAnalysisStorage.userDoc()?.collection(_collectionName);
  }

  /// Notifications de l'utilisateur, de la plus récente à la plus ancienne
  static Stream<List<AppNotification>> watch() {
    final collection = _collection();
    if (collection == null) return Stream.value(const []);

    return collection
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => [
              for (final doc in snapshot.docs)
                ?AppNotification.fromDoc(doc.id, doc.data()),
            ]);
  }

  /// Marque tout comme lu : c'est ce qui fait disparaître le point sur la cloche
  static Future<void> markAllRead() async {
    final collection = _collection();
    if (collection == null) return;

    final unread = await collection.where('read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await SkinAnalysisStorage.writeWithTimeout(batch.commit());
  }

  /// Ajoute [notification] si son identifiant est inconnu.
  ///
  /// Retourne vrai uniquement quand l'entrée vient d'être créée : l'appelant
  /// s'en sert pour n'afficher la bannière qu'une fois, même après redémarrage
  /// de l'application.
  static Future<bool> addIfMissing(AppNotification notification) async {
    final collection = _collection();
    if (collection == null) return false;

    try {
      final doc = collection.doc(notification.id);
      if ((await doc.get()).exists) return false;

      await SkinAnalysisStorage.writeWithTimeout(doc.set(notification.toJson()));
      return true;
    } catch (e) {
      debugPrint('Erreur journalisation de la notification: $e');
      return false;
    }
  }

  /// Journalise les rappels dont l'heure est passée et qui manquent encore.
  ///
  /// [routine] et [routineSince] décrivent la routine enregistrée : aucun rappel
  /// n'est inventé pour les jours antérieurs à sa création.
  static Future<void> syncDue({
    required List<RoutineProduct>? routine,
    required DateTime? routineSince,
    required bool scannedThisMonth,
  }) async {
    final collection = _collection();
    if (collection == null) return;

    final due = _dueNotifications(
      routine: routine,
      routineSince: routineSince,
      scannedThisMonth: scannedThisMonth,
    );
    if (due.isEmpty) return;

    try {
      // Les identifiants déjà présents ne sont pas réécrits : leur état « lu »
      // doit survivre à chaque ouverture
      final existing = await collection.orderBy('date', descending: true).limit(60).get();
      final known = {for (final doc in existing.docs) doc.id};

      final missing = due.where((n) => !known.contains(n.id)).toList();
      if (missing.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final notification in missing) {
        batch.set(collection.doc(notification.id), notification.toJson());
      }
      await SkinAnalysisStorage.writeWithTimeout(batch.commit());
    } catch (e) {
      debugPrint('Erreur journalisation des notifications: $e');
    }
  }

  /// Rappels qui auraient dû s'afficher depuis [_historyDays] jours.
  static List<AppNotification> _dueNotifications({
    required List<RoutineProduct>? routine,
    required DateTime? routineSince,
    required bool scannedThisMonth,
  }) {
    final now = DateTime.now();
    final due = <AppNotification>[];

    final morningCount = routine?.where((p) => p.isMorning).length ?? 0;
    final eveningCount = routine?.where((p) => p.isEvening).length ?? 0;

    for (var day = 0; day < _historyDays; day++) {
      final date = now.subtract(Duration(days: day));

      void addIfDue(String prefix, int hour, int count, String title, String body) {
        if (count == 0) return;

        final slot = DateTime(date.year, date.month, date.day, hour);
        // Rappel encore à venir, ou antérieur à la création de la routine
        if (slot.isAfter(now)) return;
        if (routineSince != null && slot.isBefore(routineSince)) return;

        due.add(AppNotification(
          id: '${prefix}_${_dayKey(slot)}',
          title: title,
          body: body,
          date: slot,
        ));
      }

      addIfDue(
        'routine_morning',
        NotificationService.morningHour,
        morningCount,
        'Good morning ☀️',
        morningCount == 1
            ? 'Your morning routine is waiting: 1 product to apply.'
            : 'Your morning routine is waiting: $morningCount products to apply.',
      );
      addIfDue(
        'routine_evening',
        NotificationService.eveningHour,
        eveningCount,
        'Evening routine 🌙',
        eveningCount == 1
            ? 'Time for your evening routine: 1 product to apply.'
            : 'Time for your evening routine: $eveningCount products to apply.',
      );
    }

    // Rappel du scan mensuel : seulement si le scan du mois reste à faire
    final scanSlot = DateTime(now.year, now.month, 1, NotificationService.scanHour);
    if (!scannedThisMonth && !scanSlot.isAfter(now)) {
      due.add(AppNotification(
        id: 'scan_${_monthKey(scanSlot)}',
        title: 'Your monthly skin scan is ready 📸',
        body: 'Take this month\'s scan to see how your skin has changed.',
        date: scanSlot,
      ));
    }

    return due;
  }

  static String _dayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
}
