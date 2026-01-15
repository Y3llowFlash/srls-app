import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewQueueItem {
  final String id; // srs doc id (e.g., q_{questionId}, n_{topicId})
  final String type; // "question" | "note"
  final String refId; // questionId or topicId
  final String courseId;
  final String moduleId;
  final String topicId;

  final int reps;
  final double easeFactor;
  final int intervalDays;

  final DateTime dueAt;
  final DateTime? lastReviewedAt;

  ReviewQueueItem({
    required this.id,
    required this.type,
    required this.refId,
    required this.courseId,
    required this.moduleId,
    required this.topicId,
    required this.reps,
    required this.easeFactor,
    required this.intervalDays,
    required this.dueAt,
    required this.lastReviewedAt,
  });

  static DateTime _dt(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory ReviewQueueItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return ReviewQueueItem(
      id: doc.id,
      type: (m['type'] ?? '') as String,
      refId: (m['refId'] ?? '') as String,
      courseId: (m['courseId'] ?? '') as String,
      moduleId: (m['moduleId'] ?? '') as String,
      topicId: (m['topicId'] ?? '') as String,
      reps: (m['reps'] ?? 0) as int,
      easeFactor: ((m['easeFactor'] ?? 2.5) as num).toDouble(),
      intervalDays: (m['intervalDays'] ?? 0) as int,
      dueAt: _dt(m['dueAt']),
      lastReviewedAt: m['lastReviewedAt'] == null ? null : _dt(m['lastReviewedAt']),
    );
  }
}
  