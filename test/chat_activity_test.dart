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

    test('an empty conversation has no message and nothing unread', () {
      final summary = summarise(const []);
      expect(summary.hasMessages, isFalse);
      expect(summary.unread, 0);
      expect(summary.lastMessageAt, isNull);
    });

    test('with no recorded read, everything from the patient is unread', () {
      final summary = summarise([
        message('Bonjour docteur', patient, now),
        message('Une question', patient, now.subtract(const Duration(days: 2))),
      ]);
      expect(summary.unread, 2);
    });

    test('only messages received after the last read count', () {
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

    test('my own messages are never unread', () {
      final summary = summarise([
        message('Je vous rappelle demain', me, now),
        message('Bien note', me, now.subtract(const Duration(minutes: 5))),
      ]);
      expect(summary.unread, 0);
      expect(summary.lastMessageIsMine, isTrue);
    });

    test('the preview is the most recent message', () {
      final summary = summarise([
        message('Le dernier', patient, now),
        message('Le precedent', patient, now.subtract(const Duration(hours: 1))),
      ]);
      expect(summary.lastMessage, 'Le dernier');
      expect(summary.lastMessageAt, now);
      expect(summary.lastMessageIsMine, isFalse);
    });

    test('a message without a resolved timestamp is brand new', () {
      final summary = summarise(
        [
          {'text': 'Envoye a l\'instant', 'senderId': patient, 'timestamp': null},
        ],
        lastRead: now,
      );
      expect(summary.unread, 1);
    });

    test('the patient is the other party on the dermatologist side', () {
      final summary = summarise([message('Bonjour', patient, now)]);
      expect(summary.peerId, patient);
      expect(summary.peerName, 'Awa');
    });
  });

  group('conversation ordering', () {
    ChatSummary chat(String name, DateTime? at) => ChatSummary(
          chatId: name,
          peerId: name,
          peerName: name,
          lastMessageAt: at,
          lastMessage: at == null ? '' : 'Bonjour',
          lastMessageIsMine: false,
          unread: 0,
        );

    test('the most recent conversation comes first, silent ones last', () {
      final chats = [
        chat('Ancienne', DateTime(2026, 9, 1)),
        chat('Jamais ecrit', null),
        chat('Recente', DateTime(2026, 9, 22)),
      ]..sort(ChatActivity.compareByActivity);

      expect(chats.map((c) => c.peerName).toList(),
          ['Recente', 'Ancienne', 'Jamais ecrit']);
    });
  });

  group('read dates', () {
    test('usable entries are converted, the others ignored', () {
      final reads = ChatActivity.readsFrom({
        'a_b': 1758542400000,
        'b_c': 'hier',
      });

      expect(reads.keys, ['a_b']);
      expect(reads['a_b'], DateTime.fromMillisecondsSinceEpoch(1758542400000));
    });

    test('a missing field gives no reads', () {
      expect(ChatActivity.readsFrom(null), isEmpty);
    });
  });

  test('the conversation id is the same on both sides', () {
    expect(ChatActivity.chatIdFor(me, patient), ChatActivity.chatIdFor(patient, me));
  });
}
