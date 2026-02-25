import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/models/story_model.dart';
import 'package:halo/utils/story_utils.dart';
import 'package:halo/utils/story_ranking.dart';

/// Result of ranking: ordered user ids (current user first) and grouped stories.
class RankedStoriesResult {
  final List<String> orderedUserIds;
  final Map<String, List<StoryModel>> grouped;

  const RankedStoriesResult({
    required this.orderedUserIds,
    required this.grouped,
  });
}

class StoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Existing stream: last 24h by createdAt (unchanged for backward compatibility).
  Stream<List<StoryModel>> fetchStories() {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    return _firestore
        .collection('stories')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                return StoryModel.fromDoc(doc);
              } catch (_) {
                return null;
              }
            })
            .whereType<StoryModel>()
            .toList());
  }

  /// Active stories: expiresAt > now, sorted by createdAt descending (client sort).
  Stream<List<StoryModel>> fetchActiveStories() {
    final now = DateTime.now();
    return _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) {
                try {
                  return StoryModel.fromDoc(doc);
                } catch (_) {
                  return null;
                }
              })
              .whereType<StoryModel>()
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Relationship doc id: currentUser_otherUser. Returns score 0.0–1.0 per userId.
  Future<Map<String, double>> getRelationshipScores(
    String currentUserId,
    List<String> userIds,
  ) async {
    if (currentUserId.isEmpty) return {};
    final map = <String, double>{};
    for (final otherId in userIds) {
      if (otherId.isEmpty) continue;
      if (otherId == currentUserId) {
        map[otherId] = 1.0;
        continue;
      }
      try {
        final doc = await _firestore
            .collection('relationships')
            .doc('${currentUserId}_$otherId')
            .get();
        final score = (doc.data()?['score'] as num?)?.toDouble();
        map[otherId] = (score ?? 0.0).clamp(0.0, 1.0);
      } catch (_) {
        map[otherId] = 0.0;
      }
    }
    return map;
  }

  /// Stream of ranked stories: current user first, then others by storyScore desc.
  Stream<RankedStoriesResult> fetchStoriesRanked(String myUid) {
    return fetchActiveStories().asyncMap((stories) async {
      final grouped = groupStoriesByUser(stories);
      final userIds = grouped.keys.where((id) => id.isNotEmpty).toList();
      final relScores = await getRelationshipScores(myUid, userIds);

      final scored = <_ScoredUser>[];
      for (final uid in userIds) {
        final list = grouped[uid]!;
        if (list.isEmpty) continue;
        final newest = list.reduce(
            (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
        final allViewers = list.expand((s) => s.viewers).toSet().toList();
        final score = storyScore(
          createdAt: newest.createdAt,
          viewers: allViewers,
          relationshipScore: relScores[uid] ?? 0.0,
          currentUserId: myUid,
        );
        scored.add(_ScoredUser(uid: uid, score: score));
      }

      scored.sort((a, b) => b.score.compareTo(a.score));
      final ordered =
          scored.map((e) => e.uid).toList();
      if (ordered.contains(myUid)) {
        ordered.remove(myUid);
        ordered.insert(0, myUid);
      }
      return RankedStoriesResult(
        orderedUserIds: ordered,
        grouped: grouped,
      );
    });
  }
}

class _ScoredUser {
  final String uid;
  final double score;
  _ScoredUser({required this.uid, required this.score});
}
