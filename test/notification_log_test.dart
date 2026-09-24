import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/models/app_notification.dart';
import 'package:ziskin/models/routine_product.dart';
import 'package:ziskin/services/notification_log.dart';

void main() {
  const morningOnly = RoutineProduct(
    category: 'Protection',
    name: 'SPF 50',
    description: 'Desc',
    time: RoutineTime.morning,
  );
  const both = RoutineProduct(category: 'Cleanser', name: 'Gel', description: 'Desc');
  const eveningOnly = RoutineProduct(
    category: 'Treatment',
    name: 'Retinol',
    description: 'Desc',
    time: RoutineTime.evening,
  );

  // Wednesday 24 September 2026, noon: the morning reminder has fired, not the evening one
  final noon = DateTime(2026, 9, 24, 12);

  List<AppNotification> due({
    List<RoutineProduct>? routine,
    DateTime? routineSince,
    bool scannedThisMonth = true,
    DateTime? at,
  }) =>
      NotificationLog.dueNotifications(
        routine: routine,
        routineSince: routineSince,
        scannedThisMonth: scannedThisMonth,
        at: at ?? noon,
      );

  Iterable<String> ids(List<AppNotification> notifications) => notifications.map((n) => n.id);

  group('reminders in the bell', () {
    test('no routine and this month scanned: nothing to show', () {
      expect(due(), isEmpty);
      expect(due(routine: const []), isEmpty);
    });

    test('the last seven days are rebuilt, but not reminders still to come', () {
      final notifications = due(routine: const [morningOnly, both, eveningOnly]);
      final morning = notifications.where((n) => n.id.startsWith('routine_morning'));
      final evening = notifications.where((n) => n.id.startsWith('routine_evening'));

      expect(morning, hasLength(7));
      expect(evening, hasLength(6));
      expect(ids(notifications), contains('routine_morning_2026-09-24'));
      expect(ids(notifications), contains('routine_morning_2026-09-18'));
      expect(ids(notifications), isNot(contains('routine_morning_2026-09-17')));
      expect(ids(notifications), isNot(contains('routine_evening_2026-09-24')));
      expect(ids(notifications), contains('routine_evening_2026-09-23'));
    });

    test('reminders fire at 8:00 and 21:00', () {
      final notifications = due(routine: const [both]);

      expect(
        notifications.firstWhere((n) => n.id == 'routine_morning_2026-09-23').date,
        DateTime(2026, 9, 23, 8),
      );
      expect(
        notifications.firstWhere((n) => n.id == 'routine_evening_2026-09-23').date,
        DateTime(2026, 9, 23, 21),
      );
    });

    test('the message counts the products for that moment', () {
      final plural = due(routine: const [morningOnly, both]);
      final singular = due(routine: const [morningOnly]);

      expect(plural.first.body, 'Your morning routine is waiting: 2 products to apply.');
      expect(singular.first.body, 'Your morning routine is waiting: 1 product to apply.');
    });

    test('a morning-only routine never reminds in the evening', () {
      expect(ids(due(routine: const [morningOnly])), everyElement(startsWith('routine_morning')));
    });

    test('nothing is invented before the routine was created', () {
      final notifications = due(
        routine: const [both],
        routineSince: DateTime(2026, 9, 22, 10),
      );

      expect(ids(notifications), unorderedEquals([
        'routine_morning_2026-09-24',
        'routine_morning_2026-09-23',
        'routine_evening_2026-09-23',
        'routine_evening_2026-09-22',
      ]));
    });

    test('the days before the 1st keep their own month', () {
      final notifications = due(routine: const [both], at: DateTime(2026, 10, 2, 22));

      expect(ids(notifications), contains('routine_morning_2026-10-01'));
      expect(ids(notifications), contains('routine_evening_2026-09-30'));
    });
  });

  group('monthly scan reminder', () {
    test('shown on the 1st at 10:00 while the scan is still to do', () {
      final notifications = due(scannedThisMonth: false);

      expect(ids(notifications), ['scan_2026-09']);
      expect(notifications.single.date, DateTime(2026, 9, 1, 10));
    });

    test('not shown once this month is scanned', () {
      expect(due(scannedThisMonth: true), isEmpty);
    });

    test('not shown before 10:00 on the 1st', () {
      expect(due(scannedThisMonth: false, at: DateTime(2026, 10, 1, 9)), isEmpty);
      expect(ids(due(scannedThisMonth: false, at: DateTime(2026, 10, 1, 11))), ['scan_2026-10']);
    });
  });
}
