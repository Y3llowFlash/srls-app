import 'package:cloud_firestore/cloud_firestore.dart';

enum SrsKind { note, question }

class SrsItem {
  final String id; // topicId for note, questionId for question
  final SrsKind kind;

  // Context (so we can display content later)
  final String courseId;
  final String moduleId;
  final String topicId;
  final String? questionId; // only for question kind

  final bool isStarred; // snapshot (useful)
  final int reps; // successful reviews count
  final double easeFactor; // typically starts 2.5
  final int intervalDays; // current interval in days
  final Timestamp dueAt;

  SrsItem({
    required this.id,
    required this.kind,
    required this.courseId,
    required this.moduleId,
    required this.topicId,
    this.questionId,
    required this.isStarred,
    required this.reps,
    required this.easeFactor,
    required this.intervalDays,
    required this.dueAt,
  });

  factory SrsItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final kindStr = (d['kind'] ?? 'question') as String;

    return SrsItem(
      id: doc.id,
      kind: kindStr == 'note' ? SrsKind.note : SrsKind.question,
      courseId: (d['courseId'] ?? '') as String,
      moduleId: (d['moduleId'] ?? '') as String,
      topicId: (d['topicId'] ?? '') as String,
      questionId: d['questionId'] as String?,
      isStarred: (d['isStarred'] ?? true) as bool,
      reps: (d['reps'] ?? 0) as int,
      easeFactor: ((d['easeFactor'] ?? 2.5) as num).toDouble(),
      intervalDays: (d['intervalDays'] ?? 0) as int,
      dueAt: (d['dueAt'] as Timestamp?) ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMapForCreate() => {
        'kind': kind == SrsKind.note ? 'note' : 'question',
        'courseId': courseId,
        'moduleId': moduleId,
        'topicId': topicId,
        'questionId': questionId,
        'isStarred': isStarred,
        'reps': reps,
        'easeFactor': easeFactor,
        'intervalDays': intervalDays,
        'dueAt': dueAt,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
