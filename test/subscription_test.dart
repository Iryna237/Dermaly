import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/models/subscription.dart';
import 'package:ziskin/services/notchpay_service.dart';
import 'package:ziskin/services/subscription_service.dart';

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

  group('NotchPayService.operatorOf', () {
    test('recognises MTN and Orange prefixes', () {
      expect(NotchPayService.operatorOf('+237670000000'), MobileMoneyChannel.mtn);
      expect(NotchPayService.operatorOf('+237680000000'), MobileMoneyChannel.mtn);
      expect(NotchPayService.operatorOf('+237650000000'), MobileMoneyChannel.mtn);
      expect(NotchPayService.operatorOf('+237654000000'), MobileMoneyChannel.mtn);
      expect(NotchPayService.operatorOf('+237690000000'), MobileMoneyChannel.orange);
      expect(NotchPayService.operatorOf('+237655000000'), MobileMoneyChannel.orange);
      expect(NotchPayService.operatorOf('+237659000000'), MobileMoneyChannel.orange);
    });

    test('other prefixes have no Mobile Money operator', () {
      expect(NotchPayService.operatorOf('+237600000000'), isNull);
      expect(NotchPayService.operatorOf('+237612345678'), isNull);
      expect(NotchPayService.operatorOf('+237660000000'), isNull);
      expect(NotchPayService.operatorOf('670000000'), isNull);
    });
  });

  group('NotchPayService.phoneError', () {
    test('accepts a number of the chosen operator', () {
      expect(NotchPayService.phoneError('6 70 00 00 00', MobileMoneyChannel.mtn), isNull);
      expect(NotchPayService.phoneError('+237 690 000 000', MobileMoneyChannel.orange), isNull);
    });

    test('rejects malformed numbers before any request', () {
      expect(NotchPayService.phoneError('', MobileMoneyChannel.mtn), isNotNull);
      expect(NotchPayService.phoneError('67000000', MobileMoneyChannel.mtn), isNotNull);
      expect(NotchPayService.phoneError('222000000', MobileMoneyChannel.mtn), isNotNull);
    });

    test('rejects numbers no Mobile Money operator serves', () {
      expect(NotchPayService.phoneError('612345678', MobileMoneyChannel.mtn), contains('not an MTN or Orange'));
      expect(NotchPayService.phoneError('660000000', MobileMoneyChannel.orange), contains('not an MTN or Orange'));
    });

    test('rejects a number of the other operator', () {
      expect(NotchPayService.phoneError('690000000', MobileMoneyChannel.mtn), contains('Orange Money number'));
      expect(NotchPayService.phoneError('670000000', MobileMoneyChannel.orange), contains('MTN Mobile Money number'));
    });
  });

  group('SubscriptionService.rejectionReason', () {
    NotchPayment paid({
      String status = 'complete',
      num amount = 1000,
      String currency = 'XAF',
      String merchant = 'dermaly-uid-1',
      bool sandbox = false,
    }) =>
        NotchPayment(
          reference: 'trx.1',
          status: status,
          amount: amount,
          currency: currency,
          merchantReference: merchant,
          sandbox: sandbox,
        );

    const pending = {'status': 'pending', 'merchantReference': 'dermaly-uid-1'};

    test('a complete transaction matching the recorded payment is accepted', () {
      expect(SubscriptionService.rejectionReason(paid(), pending, testKey: false), isNull);
    });

    test('a transaction that is not complete is refused', () {
      expect(SubscriptionService.rejectionReason(paid(status: 'pending'), pending, testKey: false), isNotNull);
      expect(SubscriptionService.rejectionReason(paid(status: 'failed'), pending, testKey: false), isNotNull);
    });

    test('a payment the app did not record, or already settled, is refused', () {
      expect(SubscriptionService.rejectionReason(paid(), null, testKey: false), isNotNull);
      expect(
        SubscriptionService.rejectionReason(paid(), {...pending, 'status': 'complete'}, testKey: false),
        isNotNull,
      );
    });

    test('another transaction, or one recorded without its reference, is refused', () {
      expect(SubscriptionService.rejectionReason(paid(merchant: 'dermaly-uid-2'), pending, testKey: false), isNotNull);
      expect(SubscriptionService.rejectionReason(paid(), {'status': 'pending'}, testKey: false), isNotNull);
    });

    test('a different amount or currency is refused', () {
      expect(SubscriptionService.rejectionReason(paid(amount: 100), pending, testKey: false), isNotNull);
      expect(SubscriptionService.rejectionReason(paid(amount: 5000), pending, testKey: false), isNotNull);
      expect(SubscriptionService.rejectionReason(paid(currency: 'EUR'), pending, testKey: false), isNotNull);
    });

    test('a sandbox transaction only counts with a test key', () {
      expect(SubscriptionService.rejectionReason(paid(sandbox: true), pending, testKey: true), isNull);
      expect(SubscriptionService.rejectionReason(paid(sandbox: true), pending, testKey: false), isNotNull);
    });
  });

  group('NotchPayment', () {
    test('reads the merchant reference and the sandbox flag', () {
      final payment = NotchPayment.fromResponse({
        'transaction': {
          'reference': 'trx.test_1',
          'merchant_reference': 'dermaly-uid-1',
          'sandbox': true,
          'status': 'complete',
        },
      })!;

      expect(payment.merchantReference, 'dermaly-uid-1');
      expect(payment.sandbox, isTrue);
    });

    test('the sandbox flag is read whether Notch Pay sends 1 or a boolean', () {
      bool sandboxOf(Object? flag) => NotchPayment.fromResponse({
            'transaction': {'reference': 'trx.1', 'sandbox': flag},
          })!
              .sandbox;

      expect(sandboxOf(1), isTrue);
      expect(sandboxOf('1'), isTrue);
      expect(sandboxOf(true), isTrue);
      expect(sandboxOf(0), isFalse);
      expect(sandboxOf(false), isFalse);
      expect(sandboxOf(null), isFalse);
    });

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
