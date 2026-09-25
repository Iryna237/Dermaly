import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ziskin/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    final sentAt = DateTime(2026, 9, 22, 14, 30);

    test('the sender is stored as user or ai', () {
      final fromUser = ChatMessage(text: 'Hi', sender: MessageSender.user, timestamp: sentAt);
      final fromAi = ChatMessage(text: 'Hello', sender: MessageSender.ai, timestamp: sentAt);

      expect(fromUser.toMap()['sender'], 'user');
      expect(fromAi.toMap()['sender'], 'ai');
      expect(fromUser.toMap()['timestamp'], Timestamp.fromDate(sentAt));
    });

    test('the sender id is only stored when known', () {
      final withAi = ChatMessage(text: 'Hi', sender: MessageSender.user, timestamp: sentAt);
      final withPeer = ChatMessage(
        text: 'Hi',
        sender: MessageSender.user,
        timestamp: sentAt,
        senderId: 'patient-1',
      );

      expect(withAi.toMap().containsKey('senderId'), isFalse);
      expect(withPeer.toMap()['senderId'], 'patient-1');
    });

    test('a saved message reads back the same', () {
      final original = ChatMessage(
        text: 'Is this spot worrying?',
        sender: MessageSender.user,
        timestamp: sentAt,
        senderId: 'patient-1',
      );

      final copy = ChatMessage.fromMap(original.toMap());

      expect(copy.text, original.text);
      expect(copy.sender, original.sender);
      expect(copy.timestamp, original.timestamp);
      expect(copy.senderId, original.senderId);
    });

    test('a damaged message still reads without crashing', () {
      final before = DateTime.now();
      final message = ChatMessage.fromMap({'sender': 'bot', 'timestamp': 'yesterday'});
      final after = DateTime.now();

      expect(message.text, '');
      expect(message.sender, MessageSender.ai);
      expect(message.senderId, isNull);
      expect(message.timestamp.isBefore(before), isFalse);
      expect(message.timestamp.isAfter(after), isFalse);
    });
  });
}
