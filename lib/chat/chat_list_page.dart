import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_service.dart';
import 'chat_screen.dart';
import 'user_list_page.dart';
import 'package:classic_1/Bottom%20Pages/HomePage.dart';

class ChatListPage extends StatefulWidget {
  final String currentUserId; // logged-in userId

  const ChatListPage({Key? key, required this.currentUserId}) : super(key: key);

  @override
  _ChatListPageState createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatService _chatService = ChatService();

  /// 🔹 Helper: get user info from users collection
  Future<Map<String, dynamic>?> _getUserData(String userId) async {
    try {
      final doc =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print("❌ Error fetching user data: $e");
    }
    return null;
  }

  /// 🔹 Helper: get unread count for a chat
  Stream<int> _getUnreadCount(String chatId) {
    return FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: widget.currentUserId)
        .where('seen', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chats"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomePage()),
            );
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatService.getUserChats(widget.currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No chats yet."));
          }

          // Sort client-side by updatedAt desc, with nulls last
          final chats = [...snapshot.data!.docs];
          chats.sort((a, b) {
            final aTs = (a.data()['updatedAt'] as Timestamp?);
            final bTs = (b.data()['updatedAt'] as Timestamp?);
            final aMs = aTs?.millisecondsSinceEpoch ?? 0;
            final bMs = bTs?.millisecondsSinceEpoch ?? 0;
            return bMs.compareTo(aMs);
          });

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index].data();
              final chatId = chats[index].id;
              final members = List<String>.from(chat['members']);

              // find the other user
              final otherUserId = members.firstWhere(
                    (id) => id != widget.currentUserId,
                orElse: () => "Unknown",
              );

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUserData(otherUserId),
                builder: (context, userSnapshot) {
                  final otherUser = userSnapshot.data;

                  return StreamBuilder<int>(
                    stream: _getUnreadCount(chatId),
                    builder: (context, unreadSnapshot) {
                      final unreadCount = unreadSnapshot.data ?? 0;

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(otherUser?['name'] ?? "User $otherUserId"),
                        subtitle: Text(
                          chat['lastMessage'] ?? '',
                          style: TextStyle(
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: unreadCount > 0
                                ? Colors.black
                                : Colors.grey[700],
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              chat['updatedAt'] != null
                                  ? (chat['updatedAt'] as Timestamp)
                                  .toDate()
                                  .toLocal()
                                  .toString()
                                  .substring(0, 16)
                                  : "",
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.teal,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  "$unreadCount",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: chatId,
                                currentUserId: widget.currentUserId,
                                otherUserId: otherUserId,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),

      // 👇 Floating button to go to UserListPage
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.chat),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserListPage(currentUserId: widget.currentUserId),
            ),
          );
        },
      ),
    );
  }
}
