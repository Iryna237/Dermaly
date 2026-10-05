import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/models/subscription.dart';
import 'package:ziskin/services/notchpay_service.dart';

void main() {
  group('Subscription', () {
    final now = DateTime(2026, 10, 5, 12);

    test('a missing or malformed field gives no subscription', () {
      expect(Subscription.fromMap(null), isNull);
      expect(Subscription.fromMap('active'), isNull);
      expect(Subscription.fromMap({'expiresAt': 'tomorrow'}), isNull);
    });

    test('the expiry survives a round trip through Firestore', () {
      final subscription = Subscription(expiresAt: now);
      expect(Subscription.fromMap(subscription.toJson())!.expiresAt, now);
    });

    test('it is active until its expiry only', () {
      final subscription = Subscription(expiresAt: now);

      expect(Subscription.activeIn(subscription, now.subtract(const Duration(minutes: 1))), isTrue);
      expect(Subscription.activeIn(subscription, now), isFalse);
      expect(Subscription.activeIn(null, now), isFalse);
    });

    test('a first payment gives one month from the payment', () {
      expect(Subscription.renewedExpiry(null, now), now.add(Subscription.period));
    });

    test('paying early extends from the current expiry', () {
      final current = Subscription(expiresAt: now.add(const Duration(days: 10)));

      expect(
        Subscription.renewedExpiry(current, now),
        now.add(const Duration(days: 10)).add(Subscription.period),
      );
    });

    test('paying after expiry restarts from the payment', () {
      final expired = Subscription(expiresAt: now.subtract(const Duration(days: 3)));
      expect(Subscription.renewedExpiry(expired, now), now.add(Subscription.period));
    });
  });

  group('NotchPayService.normalizeCameroonPhone', () {
    test('accepts local and international forms', () {
      expect(NotchPayService.normalizeCameroonPhone('670000000'), '+237670000000');
      expect(NotchPayService.normalizeCameroonPhone('6 70 00 00 00'), '+237670000000');
      expect(NotchPayService.normalizeCameroonPhone('+237 690-000-000'), '+237690000000');
      expect(NotchPayService.normalizeCameroonPhone('00237670000000'), '+237670000000');
    });

    test('rejects numbers that are not Cameroonian mobiles', () {
      expect(NotchPayService.normalizeCameroonPhone(''), isNull);
      expect(NotchPayService.normalizeCameroonPhone('67000000'), isNull);
      expect(NotchPayService.normalizeCameroonPhone('222000000'), isNull);
      expect(NotchPayService.normalizeCameroonPhone('+33612345678'), isNull);
    });
  });

  group('NotchPayment', () {
    test('reads the transaction of a response', () {
      final payment = NotchPayment.fromResponse({
        'code': 202,
        'transaction': {
          'reference': 'trx.123',
          'status': 'complete',
          'amount': 1000,
          'currency': 'xaf',
        },
      })!;

      expect(payment.reference, 'trx.123');
      expect(payment.isComplete, isTrue);
      expect(payment.isFinal, isTrue);
      expect(payment.amount, 1000);
      expect(payment.currency, 'XAF');
    });

    test('a response without a transaction reference is unreadable', () {
      expect(NotchPayment.fromResponse({}), isNull);
      expect(NotchPayment.fromResponse({'transaction': 'trx.123'}), isNull);
      expect(NotchPayment.fromResponse({'transaction': {'status': 'complete'}}), isNull);
    });

    test('only complete, failed, canceled and expired are final', () {
      NotchPayment withStatus(String status) => NotchPayment.fromResponse({
            'transaction': {'reference': 'trx.1', 'status': status},
          })!;

      expect(withStatus('pending').isFinal, isFalse);
      expect(withStatus('processing').isFinal, isFalse);
      expect(withStatus('failed').isFinal, isTrue);
      expect(withStatus('canceled').isFinal, isTrue);
      expect(withStatus('expired').isFinal, isTrue);
      expect(withStatus('failed').isComplete, isFalse);
    });
  });
}
