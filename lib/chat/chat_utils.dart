// lib/chat/chat_utils.dart
import 'package:cloud_firestore/cloud_firestore.dart';

String chatIdFromUids(String a, String b) {
  final list = [a, b]..sort();
  return '${list[0]}_${list[1]}';
}

Future<void> ensureChatExists(String chatId, List<String> users) async {
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
  final doc = await chatRef.get();
  if (!doc.exists) {
    await chatRef.set({
      'users': users,
      'lastMessage': '',
      'lastMessageSenderId': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'typing': {},
    });
  }
}

Future<String> createChatIfNotExists(String uidA, String uidB) async {
  final chatId = chatIdFromUids(uidA, uidB);
  final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
  final doc = await chatRef.get();
  if (!doc.exists) {
    await chatRef.set({
      'users': [uidA, uidB],
      'lastMessage': '',
      'lastMessageSenderId': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'typing': {},
    });
  }
  return chatId;
}
