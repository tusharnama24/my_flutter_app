import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class UploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadPostImage({
    required File imageFile,
    required String uid,
    required String postId,
  }) async {
    final ref = _storage.ref('users/$uid/posts/$postId.jpg');
    await ref.putFile(imageFile);
    return ref.getDownloadURL();
  }

  Future<String> uploadProfileImage({
    required File imageFile,
    required String uid,
  }) async {
    final ref = _storage.ref('users/$uid/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(imageFile);
    return ref.getDownloadURL();
  }
}
