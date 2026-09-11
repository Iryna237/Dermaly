import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/chat_message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // IMPORTANT: Replace with your actual Gemini API Key
  static const String _apiKey = '';

  late final GenerativeModel _model;
  ChatSession? _chatSession;

  ChatService() {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
      systemInstruction: Content.system(
        'You are Dr. Zita, a specialized dermatologist for Dermaly. '
        'Your goal is to provide expert skincare advice, analyze skin concerns, '
        'and suggest skincare routines. Be professional, empathetic, and encouraging. '
        'Always remind users to consult a doctor in person for severe conditions.'
      ),
    );
  }

  String get _userId => _auth.currentUser?.uid ?? 'anonymous';

  /// Stream of chat messages for the current user
  Stream<List<ChatMessage>> getMessages() {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data()))
            .toList());
  }

  /// Send a message to Gemini and store both in Firestore
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    // 1. Save user message to Firestore
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('messages')
        .add(userMessage.toMap());

    try {
      // 2. Get history for context (optional but better)
      final historySnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .limitToLast(10)
          .get();

      final history = historySnapshot.docs.map((doc) {
        final msg = ChatMessage.fromMap(doc.data());
        return msg.sender == MessageSender.user
            ? Content.text(msg.text)
            : Content.model([TextPart(msg.text)]);
      }).toList();

      // 3. Start/Resume Gemini session
      _chatSession ??= _model.startChat(history: history);

      // 4. Get AI response
      final response = await _chatSession!.sendMessage(Content.text(text));
      final aiText = response.text ?? "I'm sorry, I couldn't process that. Please try again.";

      final aiMessage = ChatMessage(
        text: aiText,
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      );

      // 5. Save AI message to Firestore
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('messages')
          .add(aiMessage.toMap());
          
    } catch (e) {
      final errorMessage = ChatMessage(
        text: "Error: Could not connect to AI. Please check your API key.",
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      );
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('messages')
          .add(errorMessage.toMap());
    }
  }
}
