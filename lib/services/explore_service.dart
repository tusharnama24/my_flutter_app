import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/utils/explore_ranking.dart';

class ExploreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Posts from last 3 days, ordered by createdAt descending, limit 200.
  Stream<QuerySnapshot<Map<String, dynamic>>> getRecentPosts() {
    final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
    return _firestore
        .collection('posts')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(threeDaysAgo))
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();
  }

  /// User IDs that the current user follows.
  Future<List<String>> getFollowingIds(String currentUserId) async {
    if (currentUserId.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection('follows')
          .where('followerId', isEqualTo: currentUserId)
          .get();
      return snap.docs
          .map((d) => (d.data()['followingId'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Current user's interests from user_interests collection.
  Future<List<String>> getUserInterests(String currentUserId) async {
    if (currentUserId.isEmpty) return [];
    try {
      final snap = await _firestore
          .collection('user_interests')
          .where('userId', isEqualTo: currentUserId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return [];
      final list = snap.docs.first.data()['interests'];
      if (list is! List) return [];
      return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// Explore feed: exclude followed users, rank by exploreScore, diversity (max 2 per user).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getExplorePostsStream(String currentUserId) {
    return getRecentPosts().asyncMap((snapshot) async {
      final following = await getFollowingIds(currentUserId);
      final followingSet = following.toSet();
      var docs = snapshot.docs
          .where((d) => !followingSet.contains((d.data()['userId'] as String?) ?? ''))
          .toList();

      final userInterests = await getUserInterests(currentUserId);

      final scored = <_ScoredPost>[];
      for (final doc in docs) {
        final d = doc.data();
        final tags = (d['tags'] as List?)?.map((e) => e.toString()).where((s) => s.isNotEmpty).toList() ?? [];
        final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final likes = (d['likesCount'] as int?) ?? 0;
        final comments = (d['commentsCount'] as int?) ?? 0;
        final saves = (d['savesCount'] as int?) ?? 0;
        final score = exploreScore(
          postTags: tags,
          userInterests: userInterests,
          likes: likes,
          comments: comments,
          saves: saves,
          createdAt: createdAt,
        );
        scored.add(_ScoredPost(doc: doc, score: score));
      }

      scored.sort((a, b) => b.score.compareTo(a.score));

      final perUserCount = <String, int>{};
      const maxPerUser = 2;
      final result = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final s in scored) {
        final uid = (s.doc.data()['userId'] as String?) ?? '';
        if ((perUserCount[uid] ?? 0) >= maxPerUser) continue;
        perUserCount[uid] = (perUserCount[uid] ?? 0) + 1;
        result.add(s.doc);
      }

      return result;
    });
  }
}

class _ScoredPost {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final double score;
  _ScoredPost({required this.doc, required this.score});
}
