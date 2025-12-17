import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'chat_service.dart';
import 'message_bubble.dart';

// Halo chat theme colors (same as we used elsewhere)
const Color kPrimaryColor = Color(0xFFA58CE3); // Lavender
const Color kSecondaryColor = Color(0xFF5B3FA3); // Deep Purple
const Color kBackgroundColor = Color(0xFFF4F1FB); // Light lavender-gray;

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  final String otherUserId;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.currentUserId,
    required this.otherUserId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _controller = TextEditingController();

  Timer? _presenceTimer;
  Timer? _typingClearTimer;

  @override
  void initState() {
    super.initState();
    // Mark messages as seen when entering the chat
    _chatService.markMessagesAsSeen(widget.chatId, widget.currentUserId);
    _startPresenceHeartbeat();
  }

  void _startPresenceHeartbeat() {
    // Initial write
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    // Update every 60 seconds
    _presenceTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }

  Future<void> _updateTypingStatus(String value) async {
    final trimmed = value.trim();
    final docRef =
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId);

    if (trimmed.isNotEmpty) {
      // user is typing
      await docRef.set(
        {'typingUserId': widget.currentUserId},
        SetOptions(merge: true),
      );
      // auto clear after 5s of no changes
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(seconds: 5), () async {
        await docRef.set({'typingUserId': null}, SetOptions(merge: true));
      });
    } else {
      // user cleared text
      _typingClearTimer?.cancel();
      await docRef.set({'typingUserId': null}, SetOptions(merge: true));
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await _chatService.sendMessage(
      widget.chatId,
      widget.currentUserId,
      widget.otherUserId,
      text,
    );

    _controller.clear();
    // also clear typing immediately
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .set({'typingUserId': null}, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    _typingClearTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      Theme.of(context).textTheme,
    );

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF5EDFF), Color(0xFFE8E4FF), kBackgroundColor],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _ChatHeader(
                  otherUserId: widget.otherUserId,
                ),
                const Divider(height: 1, thickness: 0.2),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _chatService.getMessages(widget.chatId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final messages = snapshot.data!.docs;

                      // Mark as seen whenever new messages arrive
                      _chatService.markMessagesAsSeen(
                        widget.chatId,
                        widget.currentUserId,
                      );

                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            'Say hi 👋',
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        reverse: true, // newest at bottom
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msgDoc = messages[index];
                          final msg = msgDoc.data();
                          final isMe =
                              msg['senderId'] == widget.currentUserId;

                          // Handle timestamp/createdAt
                          final ts = msg['createdAt'] ?? msg['timestamp'];
                          DateTime? createdAt;
                          if (ts is Timestamp) {
                            createdAt = ts.toDate().toLocal();
                          }

                          final seen = (msg['seen'] as bool?) ?? false;
                          final delivered =
                              (msg['delivered'] as bool?) ?? false;
                          final messageType =
                          (msg['type'] ?? 'text').toString();
                          final metadata =
                              (msg['metadata'] as Map<String, dynamic>?) ??
                                  {};
                          final isDeleted =
                              (msg['deleted'] as bool?) ?? false;
                          final isEdited =
                              (msg['edited'] as bool?) ?? false;
                          final isForwarded =
                              (msg['forwarded'] as bool?) ?? false;
                          final reactions =
                              (msg['reactions'] as Map<String, dynamic>?) ??
                                  {};

                          // Date separator logic
                          bool showDateHeader = false;
                          String dateLabel = '';
                          if (createdAt != null) {
                            if (index == 0) {
                              showDateHeader = true;
                            } else {
                              final prevMsg = messages[index - 1].data();
                              final prevTs =
                                  prevMsg['createdAt'] ?? prevMsg['timestamp'];
                              DateTime? prevDate;
                              if (prevTs is Timestamp) {
                                prevDate = prevTs.toDate().toLocal();
                              }
                              if (prevDate != null &&
                                  !_isSameDay(createdAt, prevDate)) {
                                showDateHeader = true;
                              }
                            }

                            if (showDateHeader) {
                              dateLabel = _formatDateLabel(createdAt);
                            }
                          }

                          return Column(
                            children: [
                              if (showDateHeader)
                                _DateSeparator(label: dateLabel),
                              MessageBubble(
                                isMe: isMe,
                                text: (msg['text'] ?? '').toString(),
                                timestamp: createdAt,
                                seen: seen,
                                delivered: delivered,
                                messageType: messageType,
                                metadata: metadata,
                                isDeleted: isDeleted,
                                isEdited: isEdited,
                                isForwarded: isForwarded,
                                // For now we don't resolve original message text, so null:
                                replyPreviewText: null,
                                reactions: reactions,
                                onLongPress: () {
                                  // TODO: show bottom sheet for reply/copy/delete/star/react
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Long-press actions coming soon'),
                                    ),
                                  );
                                },
                                onTap: () {
                                  // Future: open media, show message info, etc.
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),

                // Typing indicator for OTHER user
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }
                    final data = snapshot.data!.data();
                    final typingUserId =
                    (data?['typingUserId'] ?? '').toString();
                    final isOtherTyping =
                        typingUserId == widget.otherUserId;

                    if (!isOtherTyping) {
                      return const SizedBox(height: 4);
                    }

                    return const Padding(
                      padding: EdgeInsets.only(
                        left: 70.0,
                        bottom: 4,
                        top: 0,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _TypingDots(),
                      ),
                    );
                  },
                ),

                _InputBar(
                  controller: _controller,
                  onSend: _sendMessage,
                  onChanged: _updateTypingStatus,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// HEADER

class _ChatHeader extends StatelessWidget {
  final String otherUserId;

  const _ChatHeader({
    required this.otherUserId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kSecondaryColor, kPrimaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 64,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .snapshots(),
        builder: (context, snapshot) {
          Widget content;

          if (snapshot.connectionState == ConnectionState.waiting) {
            content = Row(
              children: const [
                BackButton(color: Colors.white),
                SizedBox(width: 6),
                CircleAvatar(
                  radius: 18,
                  backgroundImage:
                  AssetImage('assets/images/Profile.png'),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loading...',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          } else {
            final data = snapshot.data?.data();
            final name = (data?['name'] ??
                data?['username'] ??
                'Unknown User')
                .toString();
            final avatarUrl = (data?['photoURL'] ?? '').toString();
            DateTime? lastSeen;
            if (data?['lastSeen'] != null &&
                data!['lastSeen'] is Timestamp) {
              lastSeen = (data['lastSeen'] as Timestamp).toDate();
            }
            final isOnline = lastSeen != null &&
                DateTime.now().difference(lastSeen).inMinutes < 2;
            final statusText = isOnline
                ? 'Online'
                : (lastSeen != null
                ? 'Last seen ${_formatAgo(lastSeen)}'
                : 'Offline');

            content = Row(
              children: [
                const BackButton(color: Colors.white),
                const SizedBox(width: 2),
                CircleAvatar(
                  radius: 18,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('assets/images/Profile.png')
                  as ImageProvider,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 18, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: isOnline ? Colors.greenAccent : Colors.grey,
                            size: 9,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              statusText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onPressed: () {
                    // TODO: chat info / more options
                  },
                ),
              ],
            );
          }

          return content;
        },
      ),
    );
  }
}

/// DATE FORMAT HELPERS

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatDateLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dt.year, dt.month, dt.day);

  if (date == today) {
    return 'Today';
  } else if (today.difference(date).inDays == 1) {
    return 'Yesterday';
  } else {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    return '$dd/$mm/$yy';
  }
}

String _formatAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

/// DATE SEPARATOR

class _DateSeparator extends StatelessWidget {
  final String label;

  const _DateSeparator({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: Row(
        children: [
          const Expanded(
            child: Divider(thickness: 0.7),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey[800],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(thickness: 0.7),
          ),
        ],
      ),
    );
  }
}

/// TYPING INDICATOR

class _TypingDots extends StatelessWidget {
  const _TypingDots();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            spreadRadius: -3,
            offset: const Offset(0, 3),
            color: Colors.black.withOpacity(0.1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          _Dot(),
          SizedBox(width: 4),
          _Dot(),
          SizedBox(width: 4),
          _Dot(),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// INPUT BAR

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            offset: const Offset(0, -2),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                // TODO: camera attachment
              },
              icon: const Icon(Icons.camera_alt_outlined),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  onChanged: onChanged,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Message...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                // TODO: voice note
              },
              icon: const Icon(Icons.mic_none),
            ),
            IconButton(
              onPressed: () {
                // TODO: gallery picker
              },
              icon: const Icon(Icons.image_outlined),
            ),
            IconButton(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
