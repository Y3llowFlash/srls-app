import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/topic_model.dart';
import 'firestore_paths.dart';
import 'srs_service.dart';

class TopicService {

  final _srs = SrsService();

  Stream<List<TopicModel>> watchTopics(String courseId, String moduleId) {
    return FsPaths.topics(courseId, moduleId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TopicModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<void> addTopic({
    required String courseId,
    required String moduleId,
    required String title,
    required String notes,
    String? videoUrl,
  }) async {
    final now = FieldValue.serverTimestamp();

    await FsPaths.topics(courseId, moduleId).add({
      'title': title,
      'notes': notes,
      'videoUrl': (videoUrl == null || videoUrl.trim().isEmpty) ? null : videoUrl.trim(),
      'isStarredNote': false,
      'createdAt': now,
      'updatedAt': now,
    });
  }

  Future<void> deleteTopic({
    required String courseId,
    required String moduleId,
    required String topicId,
  }) async {
    // 1) delete topic doc
    await FsPaths.topics(courseId, moduleId).doc(topicId).delete();

    // 2) delete SRS note doc (cleanup)
    await _srs.deleteNoteSrs(topicId);
  }



  Future<void> setStarNote({
    required String courseId,
    required String moduleId,
    required String topicId,
    required bool starred,
  }) async {
    // 1) Update topic doc
    await FsPaths.topics(courseId, moduleId).doc(topicId).update({
      'isStarredNote': starred,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2) If starring, ensure SRS doc exists
    if (starred) {
      await _srs.ensureNoteSrs(
        courseId: courseId,
        moduleId: moduleId,
        topicId: topicId,
        isStarred: true,
      );
    }

    // 3) ALWAYS update SRS starred flag (true OR false)
    await _srs.setNoteSrsStarred(
      topicId: topicId,
      starred: starred,
    );
  }


}
