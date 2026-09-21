import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/routine_product.dart';
import 'routine_storage.dart';
import 'skin_progress_storage.dart';

/// Rappels locaux de l'application :
/// - routine : un rappel le matin et un le soir, tous les jours, tant que
///   l'utilisateur a une routine enregistrée ;
/// - Skin Progress : un rappel le 1er du mois, jour où le scan mensuel se
///   débloque, sauf si le scan du mois est déjà fait.
///
/// Tout est programmé en local, sans serveur : rien n'est envoyé si l'app n'est
/// jamais ouverte, mais les rappels sont reprogrammés à chaque ouverture.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Identifiants fixes : reprogrammer avec le même id remplace le rappel
  /// précédent au lieu d'en empiler un deuxième.
  static const int _morningId = 1001;
  static const int _eveningId = 1002;
  static const int _monthlyScanId = 2001;

  static const AndroidNotificationDetails _routineChannel = AndroidNotificationDetails(
    'routine_reminders',
    'Routine reminders',
    channelDescription: 'Morning and evening reminders to apply your products',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const AndroidNotificationDetails _scanChannel = AndroidNotificationDetails(
    'scan_reminders',
    'Monthly scan reminders',
    channelDescription: 'Reminder when your monthly skin scan is due',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  /// Heures des rappels de routine
  static const int morningHour = 8;
  static const int eveningHour = 21;

  /// Heure du rappel de scan mensuel, le 1er du mois
  static const int scanHour = 10;

  static bool _initialised = false;

  /// Prépare le plugin et demande l'autorisation d'afficher des notifications.
  /// Sans réponse positive, les programmations suivantes ne feront rien de visible.
  static Future<void> init() async {
    if (_initialised) return;

    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(await _deviceTimeZone()));
    } catch (e) {
      // Fuseau inconnu : on reste sur UTC plutôt que de renoncer aux rappels
      debugPrint('Fuseau horaire non résolu, UTC utilisé: $e');
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    _initialised = true;
  }

  static Future<String> _deviceTimeZone() async {
    // La zone locale de Dart suffit : on ne veut que l'heure locale de l'appareil
    final offset = DateTime.now().timeZoneOffset;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.currentTimeZone.offset == offset) {
        return location.name;
      }
    }
    return 'UTC';
  }

  /// Reprogramme les deux familles de rappels d'après l'état de l'utilisateur.
  /// Appelée à l'ouverture de l'app, après un scan et après une recommandation.
  static Future<void> refreshSchedules() async {
    try {
      await init();
      await _refreshRoutineReminders();
      await _refreshMonthlyScanReminder();
    } catch (e) {
      // Un rappel manquant ne doit jamais empêcher l'app de fonctionner
      debugPrint('Erreur programmation des rappels: $e');
    }
  }

  /// Rappels de routine : seulement si l'utilisateur a des produits à appliquer.
  static Future<void> _refreshRoutineReminders() async {
    List<RoutineProduct>? routine;
    try {
      routine = await RoutineStorage.load();
    } catch (e) {
      debugPrint('Erreur chargement routine pour les rappels: $e');
      return;
    }

    final morning = routine?.where((p) => p.isMorning).length ?? 0;
    final evening = routine?.where((p) => p.isEvening).length ?? 0;

    // Pas de routine : ne pas rappeler d'appliquer des produits qui n'existent pas
    if (morning == 0) {
      await _plugin.cancel(id: _morningId);
    } else {
      await _scheduleDaily(
        id: _morningId,
        hour: morningHour,
        title: 'Good morning ☀️',
        body: morning == 1
            ? 'Your morning routine is waiting: 1 product to apply.'
            : 'Your morning routine is waiting: $morning products to apply.',
      );
    }

    if (evening == 0) {
      await _plugin.cancel(id: _eveningId);
    } else {
      await _scheduleDaily(
        id: _eveningId,
        hour: eveningHour,
        title: 'Evening routine 🌙',
        body: evening == 1
            ? 'Time for your evening routine: 1 product to apply.'
            : 'Time for your evening routine: $evening products to apply.',
      );
    }
  }

  /// Rappel du scan mensuel, le 1er du prochain mois où le scan reste à faire.
  static Future<void> _refreshMonthlyScanReminder() async {
    final now = DateTime.now();
    bool scannedThisMonth = false;
    try {
      final history = await SkinProgressStorage.loadHistory();
      scannedThisMonth = history.isNotEmpty &&
          SkinProgressStorage.monthKey(history.last.analyzedAt!) ==
              SkinProgressStorage.monthKey(now);
    } catch (e) {
      debugPrint('Erreur chargement historique pour le rappel de scan: $e');
      return;
    }

    final firstOfNextMonth = DateTime(now.year, now.month + 1, 1, scanHour);

    final DateTime when;
    if (scannedThisMonth) {
      // Scan du mois fait : le prochain se débloque le 1er du mois suivant
      when = firstOfNextMonth;
    } else {
      // Scan encore à faire : rappeler aujourd'hui s'il reste du temps, sinon
      // demain, plutôt que de sauter un mois entier
      final today = DateTime(now.year, now.month, now.day, scanHour);
      final tomorrow = today.add(const Duration(days: 1));
      when = today.isAfter(now)
          ? today
          : (tomorrow.month == now.month ? tomorrow : firstOfNextMonth);
    }

    await _scheduleAt(
      id: _monthlyScanId,
      when: when,
      title: 'Your monthly skin scan is ready 📸',
      body: 'Take this month\'s scan to see how your skin has changed.',
      details: _scanChannel,
    );
  }

  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: _routineChannel,
        iOS: DarwinNotificationDetails(),
      ),
      // Rappel d'hygiène : quelques minutes de décalage sont sans importance, et
      // l'alarme inexacte évite de demander une permission d'alarme exacte
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Répète tous les jours à la même heure
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> _scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required AndroidNotificationDetails details,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      notificationDetails: NotificationDetails(
        android: details,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}

