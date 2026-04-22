import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/models/post_model.dart';
import 'package:halo/models/user_model.dart';

class ProfileRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<UserModel?> watchUser(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<List<PostModel>> fetchUserPosts({
    required String userId,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 18,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.get();
    return snap.docs.map((d) => PostModel.fromMap(d.id, d.data())).toList();
  }
}
