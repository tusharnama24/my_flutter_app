import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/story_model.dart';

class StoryService {
  Stream<List<StoryModel>> fetchStories() {
    final yesterday = DateTime.now().subtract(
      const Duration(hours: 24),
    );

    return FirebaseFirestore.instance
        .collection('stories')
        .where(
      'createdAt',
      isGreaterThan: Timestamp.fromDate(yesterday),
    )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
          .map((doc) {
        try {
          return StoryModel.fromDoc(doc);
        } catch (_) {
          return null;
        }
      })
          .whereType<StoryModel>()
          .toList(),
    );
  }
}
