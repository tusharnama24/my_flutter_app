import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();
  Timer? _presenceTimer;

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;

    _chatService.sendMessage(
      widget.chatId,
      widget.currentUserId,
      widget.otherUserId,
      _controller.text.trim(),
    );

    _controller.clear();
  }

  @override
  void initState() {
    super.initState();
    // Mark messages as seen when entering the chat
    _chatService.markMessagesAsSeen(widget.chatId, widget.currentUserId);
    _startPresenceHeartbeat();
  }

  void _startPresenceHeartbeat() {
    // initial write
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    _presenceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(otherUserId: widget.otherUserId),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _chatService.getMessages(widget.chatId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index].data();
                      final isMe = msg['senderId'] == widget.currentUserId;
                      return _MessageRow(
                        isMe: isMe,
                        text: msg['text'] ?? '',
                        avatarUrl: null,
                      );
                    },
                  );
                },
              ),
            ),
            // Optional typing indicator placeholder
            Padding(
              padding: const EdgeInsets.only(left: 60.0, bottom: 4, top: 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TypingDots(),
              ),
            ),
            _InputBar(
              controller: _controller,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }
}

class _ChatHeader extends StatelessWidget {
  final String otherUserId;

  const _ChatHeader({required this.otherUserId});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black, width: 2),
        ),
      ),
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(otherUserId).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final name = (data?['name'] ?? data?['username'] ?? otherUserId).toString();
          final avatarUrl = (data?['photoURL'] ?? '').toString();
          DateTime? lastSeen;
          if (data?['lastSeen'] != null && data!['lastSeen'] is Timestamp) {
            lastSeen = (data['lastSeen'] as Timestamp).toDate();
          }
          final isOnline = lastSeen != null && DateTime.now().difference(lastSeen).inMinutes < 2;
          final statusText = isOnline
              ? 'Online'
              : (lastSeen != null ? 'Last seen ${_formatAgo(lastSeen)}' : 'Offline');

          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : const AssetImage('assets/images/Profile.png') as ImageProvider,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.rubik(fontWeight: FontWeight.w600, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.circle, color: isOnline ? Colors.green : Colors.grey, size: 10),
                        const SizedBox(width: 4),
                        Text(statusText, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _formatAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

class _MessageRow extends StatelessWidget {
  final bool isMe;
  final String text;
  final String? avatarUrl;

  const _MessageRow({required this.isMe, required this.text, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.lightBlueAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );

    if (isMe) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            bubble,
            const SizedBox(width: 12),
            const _FloatingCircle(),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('assets/images/Profile.png'),
            ),
            const SizedBox(width: 8),
            bubble,
          ],
        ),
      );
    }
  }
}

class _TypingDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        _Dot(),
        SizedBox(width: 6),
        _Dot(),
        SizedBox(width: 6),
        _Dot(),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _FloatingCircle extends StatelessWidget {
  const _FloatingCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFFD9D9D9),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFE5E5E5),
      ),
      child: Row(
        children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.camera_alt_outlined)),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Message..',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.mic_none)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.image_outlined)),
          IconButton(onPressed: onSend, icon: const Icon(Icons.send)),
        ],
      ),
    );
  }
}
