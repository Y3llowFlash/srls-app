import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/review_queue_item.dart';
import 'firestore_paths.dart';

class ReviewQueueService {
  Stream<List<ReviewQueueItem>> watchDueReviews({
    required String uid,
    String? type,        // "note" | "question" | null
    String? courseId,
    String? moduleId,
    String? topicId,
    int limit = 50,
  }) {
    final now = Timestamp.now();

    Query<Map<String, dynamic>> q = FsPaths.userSrs(uid)
        .where('dueAt', isLessThanOrEqualTo: now)
        .orderBy('dueAt')
        .limit(limit);

    if (type != null) {
      q = q.where('type', isEqualTo: type);
    }

    if (courseId != null) {
      q = q.where('courseId', isEqualTo: courseId);
    }

    if (moduleId != null) {
      q = q.where('moduleId', isEqualTo: moduleId);
    }

    if (topicId != null) {
      q = q.where('topicId', isEqualTo: topicId);
    }

    return q.snapshots().map(
      (snap) => snap.docs.map((d) => ReviewQueueItem.fromDoc(d)).toList(),
    );
  }
}
