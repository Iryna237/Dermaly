import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/subscription.dart';
import 'notchpay_service.dart';
import 'skin_analysis_storage.dart';

/// Abonnement du patient connecté et paiements qui le prolongent.
///
/// L'abonnement est le champ `subscription` de `users/{uid}`. Chaque paiement
/// est suivi dans `users/{uid}/payments/{référence Notch Pay}` : un paiement
/// déjà compté ne prolonge pas l'abonnement une seconde fois, et un paiement
/// confirmé après la fermeture de l'app est rattrapé par [resumePending].
class SubscriptionService {
  static const String _field = 'subscription';

  /// Durée pendant laquelle l'app attend que le patient valide sur son téléphone
  static const Duration confirmationTimeout = Duration(minutes: 3);
  static const Duration _pollInterval = Duration(seconds: 5);

  static CollectionReference<Map<String, dynamic>>? _payments() =>
      SkinAnalysisStorage.userDoc()?.collection('payments');

  /// Abonnement du patient connecté, ou du patient [uid] côté dermatologue.
  /// Null s'il n'en a jamais pris.
  static Stream<Subscription?> watch([String? uid]) {
    final doc = uid == null
        ? SkinAnalysisStorage.userDoc()
        : FirebaseFirestore.instance.collection('users').doc(uid);
    if (doc == null) return Stream.value(null);

    return doc.snapshots().map((snapshot) => Subscription.fromMap(snapshot.data()?[_field]));
  }

  static Future<bool> isActive() async {
    final doc = SkinAnalysisStorage.userDoc();
    if (doc == null) return false;

    final snapshot = await doc.get();
    return Subscription.activeIn(Subscription.fromMap(snapshot.data()?[_field]));
  }

  /// Crée le paiement d'un mois et l'envoie sur le téléphone du patient.
  /// Retourne la référence Notch Pay à suivre avec [waitForResult].
  ///
  /// Le numéro est vérifié avant tout appel à Notch Pay : un numéro invalide
  /// ou d'un autre opérateur ne crée aucune transaction.
  static Future<String> startPayment({
    required MobileMoneyChannel channel,
    required String phone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final payments = _payments();
    if (user == null || payments == null) {
      throw Exception('Please sign in to subscribe.');
    }

    final phoneError = NotchPayService.phoneError(phone, channel);
    if (phoneError != null) throw Exception(phoneError);
    final normalizedPhone = NotchPayService.normalizeCameroonPhone(phone)!;

    final merchantReference = 'dermaly-${user.uid}-${DateTime.now().millisecondsSinceEpoch}';
    final payment = await NotchPayService.initialize(
      amount: Subscription.price,
      currency: Subscription.currency,
      phone: normalizedPhone,
      email: user.email,
      name: user.displayName,
      reference: merchantReference,
      description: 'Dermaly - 1 month of dermatologist access',
    );

    // Gardé avant le débit : si l'app se ferme pendant la confirmation, le
    // paiement sera retrouvé et vérifié à la prochaine ouverture. La référence
    // marchande permettra de vérifier que la transaction est bien celle-ci.
    final paymentDoc = payments.doc(payment.reference);
    await SkinAnalysisStorage.writeWithTimeout(paymentDoc.set({
      'status': 'pending',
      'amount': Subscription.price,
      'currency': Subscription.currency,
      'channel': channel.code,
      'merchantReference': merchantReference,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }));

    try {
      await NotchPayService.charge(
        reference: payment.reference,
        channel: channel,
        phone: normalizedPhone,
      );
    } catch (_) {
      // Demande refusée par Notch Pay : ce paiement ne pourra jamais aboutir
      await SkinAnalysisStorage.writeWithTimeout(paymentDoc.update({
        'status': 'failed',
        'settledAt': DateTime.now().millisecondsSinceEpoch,
      }));
      rethrow;
    }
    return payment.reference;
  }

  /// Suit le paiement jusqu'à son issue, ou jusqu'à [confirmationTimeout].
  /// L'abonnement n'est prolongé que si Notch Pay confirme le paiement et que
  /// la transaction correspond à celle enregistrée ([settle]).
  static Future<PaymentOutcome> waitForResult(String reference) async {
    final deadline = DateTime.now().add(confirmationTimeout);

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollInterval);

      final NotchPayment payment;
      try {
        payment = await NotchPayService.retrieve(reference);
      } on NotchPayException catch (e) {
        // Coupure réseau passagère : le paiement continue côté Notch Pay
        debugPrint('Suivi du paiement $reference : $e');
        continue;
      }

      if (payment.isFinal) return settle(payment);
    }

    return PaymentOutcome.pending;
  }

  /// Raison de refuser une transaction que Notch Pay dit payée, ou null si
  /// elle correspond au paiement enregistré : même référence marchande, prix
  /// exact de l'abonnement, et vraie transaction quand la clé est réelle.
  static String? rejectionReason(
    NotchPayment payment,
    Map<String, dynamic>? recorded, {
    required bool testKey,
  }) {
    if (!payment.isComplete) return 'not complete';
    if (recorded == null) return 'unknown payment';
    if (recorded['status'] != 'pending') return 'already settled';

    final expected = recorded['merchantReference'];
    if (expected is! String || expected.isEmpty || payment.merchantReference != expected) {
      return 'merchant reference mismatch';
    }
    if (payment.amount != Subscription.price || payment.currency != Subscription.currency) {
      return 'wrong amount';
    }
    if (payment.sandbox && !testKey) return 'sandbox transaction with a live key';
    return null;
  }

  /// Enregistre l'issue d'un paiement définitif. Seul un paiement vérifié par
  /// [rejectionReason] prolonge l'abonnement d'un mois, une seule fois.
  static Future<PaymentOutcome> settle(NotchPayment payment) async {
    final userDoc = SkinAnalysisStorage.userDoc();
    final payments = _payments();
    if (userDoc == null || payments == null || !payment.isFinal) return PaymentOutcome.pending;

    final paymentDoc = payments.doc(payment.reference);
    final testKey = NotchPayService.isTestKey;

    return FirebaseFirestore.instance.runTransaction<PaymentOutcome>((transaction) async {
      final recorded = await transaction.get(paymentDoc);
      final data = recorded.data();
      if (data?['status'] == 'complete') return PaymentOutcome.activated;
      // Paiement inconnu ou déjà réglé : rien à enregistrer
      if (data == null || data['status'] != 'pending') return PaymentOutcome.rejected;

      final now = DateTime.now();

      if (!payment.isComplete) {
        transaction.update(paymentDoc, {
          'status': payment.status,
          'settledAt': now.millisecondsSinceEpoch,
        });
        return PaymentOutcome.failedWith(payment.status);
      }

      final reason = rejectionReason(payment, data, testKey: testKey);
      if (reason != null) {
        debugPrint('Paiement ${payment.reference} refusé : $reason');
        transaction.update(paymentDoc, {
          'status': 'invalid',
          'settledAt': now.millisecondsSinceEpoch,
        });
        return PaymentOutcome.rejected;
      }

      final profile = await transaction.get(userDoc);
      final current = Subscription.fromMap(profile.data()?[_field]);
      final renewed = Subscription(expiresAt: Subscription.renewedExpiry(current, now));

      // La référence désigne le paiement consommé : les règles Firestore
      // n'acceptent la prolongation que s'il passe à « complete » ici même
      transaction.set(
        userDoc,
        {
          _field: {...renewed.toJson(), 'payment': payment.reference},
        },
        SetOptions(merge: true),
      );
      transaction.update(paymentDoc, {
        'status': 'complete',
        'settledAt': now.millisecondsSinceEpoch,
      });
      return PaymentOutcome.activated;
    });
  }

  /// Revérifie les paiements restés en attente, par exemple validés sur le
  /// téléphone après la fermeture de l'app. Les erreurs sont ignorées : la
  /// vérification sera retentée à la prochaine ouverture.
  static Future<void> resumePending() async {
    final payments = _payments();
    if (payments == null) return;

    try {
      final pending = await payments.where('status', isEqualTo: 'pending').get();
      for (final doc in pending.docs) {
        final payment = await NotchPayService.retrieve(doc.id);
        if (payment.isFinal) await settle(payment);
      }
    } catch (e) {
      debugPrint('Vérification des paiements en attente : $e');
    }
  }
}

/// Issue d'un paiement suivi jusqu'au bout
enum PaymentOutcome {
  /// Payé, vérifié auprès de Notch Pay : l'abonnement est prolongé
  activated,

  /// Notch Pay le dit payé, mais la transaction ne correspond pas au paiement
  /// enregistré : l'abonnement n'est pas prolongé
  rejected,

  failed,
  canceled,
  expired,

  /// Aucune réponse définitive dans le délai d'attente
  pending;

  static PaymentOutcome failedWith(String status) => switch (status) {
        'canceled' => canceled,
        'expired' => expired,
        _ => failed,
      };
}
