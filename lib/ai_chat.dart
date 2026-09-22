import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'models/chat_message.dart';
import 'services/chat_service.dart';
import 'models/consultation.dart';
import 'request_consultation.dart';
import 'services/chat_activity.dart';
import 'services/consultation_service.dart';
import 'services/gemini_service.dart';
import 'services/message_notifier.dart';
import 'unread_badge.dart';
import 'user_avatar.dart';

class ClientChatListPage extends StatefulWidget {
  const ClientChatListPage({super.key});

  @override
  State<ClientChatListPage> createState() => _ClientChatListPageState();
}

class _ClientChatListPageState extends State<ClientChatListPage> {
  // Flux créés une seule fois : les recréer à chaque build relance la lecture Firestore
  late final Stream<List<Consultation>> _consultations =
      ConsultationService.watchForPatient();
  late final Stream<List<ChatSummary>> _chats =
      ChatActivity.watch(asDermatologist: false);

  void _openRequestPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RequestConsultationPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Dermaly Messages',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
      ),
      body: StreamBuilder<List<Consultation>>(
        stream: _consultations,
        builder: (context, snapshot) {
          final consultations = snapshot.data ?? const <Consultation>[];
          final accepted = consultations.where((c) => c.isAccepted).toList();
          final pending = consultations.where((c) => c.isPending).toList();

          return StreamBuilder<List<ChatSummary>>(
            stream: _chats,
            builder: (context, chats) {
              // Non-lus par dermatologue : la liste garde son ordre, seules les
              // conversations qui attendent une lecture se signalent.
              final unread = {
                for (final chat in chats.data ?? const <ChatSummary>[])
                  chat.peerId: chat.unread,
              };

              return Column(
                children: [
                  // L'assistant IA reste accessible sans aucune demande
                  _buildChatTile(
                    name: 'Dermaly AI Assistant',
                    subtitle: 'AI specialized in dermatology',
                    isAi: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const DetailedChatPage(isAi: true)),
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Divider(),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Professional Consultations',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
                      ),
                    ),
                  ),
                  Expanded(
                    child: snapshot.hasError
                        ? _buildError(snapshot.error.toString())
                        : snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple))
                        : (accepted.isEmpty && pending.isEmpty)
                            ? _buildEmptyState()
                            : ListView(
                                children: [
                                  // Le chat n'apparait qu'une fois la demande acceptée
                                  for (final consultation in accepted)
                                    _buildChatTile(
                                      name: consultation.dermatologistName,
                                      subtitle: (unread[consultation.dermatologistId] ?? 0) > 0
                                          ? 'New message waiting'
                                          : 'Consultation accepted · tap to chat',
                                      userId: consultation.dermatologistId,
                                      unread: unread[consultation.dermatologistId] ?? 0,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => DetailedChatPage(
                                              isAi: false,
                                              peerId: consultation.dermatologistId,
                                              peerName: consultation.dermatologistName,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  for (final consultation in pending)
                                    _buildPendingTile(consultation),
                                ],
                              ),
                  ),
                ],
              );
            },
          );
        },
      ),
      // Première demande : bouton explicite. Ensuite, un simple « + »
      floatingActionButton: StreamBuilder<List<Consultation>>(
        stream: _consultations,
        builder: (context, snapshot) {
          final hasAny = (snapshot.data ?? const <Consultation>[])
              .any((c) => c.isAccepted || c.isPending);

          if (hasAny) {
            return FloatingActionButton(
              onPressed: _openRequestPage,
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: AppColors.white,
              tooltip: 'Request another consultation',
              child: const Icon(Icons.add),
            );
          }

          return FloatingActionButton.extended(
            onPressed: _openRequestPage,
            backgroundColor: AppColors.primaryPurple,
            foregroundColor: AppColors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'Request consultation',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }

  /// Une erreur de lecture ne doit pas ressembler à une absence de consultation
  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.softGrey),
            const SizedBox(height: 16),
            const Text(
              'Unable to load your consultations',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.greyText, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services_outlined, size: 48, color: AppColors.softGrey),
            const SizedBox(height: 16),
            const Text(
              'No consultation yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkPurple),
            ),
            const SizedBox(height: 8),
            const Text(
              'Request a consultation to start chatting with a dermatologist. '
              'They open the conversation once they accept.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.greyText, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  /// Demande envoyée, pas encore acceptée : visible mais non cliquable
  Widget _buildPendingTile(Consultation consultation) {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.softGrey),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          radius: 25,
          backgroundColor: AppColors.softPurple,
          child: Icon(Icons.hourglass_empty_rounded, color: AppColors.primaryPurple),
        ),
        title: Text(
          consultation.dermatologistName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkPurple),
        ),
        subtitle: const Text(
          'Request sent · waiting for approval',
          style: TextStyle(fontSize: 12, color: AppColors.greyText),
        ),
      ),
    );
  }

  Widget _buildChatTile({
    required String name,
    required String subtitle,
    String? userId,
    bool isAi = false,
    int unread = 0,
    required VoidCallback onTap,
  }) {
    // Une conversation non lue se repère avant d'être ouverte, comme côté
    // dermatologue : fond teinté et nombre de messages en attente.
    final hasUnread = unread > 0;

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAi
            ? AppColors.softPurple
            : hasUnread
                ? AppColors.terracotta.withAlpha(15)
                : AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: hasUnread ? AppColors.terracotta.withAlpha(90) : AppColors.softGrey,
        ),
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
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: hasUnread ? AppColors.terracotta : AppColors.greyText,
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: hasUnread
            ? UnreadCount(count: unread)
            : const Icon(Icons.chevron_right_rounded, color: AppColors.softGrey),
        onTap: onTap,
      ),
    );
  }
}

class DetailedChatPage extends StatefulWidget {
  final bool isAi;
  final String? peerId;
  final String? peerName;

  const DetailedChatPage({
    super.key,
    required this.isAi,
    this.peerId,
    this.peerName,
  });

  @override
  State<DetailedChatPage> createState() => _DetailedChatPageState();
}

class _DetailedChatPageState extends State<DetailedChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final String _myId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isTyping = false;

  // Flux créé une seule fois : le recréer à chaque build relance la lecture Firestore
  late final Stream<List<ChatMessage>> _messages =
      widget.isAi ? _chatService.getMessages() : _getPeerMessages();

  /// Conversation avec ce dermatologue, vide face à l'IA qui n'en a pas
  late final String _chatId = widget.isAi || widget.peerId == null
      ? ''
      : ChatActivity.chatIdFor(_myId, widget.peerId!);

  @override
  void initState() {
    super.initState();
    // Lire une conversation vaut notification : pas de bannière pendant ce temps
    if (_chatId.isNotEmpty) {
      MessageNotifier.openChatId = _chatId;
      ChatActivity.markRead(_chatId);
    }
  }

  @override
  void dispose() {
    MessageNotifier.openChatId = null;
    // Les messages arrivés pendant la lecture sont lus, eux aussi : sans cette
    // seconde marque, ils resteraient comptés comme non lus à la sortie.
    if (_chatId.isNotEmpty) ChatActivity.markRead(_chatId);
    _messageController.dispose();
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
        title: Text(
          widget.isAi ? 'Dermaly AI' : (widget.peerName ?? 'Dermatologist'),
          style: const TextStyle(color: AppColors.darkPurple, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
                    // Face à un dermatologue, les deux côtés écrivent sender 'user' :
                    // seul senderId dit qui a parlé. Les messages antérieurs à son
                    // ajout n'en ont pas et gardent l'affichage d'origine.
                    final isMe = widget.isAi
                        ? msg.sender == MessageSender.user
                        : msg.senderId == null || msg.senderId == _myId;

                    return _buildChatBubble(msg.text, isMe, msg.timestamp);
                  },
                );
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Dermaly AI is typing...', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Stream<List<ChatMessage>> _getPeerMessages() {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => ChatMessage.fromMap(doc.data())).toList());
  }

  Widget _buildChatBubble(String text, bool isMe, DateTime time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.terracotta : AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(isMe ? 15 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 15),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: isMe ? Colors.white : AppColors.darkPurple, fontSize: 15)),
            const SizedBox(height: 4),
            Text(DateFormat('HH:mm').format(time), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.softGrey))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                fillColor: AppColors.softPurple,
                filled: true,
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: AppColors.primaryPurple),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    // Bloquer le double envoi pendant que l'IA répond
    if (text.isEmpty || _isTyping) return;
    _messageController.clear();

    if (widget.isAi) {
      setState(() => _isTyping = true);
      try {
        await _chatService.sendMessage(text);
      } catch (e) {
        // L'erreur est montrée à l'utilisateur, pas enregistrée comme une réponse de l'IA
        debugPrint('Erreur chat: $e');
        if (mounted) {
          final message = e.toString().replaceAll('Exception: ', '');
          // Surcharge passagère de l'IA : le message se suffit à lui-même
          final busy = e is GeminiException && e.isTransient;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(busy ? message : 'Dermaly AI could not answer: $message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isTyping = false);
      }
    } else {
      final String peerId = widget.peerId!;

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
            'text': text,
            'sender': 'user',
            'senderId': _myId,
            'timestamp': FieldValue.serverTimestamp(),
          });
          
      // Update last message in chat room metadata (optional)
      await FirebaseFirestore.instance.collection('chats').doc(_chatId).set({
        'lastMessage': text,
        'timestamp': FieldValue.serverTimestamp(),
        'participants': [_myId, peerId],
      }, SetOptions(merge: true));
    }
  }
}
