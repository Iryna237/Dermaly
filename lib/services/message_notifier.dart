import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../models/consultation.dart';
import 'consultation_service.dart';
import 'notification_log.dart';
import 'notification_service.dart';

/// Prévient d'un nouveau message dans une consultation : le patient quand son
/// dermatologue lui écrit, le dermatologue quand un patient lui écrit.
///
/// Une notification locale ne peut être déclenchée que par l'application :
/// l'écoute ne vit donc que tant que l'app tourne. Les messages reçus pendant
/// qu'elle est fermée sont rattrapés à la réouverture, car le premier événement
/// de chaque conversation porte son dernier message.
///
/// Recevoir la notification hors application demanderait Firebase Cloud
/// Messaging et un backend pour l'émettre.
class MessageNotifier {
  static StreamSubscription<List<Consultation>>? _consultations;

  /// Sens de l'écoute : change l'interlocuteur à surveiller et le nom affiché
  static bool _asDermatologist = false;
  static final Map<String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _chats = {};

  /// Conversation actuellement ouverte : pas de bannière pour un message que
  /// l'utilisateur est en train de lire.
  static String? openChatId;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Identifiant de conversation, identique des deux côtés
  static String chatIdFor(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  /// Commence à surveiller les consultations acceptées de l'utilisateur.
  /// Appeler plusieurs fois est sans effet : l'écoute existante est reprise.
  static void start({bool asDermatologist = false}) {
    if (_consultations != null) return;
    if (_uid == null) return;

    _asDermatologist = asDermatologist;
    final consultations = asDermatologist
        ? ConsultationService.watchForDermatologist()
        : ConsultationService.watchForPatient();

    _consultations = consultations.listen(
      _syncChats,
      onError: (Object e) => debugPrint('Erreur écoute des consultations: $e'),
    );
  }

  /// Interlocuteur à surveiller dans une consultation
  static String _peerId(Consultation consultation) =>
      _asDermatologist ? consultation.patientId : consultation.dermatologistId;

  /// Nom affiché en titre de la notification
  static String _peerName(Consultation consultation) =>
      _asDermatologist ? consultation.patientName : consultation.dermatologistName;

  /// Arrête toutes les écoutes (déconnexion, fermeture de l'espace client)
  static void stop() {
    _consultations?.cancel();
    _consultations = null;
    for (final subscription in _chats.values) {
      subscription.cancel();
    }
    _chats.clear();
    openChatId = null;
  }

  /// Une écoute par conversation acceptée, ni plus ni moins
  static void _syncChats(List<Consultation> consultations) {
    final uid = _uid;
    if (uid == null) return;

    final accepted = {
      for (final consultation in consultations)
        if (consultation.isAccepted)
          chatIdFor(uid, _peerId(consultation)): consultation,
    };

    // Consultations retirées ou refusées : on cesse de les écouter
    for (final chatId in _chats.keys.toList()) {
      if (!accepted.containsKey(chatId)) {
        _chats.remove(chatId)?.cancel();
      }
    }

    accepted.forEach((chatId, consultation) {
      if (_chats.containsKey(chatId)) return;

      _chats[chatId] = FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen(
            (snapshot) => _onMessage(snapshot, chatId, consultation),
            onError: (Object e) => debugPrint('Erreur écoute du chat $chatId: $e'),
          );
    });
  }

  static Future<void> _onMessage(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String chatId,
    Consultation consultation,
  ) async {
    if (snapshot.docs.isEmpty) return;

    final data = snapshot.docs.first.data();
    final senderId = (data['senderId'] as Object?)?.toString();

    // Message envoyé par le patient lui-même, ou trop ancien pour porter un
    // expéditeur : rien à signaler
    if (senderId == null || senderId == _uid) return;

    final timestamp = data['timestamp'];
    // L'horodatage serveur arrive nul juste après l'écriture, avant sa résolution
    if (timestamp is! Timestamp) return;

    final text = (data['text'] as Object?)?.toString() ?? '';
    final date = timestamp.toDate();

    // Identifiant déterministe : un même message n'est jamais journalisé deux fois
    final notification = AppNotification(
      id: 'message_${chatId}_${date.millisecondsSinceEpoch}',
      title: _peerName(consultation),
      body: text.isEmpty ? 'Sent you a message.' : text,
      date: date,
    );

    // addIfMissing ne renvoie vrai qu'à la création : la bannière ne réapparait
    // donc pas à chaque ouverture de l'application
    final isNew = await NotificationLog.addIfMissing(notification);
    if (!isNew || openChatId == chatId) return;

    await NotificationService.showNow(
      id: _notificationId(notification.id),
      title: notification.title,
      body: notification.body,
    );
  }

  /// Identifiant numérique stable, demandé par le plugin de notifications.
  /// Borné pour rester dans un entier 32 bits, et décalé pour ne pas croiser
  /// les identifiants fixes des rappels de routine et de scan.
  static int _notificationId(String key) => 100000 + (key.hashCode.abs() % 800000);
}
