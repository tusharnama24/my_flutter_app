import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:halo/utils/reel_ranking.dart';

class ReelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  /// Last 100 reels ordered by createdAt descending.
  Stream<QuerySnapshot<Map<String, dynamic>>> getRecentReels() {
    return _firestore
        .collection('reels')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Stream of reels ranked by reelScore, with top 10% lightly shuffled.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getRankedReelsStream() {
    return getRecentReels().map((snapshot) {
      final docs = snapshot.docs;
      if (docs.isEmpty) return <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      final scored = <_ScoredReel>[];
      for (final doc in docs) {
        final d = doc.data();
        final createdAt = (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        final durationSeconds = (d['durationSeconds'] as int?) ?? 1;
        final views = (d['views'] as int?) ?? 0;
        final totalWatchTime = (d['totalWatchTime'] as int?) ?? 0;
        final replayCount = (d['replayCount'] as int?) ?? 0;
        final completedViews = (d['completedViews'] as int?) ??
            (views > 0 && durationSeconds > 0
                ? (totalWatchTime / durationSeconds).round().clamp(0, views)
                : 0);
        final likes = (d['likes'] as int?) ?? 0;
        final comments = (d['comments'] as int?) ?? 0;
        final shares = (d['shares'] as int?) ?? 0;

        final score = reelScore(
          totalWatchTime: totalWatchTime,
          views: views,
          durationSeconds: durationSeconds,
          completedViews: completedViews,
          replayCount: replayCount,
          likes: likes,
          comments: comments,
          shares: shares,
          createdAt: createdAt,
        );
        scored.add(_ScoredReel(doc: doc, score: score));
      }

      scored.sort((a, b) => b.score.compareTo(a.score));
      var list = scored.map((e) => e.doc).toList();

      final topCount = (list.length * 0.1).ceil().clamp(0, list.length);
      if (topCount > 1) {
        final top = list.sublist(0, topCount)..shuffle(_random);
        final rest = list.sublist(topCount);
        list = [...top, ...rest];
      }

      return list;
    });
  }
}

class _ScoredReel {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final double score;
  _ScoredReel({required this.doc, required this.score});
}
