import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

Future<String> uploadPostImage({
  required File imageFile,
  required String uid,
  required String postId,
}) async {
  final ref = FirebaseStorage.instance
      .ref('users/$uid/posts/$postId.jpg');

  await ref.putFile(imageFile);
  return await ref.getDownloadURL();
}
