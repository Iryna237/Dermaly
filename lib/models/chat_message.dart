import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageSender { user, ai }

class ChatMessage {
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'sender': sender == MessageSender.user ? 'user' : 'ai',
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      sender: map['sender'] == 'user' ? MessageSender.user : MessageSender.ai,
      // Horodatage absent ou invalide : ne pas faire planter tout l'historique
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
