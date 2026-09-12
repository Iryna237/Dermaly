import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';
import 'gemini_service.dart';
import 'skin_analysis_storage.dart';

/// Conversation avec Dr. Zita, la dermatologue IA de Dermaly (Gemini).
/// Les messages sont stockés dans `users/{uid}/messages`.
class ChatService {
  /// Nombre de messages précédents envoyés à Gemini pour garder le contexte
  static const int _historyLength = 20;

  static const String _systemInstruction =
      'You are Dr. Zita, a specialized dermatologist for Dermaly. '
      'Your goal is to provide expert skincare advice, analyze skin concerns, '
      'and suggest skincare routines. Be professional, empathetic, and encouraging. '
      'Always remind users to consult a doctor in person for severe conditions.';

  CollectionReference<Map<String, dynamic>>? _messages() {
    return SkinAnalysisStorage.userDoc()?.collection('messages');
  }

  /// Messages de l'utilisateur connecté, du plus récent au plus ancien
  Stream<List<ChatMessage>> getMessages() {
    final messages = _messages();
    if (messages == null) return Stream.value(const []);

    return messages
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList());
  }

  /// Enregistre le message de l'utilisateur, demande la réponse à Gemini puis l'enregistre.
  /// Lève une exception si Gemini ne répond pas : le message de l'utilisateur reste enregistré.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final messages = _messages();
    if (messages == null) {
      throw Exception('Please sign in to chat with Dr. Zita.');
    }

    // Contexte : derniers messages avant le nouveau, remis dans l'ordre chronologique
    final previous = await messages
        .orderBy('timestamp', descending: true)
        .limit(_historyLength)
        .get();
    final history = previous.docs.reversed.map((doc) => ChatMessage.fromMap(doc.data()));

    final userMessage = ChatMessage(
      text: trimmed,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );
    await SkinAnalysisStorage.writeWithTimeout(messages.add(userMessage.toMap()));

    // Gemini attend une conversation qui commence par un message de l'utilisateur
    final conversation = [...history, userMessage].skipWhile((m) => m.sender == MessageSender.ai);

    final reply = await GeminiService.generateText(
      systemInstruction: _systemInstruction,
      contents: [
        for (final message in conversation)
          {
            'role': message.sender == MessageSender.user ? 'user' : 'model',
            'parts': [
              {'text': message.text}
            ],
          },
      ],
    );

    final aiMessage = ChatMessage(
      text: reply,
      sender: MessageSender.ai,
      timestamp: DateTime.now(),
    );
    await SkinAnalysisStorage.writeWithTimeout(messages.add(aiMessage.toMap()));
  }
}
