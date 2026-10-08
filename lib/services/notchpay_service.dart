import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Opérateurs Mobile Money acceptés au Cameroun, avec leur canal Notch Pay
enum MobileMoneyChannel {
  mtn('cm.mtn', 'MTN Mobile Money'),
  orange('cm.orange', 'Orange Money');

  final String code;
  final String label;

  const MobileMoneyChannel(this.code, this.label);
}

/// Erreur renvoyée par Notch Pay, ou réseau indisponible (sans code HTTP)
class NotchPayException implements Exception {
  final String message;
  final int? statusCode;

  const NotchPayException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Transaction Notch Pay, réduite à ce qui décide de l'abonnement
class NotchPayment {
  final String reference;
  final String status;
  final num amount;
  final String currency;

  /// Référence choisie par Dermaly à la création : relie la transaction au
  /// paiement enregistré dans Firestore
  final String merchantReference;

  /// Transaction simulée (clé de test) : aucun argent n'a circulé
  final bool sandbox;

  const NotchPayment({
    required this.reference,
    required this.status,
    required this.amount,
    required this.currency,
    this.merchantReference = '',
    this.sandbox = false,
  });

  bool get isComplete => status == 'complete';

  /// Plus rien ne bougera : payé, refusé, annulé ou expiré.
  /// `pending` et `processing` attendent encore la confirmation du patient.
  bool get isFinal => isComplete || const {'failed', 'canceled', 'expired'}.contains(status);

  /// Lit la transaction d'une réponse Notch Pay, ou null si elle en est absente
  static NotchPayment? fromResponse(Map<String, dynamic> body) {
    final transaction = body['transaction'];
    if (transaction is! Map) return null;

    final reference = (transaction['reference'] as Object?)?.toString() ?? '';
    if (reference.isEmpty) return null;

    final amount = transaction['amount'];

    return NotchPayment(
      reference: reference,
      status: (transaction['status'] as Object?)?.toString().toLowerCase() ?? 'pending',
      amount: amount is num ? amount : num.tryParse('$amount') ?? 0,
      currency: (transaction['currency'] as Object?)?.toString().toUpperCase() ?? '',
      merchantReference: (transaction['merchant_reference'] as Object?)?.toString() ?? '',
      // Notch Pay renvoie 1 ; true et "1" sont acceptés par prudence
      sandbox: const {'true', '1'}.contains('${transaction['sandbox']}'.toLowerCase()),
    );
  }
}

/// Paiements Mobile Money via l'API Notch Pay (https://developer.notchpay.co).
///
/// Seule la clé publique (`NOTCHPAY_PUBLIC_KEY` dans `.env`) est utilisée : elle
/// suffit pour créer, déclencher et consulter un paiement. La clé privée ne
/// doit jamais se trouver dans l'application.
class NotchPayService {
  static const String _baseUrl = 'https://api.notchpay.co';
  static const Duration _requestTimeout = Duration(seconds: 30);

  static String get _publicKey {
    final key = dotenv.env['NOTCHPAY_PUBLIC_KEY']?.trim() ?? '';
    if (key.isEmpty) {
      throw const NotchPayException(
        'Payments are not configured: NOTCHPAY_PUBLIC_KEY is missing from .env.',
      );
    }
    return key;
  }

  /// Clé de test : les transactions sont simulées par Notch Pay
  static bool get isTestKey => _publicKey.startsWith('pk_test');

  /// Numéro camerounais au format attendu par Notch Pay (+237 suivi de 9 chiffres),
  /// ou null s'il n'en est pas un. Espaces, tirets et indicatif sont tolérés.
  static String? normalizeCameroonPhone(String input) {
    var digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00237')) digits = digits.substring(5);
    if (digits.length == 12 && digits.startsWith('237')) digits = digits.substring(3);

    // Les numéros mobiles camerounais ont 9 chiffres et commencent par 6
    if (digits.length != 9 || !digits.startsWith('6')) return null;
    return '+237$digits';
  }

  /// Opérateur Mobile Money d'un numéro normalisé, d'après son préfixe :
  /// MTN 67, 68 et 650 à 654 ; Orange 69 et 655 à 659. Null pour les autres
  /// numéros (Nexttel, Camtel, préfixes non attribués).
  static MobileMoneyChannel? operatorOf(String phone) {
    if (!phone.startsWith('+237') || phone.length != 13) return null;
    final digits = phone.substring(4);
    final third = int.parse(digits[2]);

    if (digits.startsWith('67') || digits.startsWith('68')) return MobileMoneyChannel.mtn;
    if (digits.startsWith('69')) return MobileMoneyChannel.orange;
    if (digits.startsWith('65')) {
      return third <= 4 ? MobileMoneyChannel.mtn : MobileMoneyChannel.orange;
    }
    return null;
  }

  /// Raison de refuser [input] pour un paiement par [channel], ou null si le
  /// numéro est un numéro Mobile Money de cet opérateur. Vérifié avant tout
  /// appel à Notch Pay.
  static String? phoneError(String input, MobileMoneyChannel channel) {
    final phone = normalizeCameroonPhone(input);
    if (phone == null) {
      return 'Enter a valid Cameroonian mobile number: 9 digits starting with 6, e.g. 6 70 00 00 00.';
    }

    final operator = operatorOf(phone);
    if (operator == null) {
      return 'This number is not an MTN or Orange Mobile Money number.';
    }
    if (operator != channel) {
      return 'This is an ${operator.label} number. Choose ${operator.label} or enter a ${channel.label} number.';
    }
    return null;
  }

  /// Crée le paiement chez Notch Pay. Rien n'est encore débité.
  static Future<NotchPayment> initialize({
    required int amount,
    required String currency,
    required String phone,
    required String reference,
    required String description,
    String? email,
    String? name,
  }) async {
    final body = await _send('POST', '/payments', {
      'amount': amount,
      'currency': currency,
      'reference': reference,
      'description': description,
      'customer': {
        'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (name != null && name.isNotEmpty) 'name': name,
      },
    });

    final payment = NotchPayment.fromResponse(body);
    if (payment == null) {
      throw const NotchPayException('Notch Pay did not return the payment reference.');
    }
    return payment;
  }

  /// Envoie la demande de paiement sur le téléphone du patient, qui la valide
  /// avec son code Mobile Money.
  static Future<void> charge({
    required String reference,
    required MobileMoneyChannel channel,
    required String phone,
  }) async {
    await _send('POST', '/payments/${Uri.encodeComponent(reference)}', {
      'channel': channel.code,
      'data': {'phone': phone},
    });
  }

  /// État actuel du paiement
  static Future<NotchPayment> retrieve(String reference) async {
    final body = await _send('GET', '/payments/${Uri.encodeComponent(reference)}');

    final payment = NotchPayment.fromResponse(body);
    if (payment == null) {
      throw const NotchPayException('Notch Pay returned an unreadable payment.');
    }
    return payment;
  }

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = {
      'Authorization': _publicKey,
      'Accept': 'application/json',
      if (payload != null) 'Content-Type': 'application/json',
    };

    final http.Response response;
    try {
      response = await (method == 'GET'
              ? http.get(uri, headers: headers)
              : http.post(uri, headers: headers, body: jsonEncode(payload)))
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const NotchPayException('Notch Pay did not answer in time. Check your connection.');
    } on http.ClientException {
      throw const NotchPayException('Unable to reach Notch Pay. Check your connection.');
    }

    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    } on FormatException {
      // Corps illisible : seul le code HTTP renseigne alors sur l'échec
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (body['message'] as Object?)?.toString();
      throw NotchPayException(
        message == null || message.isEmpty
            ? 'Payment error (HTTP ${response.statusCode}).'
            : message,
        statusCode: response.statusCode,
      );
    }

    return body;
  }
}
