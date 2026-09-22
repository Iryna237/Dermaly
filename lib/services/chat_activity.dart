import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/consultation.dart';
import 'consultation_service.dart';
import 'skin_analysis_storage.dart';

/// Etat d'une conversation acceptee : qui, quand, et ce qui n'a pas ete lu.
class ChatSummary {
  final String chatId;
  final String peerId;
  final String peerName;

  /// Date du dernier message echange, null tant que personne n'a ecrit
  final DateTime? lastMessageAt;

  /// Texte du dernier message, vide si la conversation n'a pas commence
  final String lastMessage;

  /// Vrai si le dernier message vient de l'utilisateur connecte
  final bool lastMessageIsMine;

  /// Messages recus depuis la derniere ouverture de la conversation
  final int unread;

  const ChatSummary({
    required this.chatId,
    required this.peerId,
    required this.peerName,
    required this.lastMessageAt,
    required this.lastMessage,
    required this.lastMessageIsMine,
    required this.unread,
  });

  bool get hasMessages => lastMessageAt != null || lastMessage.isNotEmpty;
}

/// Activite des conversations acceptees de l'utilisateur connecte : qui a ecrit
/// en dernier, et combien de messages attendent d'etre lus.
///
/// La derniere lecture de chaque conversation est gardee sur le profil, dans le
/// champ `chatReads` du document `users/{uid}` : c'est une information propre a
/// chacun, elle n'a rien a faire dans le message lui-meme, que les deux
/// interlocuteurs partagent.
class ChatActivity {
  static const String _field = 'chatReads';

  /// Messages relus par conversation. Au-dela, le compteur de non-lus plafonne :
  /// une conversation avec cinquante messages en retard se lit, elle ne se
  /// compte plus.
  static const int messageWindow = 50;

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Identifiant de conversation, identique des deux cotes
  static String chatIdFor(String a, String b) =>
      a.compareTo(b) < 0 ? '${a}_$b' : '${b}_$a';

  /// Marque la conversation comme lue a l'instant
  static Future<void> markRead(String chatId) async {
    final docRef = SkinAnalysisStorage.userDoc();
    if (docRef == null) return;

    try {
      // merge fusionne la map : les autres conversations gardent leur date
      await SkinAnalysisStorage.writeWithTimeout(docRef.set(
        {
          _field: {chatId: DateTime.now().millisecondsSinceEpoch},
        },
        SetOptions(merge: true),
      ));
    } catch (e) {
      debugPrint('Erreur enregistrement de la lecture: $e');
    }
  }

  /// Conversations de l'utilisateur, la plus recemment animee en premier.
  ///
  /// Le flux suit les consultations acceptees, les messages de chacune et les
  /// dates de lecture du profil : un nouveau message, une demande acceptee ou
  /// une conversation ouverte le met a jour.
  ///
  /// Diffuse : l'accueil le partage entre ses cartes, et les ecoutes Firestore
  /// s'arretent des que plus personne ne l'ecoute.
  static Stream<List<ChatSummary>> watch({required bool asDermatologist}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);

    final peers = <String, Consultation>{};
    final histories = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    var reads = <String, DateTime>{};

    StreamSubscription<List<Consultation>>? consultations;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profile;
    final messages = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};

    List<ChatSummary>? latest;
    late StreamController<List<ChatSummary>> controller;

    void emit() {
      final summaries = [
        for (final entry in peers.entries)
          _summarise(
            chatId: entry.key,
            consultation: entry.value,
            uid: uid,
            asDermatologist: asDermatologist,
            docs: histories[entry.key] ?? const [],
            lastRead: reads[entry.key],
          ),
      ];
      summaries.sort(compareByActivity);

      latest = summaries;
      if (!controller.isClosed) controller.add(summaries);
    }

    /// Une ecoute par conversation acceptee, ni plus ni moins
    void syncChats(List<Consultation> all) {
      peers
        ..clear()
        ..addEntries([
          for (final consultation in all)
            if (consultation.isAccepted)
              MapEntry(
                chatIdFor(
                  uid,
                  asDermatologist ? consultation.patientId : consultation.dermatologistId,
                ),
                consultation,
              ),
        ]);

      // Consultation retiree ou refusee : on cesse de l'ecouter
      for (final chatId in messages.keys.toList()) {
        if (!peers.containsKey(chatId)) {
          messages.remove(chatId)?.cancel();
          histories.remove(chatId);
        }
      }

      for (final chatId in peers.keys) {
        if (messages.containsKey(chatId)) continue;

        messages[chatId] = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(messageWindow)
            .snapshots()
            .listen(
          (snapshot) {
            histories[chatId] = snapshot.docs;
            emit();
          },
          onError: (Object e) => debugPrint('Erreur ecoute du chat $chatId: $e'),
        );
      }

      emit();
    }

    void start() {
      consultations = (asDermatologist
              ? ConsultationService.watchForDermatologist()
              : ConsultationService.watchForPatient())
          .listen(
        syncChats,
        onError: (Object e) => debugPrint('Erreur ecoute des consultations: $e'),
      );

      profile = SkinAnalysisStorage.userDoc()?.snapshots().listen(
        (doc) {
          reads = readsFrom(doc.data()?[_field]);
          emit();
        },
        onError: (Object e) => debugPrint('Erreur ecoute des lectures: $e'),
      );

      // Un abonne qui revient (retour sur l'onglet Home) retrouve tout de suite
      // le dernier etat connu, au lieu d'une carte vide le temps des lectures
      final known = latest;
      if (known != null) {
        scheduleMicrotask(() {
          if (!controller.isClosed) controller.add(known);
        });
      }
    }

    void stop() {
      consultations?.cancel();
      consultations = null;
      profile?.cancel();
      profile = null;
      for (final subscription in messages.values) {
        subscription.cancel();
      }
      messages.clear();
    }

    controller = StreamController<List<ChatSummary>>.broadcast(
      onListen: start,
      onCancel: stop,
    );
    return controller.stream;
  }

  /// La conversation la plus recente d'abord ; celles sans message a la fin
  static int compareByActivity(ChatSummary a, ChatSummary b) {
    final dateA = a.lastMessageAt, dateB = b.lastMessageAt;
    if (dateA == null && dateB == null) return a.peerName.compareTo(b.peerName);
    if (dateA == null) return 1;
    if (dateB == null) return -1;
    return dateB.compareTo(dateA);
  }

  @visibleForTesting
  static ChatSummary summarise({
    required String chatId,
    required Consultation consultation,
    required String uid,
    required bool asDermatologist,
    required List<Map<String, dynamic>> messages,
    required DateTime? lastRead,
  }) {
    var unread = 0;
    DateTime? lastMessageAt;
    var lastMessage = '';
    var lastMessageIsMine = false;
    var first = true;

    // Messages du plus recent au plus ancien : le premier donne l'apercu
    for (final data in messages) {
      final senderId = (data['senderId'] as Object?)?.toString();
      final raw = data['timestamp'];
      // L'horodatage serveur arrive nul juste apres l'ecriture : le message est
      // alors tout neuf, donc non lu s'il vient de l'autre.
      final at = raw is Timestamp ? raw.toDate() : null;
      final isMine = senderId == uid;

      if (first) {
        first = false;
        lastMessageAt = at;
        lastMessage = (data['text'] as Object?)?.toString() ?? '';
        lastMessageIsMine = isMine;
      }

      if (!isMine && (at == null || lastRead == null || at.isAfter(lastRead))) {
        unread++;
      }
    }

    return ChatSummary(
      chatId: chatId,
      peerId: asDermatologist ? consultation.patientId : consultation.dermatologistId,
      peerName:
          asDermatologist ? consultation.patientName : consultation.dermatologistName,
      lastMessageAt: lastMessageAt,
      lastMessage: lastMessage,
      lastMessageIsMine: lastMessageIsMine,
      unread: unread,
    );
  }

  static ChatSummary _summarise({
    required String chatId,
    required Consultation consultation,
    required String uid,
    required bool asDermatologist,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required DateTime? lastRead,
  }) {
    return summarise(
      chatId: chatId,
      consultation: consultation,
      uid: uid,
      asDermatologist: asDermatologist,
      messages: [for (final doc in docs) doc.data()],
      lastRead: lastRead,
    );
  }

  /// Dates de derniere lecture, telles qu'enregistrees sur le profil
  @visibleForTesting
  static Map<String, DateTime> readsFrom(Object? raw) {
    if (raw is! Map) return {};

    return {
      for (final entry in raw.entries)
        if (entry.value is int)
          '${entry.key}': DateTime.fromMillisecondsSinceEpoch(entry.value as int),
    };
  }
}
