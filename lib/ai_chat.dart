import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'app_colors.dart';
import 'models/chat_message.dart';
import 'services/chat_service.dart';

class ClientChatListPage extends StatefulWidget {
  const ClientChatListPage({super.key});

  @override
  State<ClientChatListPage> createState() => _ClientChatListPageState();
}

class _ClientChatListPageState extends State<ClientChatListPage> {
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
      body: Column(
        children: [
          // AI Assistant Option
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
          // Dermatologists List (Simplified: fetching all available doctors)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'dermatologist')
                  .where('status', isEqualTo: 'accepted')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final doctors = snapshot.data!.docs;

                if (doctors.isEmpty) {
                  return const Center(child: Text('No verified dermatologists available yet.', style: TextStyle(color: AppColors.greyText)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    final data = doctors[index].data() as Map<String, dynamic>;
                    return _buildChatTile(
                      name: 'Dr. ${data['fullName'] ?? 'Expert'}',
                      subtitle: 'Clinical Dermatology',
                      photoUrl: data['photoUrl'],
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailedChatPage(
                              isAi: false,
                              peerId: data['uid'],
                              peerName: 'Dr. ${data['fullName']}',
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile({
    required String name,
    required String subtitle,
    String? photoUrl,
    bool isAi = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAi ? AppColors.softPurple : AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.softGrey),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: isAi ? AppColors.primaryPurple : AppColors.lightPurple,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
          child: photoUrl == null 
              ? Icon(isAi ? Icons.auto_awesome : Icons.person, color: Colors.white)
              : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.greyText)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.softGrey),
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
  bool _isTyping = false;

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
              stream: widget.isAi ? _chatService.getMessages() : _getPeerMessages(),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    // Logic to determine if message is from the current user
                    final String myId = FirebaseAuth.instance.currentUser?.uid ?? '';
                    bool isMe = msg.sender == MessageSender.user;
                    
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
    final String myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final String peerId = widget.peerId!;
    final String chatId = myId.compareTo(peerId) < 0 ? '${myId}_$peerId' : '${peerId}_$myId';

    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
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
    if (text.isEmpty) return;
    _messageController.clear();

    if (widget.isAi) {
      setState(() => _isTyping = true);
      await _chatService.sendMessage(text);
      setState(() => _isTyping = false);
    } else {
      final String myId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final String peerId = widget.peerId!;
      final String chatId = myId.compareTo(peerId) < 0 ? '${myId}_$peerId' : '${peerId}_$myId';

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
            'text': text,
            'sender': 'user',
            'timestamp': FieldValue.serverTimestamp(),
          });
          
      // Update last message in chat room metadata (optional)
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'lastMessage': text,
        'timestamp': FieldValue.serverTimestamp(),
        'participants': [myId, peerId],
      }, SetOptions(merge: true));
    }
  }
}
