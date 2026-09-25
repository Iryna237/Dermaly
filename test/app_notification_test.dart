import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/models/app_notification.dart';

void main() {
  group('AppNotification', () {
    AppNotification withId(String id) =>
        AppNotification(id: id, title: 'Title', body: 'Body', date: DateTime(2026, 9, 21));

    test('a missing document gives no notification', () {
      expect(AppNotification.fromDoc('scan_2026-09', null), isNull);
    });

    test('a notification without a usable date is ignored', () {
      expect(AppNotification.fromDoc('scan_2026-09', {'title': 'Scan'}), isNull);
      expect(AppNotification.fromDoc('scan_2026-09', {'date': '2026-09-01'}), isNull);
    });

    test('missing texts are empty and it starts unread', () {
      final notification = AppNotification.fromDoc('scan_2026-09', {'date': 0})!;

      expect(notification.title, '');
      expect(notification.body, '');
      expect(notification.read, isFalse);
    });

    test('only a real true marks it as read', () {
      AppNotification readAs(Object? read) =>
          AppNotification.fromDoc('scan_2026-09', {'date': 0, 'read': read})!;

      expect(readAs(true).read, isTrue);
      expect(readAs('true').read, isFalse);
      expect(readAs(1).read, isFalse);
    });

    test('the kind is read from the id', () {
      final morning = withId('routine_morning_2026-09-21');
      final evening = withId('routine_evening_2026-09-21');
      final scan = withId('scan_2026-09');
      final message = withId('message_chat-1_42');
      final request = withId('request_patient-1_derma-1');

      expect(morning.isMorning, isTrue);
      expect(evening.isMorning, isFalse);
      expect(scan.isScan, isTrue);
      expect(message.isMessage, isTrue);
      expect(request.isRequest, isTrue);
      expect([morning.isScan, morning.isMessage, morning.isRequest], [false, false, false]);
    });

    test('a saved notification reads back the same', () {
      final original = AppNotification(
        id: 'routine_evening_2026-09-21',
        title: 'Evening routine',
        body: 'Time for your evening routine: 2 products to apply.',
        date: DateTime(2026, 9, 21, 21),
        read: true,
      );

      final copy = AppNotification.fromDoc(original.id, original.toJson())!;

      expect(copy.id, original.id);
      expect(copy.title, original.title);
      expect(copy.body, original.body);
      expect(copy.date, original.date);
      expect(copy.read, isTrue);
    });
  });
}
