import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/utils/feed_ranking.dart';

/// Fetches recent posts and exposes a stream of ranked posts for the feed.
class FeedService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Last 50 posts ordered by createdAt descending.
  Stream<QuerySnapshot<Map<String, dynamic>>> getRecentPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  /// Stream of ranked posts (client-side ranking). Use this for the home feed.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getRankedFeedStream({
    required String currentUserId,
    required String userPreference,
  }) {
    return getRecentPosts().asyncMap((snapshot) => rankPosts(
          snapshot: snapshot,
          currentUserId: currentUserId,
          userPreference: userPreference,
        ));
  }

  /// Relationship doc id: currentUser_postUser (order arbitrary but consistent).
  Future<Map<String, double>> getRelationshipScores(
    String currentUserId,
    List<String> postUserIds,
  ) async {
    if (currentUserId.isEmpty) return {};
    final unique = postUserIds.where((id) => id.isNotEmpty).toSet().toList();
    final map = <String, double>{};
    for (final otherId in unique) {
      if (otherId == currentUserId) {
        map[otherId] = 1.0;
        continue;
      }
      final docId = '${currentUserId}_$otherId';
      try {
        final doc = await _firestore.collection('relationships').doc(docId).get();
        final score = (doc.data()?['score'] as num?)?.toDouble();
        map[otherId] = (score ?? 0.0).clamp(0.0, 1.0);
      } catch (_) {
        map[otherId] = 0.0;
      }
    }
    return map;
  }

  /// Converts snapshot to ranked list using feedScore. Runs ranking on client.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> rankPosts({
    required QuerySnapshot<Map<String, dynamic>> snapshot,
    required String currentUserId,
    required String userPreference,
  }) async {
    final docs = snapshot.docs;
    if (docs.isEmpty) return [];

    final userIds = docs
        .map((d) => (d.data()['userId'] as String?) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final relScores = await getRelationshipScores(currentUserId, userIds);

    final scored = <_ScoredDoc>[];
    for (final doc in docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] ?? data['timestamp']) as Timestamp?;
      final dt = createdAt?.toDate() ?? DateTime.now();
      final userId = (data['userId'] as String?) ?? '';
      final likes = (data['likesCount'] as int?) ?? 0;
      final comments = (data['commentsCount'] as int?) ?? 0;
      final saves = (data['savesCount'] as int?) ?? 0;
      final type = (data['type'] as String?) ?? _inferPostType(data);

      final score = feedScore(
        createdAt: dt,
        relationshipScore: relScores[userId] ?? 0.0,
        likes: likes,
        comments: comments,
        saves: saves,
        postType: type,
        userPreference: userPreference,
      );
      scored.add(_ScoredDoc(doc: doc, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.doc).toList();
  }

  /// Infer "image" vs "video" from media when type is missing.
  String _inferPostType(Map<String, dynamic> data) {
    final String? type =
    (data['type'] as String?)?.toLowerCase();

    if (type == 'video') return 'video';
    if (type == 'image') return 'image';

    final media = data['media'] as List?;
    if (media != null && media.isNotEmpty) {
      final first = media.first;
      if (first is Map &&
          (first['type'] ?? '')
              .toString()
              .toLowerCase() ==
              'video') {
        return 'video';
      }
    }

    return 'image';
  }

}

class _ScoredDoc {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final double score;
  _ScoredDoc({required this.doc, required this.score});
}
