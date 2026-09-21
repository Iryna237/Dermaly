import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'models/chat_message.dart';
import 'models/consultation.dart';
import 'services/chat_service.dart';
import 'services/consultation_service.dart';
import 'services/message_notifier.dart';
import 'services/gemini_service.dart';
import 'user_avatar.dart';

class DermatologistChatListPage extends StatefulWidget {
  const DermatologistChatListPage({super.key});

  @override
  State<DermatologistChatListPage> createState() => _DermatologistChatListPageState();
}

class _DermatologistChatListPageState extends State<DermatologistChatListPage> {
  // Flux créé une seule fois : le recréer à chaque build relance la lecture Firestore
  late final Stream<List<Consultation>> _consultations =
      ConsultationService.watchForDermatologist();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
      ),
      body: StreamBuilder<List<Consultation>>(
        stream: _consultations,
        builder: (context, snapshot) {
          final accepted = (snapshot.data ?? const <Consultation>[])
              .where((c) => c.isAccepted)
              .toList();

          return Column(
            children: [
              _buildAiAssistantTile(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Divider(),
              ),
              Expanded(
                child: snapshot.hasError
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Text(
                          'Unable to load consultation requests. ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, color: AppColors.greyText, height: 1.4),
                        ),
                      )
                    : snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                    : ListView(
                        children: [
                          _buildSectionTitle('Patients'),
                          if (accepted.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                              child: Text(
                                'No patient yet. Accept a consultation request from the Requests tab '
                                'to start a conversation.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.greyText, fontSize: 13, height: 1.4),
                              ),
                            )
                          else
                            for (final consultation in accepted)
                              _buildChatTile(
                                name: consultation.patientName,
                                subtitle: 'Click to open the consultation',
                                userId: consultation.patientId,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DermaDetailedChatPage(
                                        patientId: consultation.patientId,
                                        patientName: consultation.patientName,
                                        isAi: false,
                                      ),
                                    ),
                                  );
                                },
                              ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
      ),
    );
  }

  Widget _buildAiAssistantTile() {
    return _buildChatTile(
      name: 'Dermaly AI Assistant',
      subtitle: 'Ask AI for medical advice & research',
      isAi: true,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DermaDetailedChatPage(
              patientId: 'ai_assistant',
              patientName: 'AI Assistant',
              isAi: true,
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatTile({
    required String name,
    required String subtitle,
    String? userId,
    bool isAi = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAi ? AppColors.softPurple : AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.softGrey),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: userId == null
            ? CircleAvatar(
                radius: 25,
                backgroundColor: isAi ? AppColors.primaryPurple : AppColors.lightPurple,
                child: Icon(isAi ? Icons.auto_awesome : Icons.person, color: Colors.white),
              )
            : UserAvatar(userId: userId, backgroundColor: AppColors.lightPurple),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.softGrey),
        onTap: onTap,
      ),
    );
  }
}

class DermaDetailedChatPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final bool isAi;

  const DermaDetailedChatPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.isAi,
  });

  @override
  State<DermaDetailedChatPage> createState() => _DermaDetailedChatPageState();
}

class _DermaDetailedChatPageState extends State<DermaDetailedChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ChatService _chatService = ChatService();
  final String _myId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isTyping = false;

  // Flux créé une seule fois : le recréer à chaque build relance la lecture Firestore
  late final Stream<List<ChatMessage>> _messages =
      widget.isAi ? _chatService.getMessages() : _getPeerMessages();

  @override
  void initState() {
    super.initState();
    // Lire une conversation vaut notification : pas de bannière pendant ce temps
    if (!widget.isAi) {
      MessageNotifier.openChatId = MessageNotifier.chatIdFor(_myId, widget.patientId);
    }
  }

  @override
  void dispose() {
    MessageNotifier.openChatId = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2EE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F2EE),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.darkPurple, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.patientName, style: const TextStyle(color: AppColors.darkPurple, fontWeight: FontWeight.bold)),
        actions: [
          if (!widget.isAi)
            TextButton.icon(
              onPressed: () => _showSkinAnalysisSummary(context),
              icon: const Icon(Icons.analytics_outlined, size: 18, color: AppColors.terracotta),
              label: const Text('Analysis', style: TextStyle(color: AppColors.terracotta, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    // Face à un patient, les deux côtés écrivent sender 'user' :
                    // seul senderId dit qui a parlé. Les messages antérieurs à son
                    // ajout n'en ont pas et gardent l'affichage d'origine.
                    final isMe = widget.isAi
                        ? msg.sender == MessageSender.user
                        : msg.senderId == null || msg.senderId == _myId;

                    return _buildBubble(msg.text, isMe, msg.timestamp);
                  },
                );
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('AI is thinking...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ),
          _buildInput(),
        ],
      ),
    );
  }

  Stream<List<ChatMessage>> _getPeerMessages() {
    final String chatId = _myId.compareTo(widget.patientId) < 0
        ? '${_myId}_${widget.patientId}'
        : '${widget.patientId}_$_myId';

    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList());
  }

  Widget _buildBubble(String text, bool isMe, DateTime time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.terracotta : AppColors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: isMe ? Colors.white : AppColors.darkPurple)),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(time),
              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                fillColor: AppColors.softPurple,
                filled: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: const CircleAvatar(
              backgroundColor: AppColors.primaryPurple,
              child: Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _send() async {
    final text = _controller.text.trim();
    // Bloquer le double envoi pendant que l'IA répond
    if (text.isEmpty || _isTyping) return;
    _controller.clear();

    if (widget.isAi) {
      setState(() => _isTyping = true);
      try {
        await _chatService.sendMessage(text);
      } catch (e) {
        // L'erreur est montrée au dermatologue, pas enregistrée comme une réponse de l'IA
        debugPrint('Erreur chat: $e');
        if (mounted) {
          final message = e.toString().replaceAll('Exception: ', '');
          // Surcharge passagère de l'IA : le message se suffit à lui-même
          final busy = e is GeminiException && e.isTransient;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(busy ? message : 'The AI could not answer: $message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isTyping = false);
      }
    } else {
      final String chatId = _myId.compareTo(widget.patientId) < 0
          ? '${_myId}_${widget.patientId}'
          : '${widget.patientId}_$_myId';

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'text': text,
            'sender': 'user',
            'senderId': _myId,
            'timestamp': FieldValue.serverTimestamp(),
          });
    }
  }

  /// Dernière analyse du patient, prise là où elle existe réellement.
  ///
  /// Trois emplacements, du plus récent au plus ancien dans l'histoire de
  /// l'application : le champ `lastSkinAnalysis` du profil, le dernier scan
  /// mensuel, puis la collection `analyses`. Aucun n'est garanti : un patient
  /// peut n'avoir fait que des scans mensuels, ou aucune analyse du tout.
  Future<({Map<String, dynamic> data, DateTime? date})?> _loadLatestAnalysis() async {
    final patient = FirebaseFirestore.instance.collection('users').doc(widget.patientId);

    try {
      final profile = await patient.get();
      final last = profile.data()?['lastSkinAnalysis'];
      if (last is Map) {
        final data = Map<String, dynamic>.from(last);
        return (data: data, date: _analysisDate(data['analyzedAt']));
      }

      final scans = await patient
          .collection('skinScans')
          .orderBy('analyzedAt', descending: true)
          .limit(1)
          .get();
      if (scans.docs.isNotEmpty) {
        final data = scans.docs.first.data();
        return (data: data, date: _analysisDate(data['analyzedAt']));
      }

      final analyses = await patient
          .collection('analyses')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (analyses.docs.isNotEmpty) {
        final data = analyses.docs.first.data();
        return (data: data, date: _analysisDate(data['timestamp']));
      }
    } catch (e) {
      debugPrint('Erreur chargement analyse du patient: $e');
    }

    return null;
  }

  /// La date est un entier pour le stockage local, un Timestamp côté serveur
  static DateTime? _analysisDate(Object? raw) {
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is Timestamp) return raw.toDate();
    return null;
  }

  void _showSkinAnalysisSummary(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return FutureBuilder<({Map<String, dynamic> data, DateTime? date})?>(
          future: _loadLatestAnalysis(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
            }

            final result = snapshot.data;
            if (result == null) {
              return Container(
                padding: const EdgeInsets.all(40),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No analysis found for this patient yet.', textAlign: TextAlign.center),
                  ],
                ),
              );
            }

            final analysis = result.data;
            final overallScore = analysis['overallScore'] ?? 0;
            final skinType = analysis['skinType'] ?? 'Unknown';
            final summary = analysis['recommendationSummary'] ?? 'No details available.';
            final hydration = analysis['hydrationLevel'] ?? 0;
            final concerns = analysis['concerns'] as Map<String, dynamic>? ?? {};

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text('Skin Analysis: ${widget.patientName}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
                      const SizedBox(height: 4),
                      Text(
                        result.date == null
                            ? 'Date unknown'
                            : 'Analyzed on ${DateFormat('MMM d, y').format(result.date!)}',
                        style: const TextStyle(fontSize: 13, color: AppColors.greyText),
                      ),
                      const SizedBox(height: 25),
                      
                      _buildSummaryStat('Overall Score', '$overallScore%', AppColors.primaryPurple),
                      _buildSummaryStat('Skin Type', skinType, AppColors.terracotta),
                      _buildSummaryStat('Hydration', '$hydration%', Colors.blue),
                      
                      const SizedBox(height: 20),
                      const Text('Concerns Detected:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      ...concerns.entries.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key),
                            Text('${e.value}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )),

                      const SizedBox(height: 25),
                      const Text('Clinical Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: AppColors.softPurple, borderRadius: BorderRadius.circular(15)),
                        child: Text(summary, style: const TextStyle(height: 1.5)),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryPurple,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text('CLOSE'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.greyText)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(10)),
            child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }
}
