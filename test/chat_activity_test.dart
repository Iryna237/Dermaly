import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/models/consultation.dart';
import 'package:ziskin/services/chat_activity.dart';

void main() {
  const me = 'derma1';
  const patient = 'patient1';

  const consultation = Consultation(
    id: 'patient1_derma1',
    patientId: patient,
    patientName: 'Awa',
    dermatologistId: me,
    dermatologistName: 'Dr Iryna',
    status: ConsultationStatus.accepted,
  );

  Map<String, dynamic> message(String text, String sender, DateTime at) => {
        'text': text,
        'sender': 'user',
        'senderId': sender,
        'timestamp': Timestamp.fromDate(at),
      };

  /// Messages du plus récent au plus ancien, comme les rend la requête
  ChatSummary summarise(List<Map<String, dynamic>> messages, {DateTime? lastRead}) {
    return ChatActivity.summarise(
      chatId: ChatActivity.chatIdFor(me, patient),
      consultation: consultation,
      uid: me,
      asDermatologist: true,
      messages: messages,
      lastRead: lastRead,
    );
  }

  group('ChatSummary', () {
    final now = DateTime(2026, 9, 22, 14);

    test('une conversation vide n\'a ni message ni non-lu', () {
      final summary = summarise(const []);
      expect(summary.hasMessages, isFalse);
      expect(summary.unread, 0);
      expect(summary.lastMessageAt, isNull);
    });

    test('sans lecture enregistree, tout ce qui vient du patient est non lu', () {
      final summary = summarise([
        message('Bonjour docteur', patient, now),
        message('Une question', patient, now.subtract(const Duration(days: 2))),
      ]);
      expect(summary.unread, 2);
    });

    test('seuls les messages recus apres la lecture comptent', () {
      final summary = summarise(
        [
          message('Et depuis hier ?', patient, now),
          message('Merci', me, now.subtract(const Duration(hours: 2))),
          message('Bonjour', patient, now.subtract(const Duration(hours: 3))),
        ],
        lastRead: now.subtract(const Duration(hours: 1)),
      );
      expect(summary.unread, 1);
    });

    test('mes propres messages ne sont jamais non lus', () {
      final summary = summarise([
        message('Je vous rappelle demain', me, now),
        message('Bien note', me, now.subtract(const Duration(minutes: 5))),
      ]);
      expect(summary.unread, 0);
      expect(summary.lastMessageIsMine, isTrue);
    });

    test('l\'apercu est le message le plus recent', () {
      final summary = summarise([
        message('Le dernier', patient, now),
        message('Le precedent', patient, now.subtract(const Duration(hours: 1))),
      ]);
      expect(summary.lastMessage, 'Le dernier');
      expect(summary.lastMessageAt, now);
      expect(summary.lastMessageIsMine, isFalse);
    });

    test('un message sans horodatage resolu est un message tout neuf', () {
      final summary = summarise(
        [
          {'text': 'Envoye a l\'instant', 'senderId': patient, 'timestamp': null},
        ],
        lastRead: now,
      );
      expect(summary.unread, 1);
    });

    test('le patient est l\'interlocuteur cote dermatologue', () {
      final summary = summarise([message('Bonjour', patient, now)]);
      expect(summary.peerId, patient);
      expect(summary.peerName, 'Awa');
    });
  });

  group('classement des conversations', () {
    ChatSummary chat(String name, DateTime? at) => ChatSummary(
          chatId: name,
          peerId: name,
          peerName: name,
          lastMessageAt: at,
          lastMessage: at == null ? '' : 'Bonjour',
          lastMessageIsMine: false,
          unread: 0,
        );

    test('la conversation la plus recente passe devant, les muettes a la fin', () {
      final chats = [
        chat('Ancienne', DateTime(2026, 9, 1)),
        chat('Jamais ecrit', null),
        chat('Recente', DateTime(2026, 9, 22)),
      ]..sort(ChatActivity.compareByActivity);

      expect(chats.map((c) => c.peerName).toList(),
          ['Recente', 'Ancienne', 'Jamais ecrit']);
    });
  });

  group('dates de lecture', () {
    test('les entrees exploitables sont converties, les autres ignorees', () {
      final reads = ChatActivity.readsFrom({
        'a_b': 1758542400000,
        'b_c': 'hier',
      });

      expect(reads.keys, ['a_b']);
      expect(reads['a_b'], DateTime.fromMillisecondsSinceEpoch(1758542400000));
    });

    test('un champ absent ne donne aucune lecture', () {
      expect(ChatActivity.readsFrom(null), isEmpty);
    });
  });

  test('l\'identifiant de conversation est le meme des deux cotes', () {
    expect(ChatActivity.chatIdFor(me, patient), ChatActivity.chatIdFor(patient, me));
  });
}
