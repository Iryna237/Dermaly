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
  static Future<String> startPayment({
    required MobileMoneyChannel channel,
    required String phone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final payments = _payments();
    if (user == null || payments == null) {
      throw Exception('Please sign in to subscribe.');
    }

    final payment = await NotchPayService.initialize(
      amount: Subscription.price,
      currency: Subscription.currency,
      phone: phone,
      email: user.email,
      name: user.displayName,
      reference: 'dermaly-${user.uid}-${DateTime.now().millisecondsSinceEpoch}',
      description: 'Dermaly - 1 month of dermatologist access',
    );

    // Gardé avant le débit : si l'app se ferme pendant la confirmation, le
    // paiement sera retrouvé et vérifié à la prochaine ouverture.
    await SkinAnalysisStorage.writeWithTimeout(payments.doc(payment.reference).set({
      'status': 'pending',
      'amount': Subscription.price,
      'currency': Subscription.currency,
      'channel': channel.code,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    }));

    await NotchPayService.charge(reference: payment.reference, channel: channel, phone: phone);
    return payment.reference;
  }

  /// Suit le paiement jusqu'à son issue, ou jusqu'à [confirmationTimeout].
  /// Un paiement réussi prolonge l'abonnement avant d'être retourné.
  static Future<NotchPayment?> waitForResult(String reference) async {
    final deadline = DateTime.now().add(confirmationTimeout);
    NotchPayment? last;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollInterval);

      try {
        last = await NotchPayService.retrieve(reference);
      } on NotchPayException catch (e) {
        // Coupure réseau passagère : le paiement continue côté Notch Pay
        debugPrint('Suivi du paiement $reference : $e');
        continue;
      }

      if (last.isFinal) {
        await settle(last);
        return last;
      }
    }

    return last;
  }

  /// Enregistre l'issue d'un paiement. Un paiement réussi, du bon montant,
  /// prolonge l'abonnement d'un mois, une seule fois.
  static Future<void> settle(NotchPayment payment) async {
    final userDoc = SkinAnalysisStorage.userDoc();
    final payments = _payments();
    if (userDoc == null || payments == null || !payment.isFinal) return;

    final paymentDoc = payments.doc(payment.reference);
    final valid = payment.isComplete &&
        payment.amount >= Subscription.price &&
        payment.currency == Subscription.currency;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final recorded = await transaction.get(paymentDoc);
      if (recorded.data()?['status'] == 'complete') return;

      final now = DateTime.now();

      if (!valid) {
        transaction.set(
          paymentDoc,
          {
            'status': payment.isComplete ? 'invalid' : payment.status,
            'settledAt': now.millisecondsSinceEpoch,
          },
          SetOptions(merge: true),
        );
        return;
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
      transaction.set(
        paymentDoc,
        {'status': 'complete', 'settledAt': now.millisecondsSinceEpoch},
        SetOptions(merge: true),
      );
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
        await settle(payment);
      }
    } catch (e) {
      debugPrint('Vérification des paiements en attente : $e');
    }
  }
}
