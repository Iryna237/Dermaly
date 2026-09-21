import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageSender { user, ai }

class ChatMessage {
  final String text;
  final MessageSender sender;
  final DateTime timestamp;

  /// uid de l'expéditeur, renseigné dans les conversations entre deux personnes
  /// (client ↔ dermatologue) : les deux écrivent avec `sender` à `user`, donc
  /// lui seul dit de quel côté afficher le message.
  /// Null face à l'IA, où `sender` suffit à distinguer les deux interlocuteurs.
  final String? senderId;

  ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.senderId,
  });

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'sender': sender == MessageSender.user ? 'user' : 'ai',
      'timestamp': Timestamp.fromDate(timestamp),
      if (senderId != null) 'senderId': senderId,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      text: map['text'] ?? '',
      sender: map['sender'] == 'user' ? MessageSender.user : MessageSender.ai,
      senderId: map['senderId'] as String?,
      // Horodatage absent ou invalide : ne pas faire planter tout l'historique
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
