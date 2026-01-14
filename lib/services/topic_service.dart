import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/topic_model.dart';
import 'firestore_paths.dart';

class TopicService {
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

  Future<void> setStarNote({
    required String courseId,
    required String moduleId,
    required String topicId,
    required bool starred,
  }) async {
    await FsPaths.topics(courseId, moduleId).doc(topicId).update({
      'isStarredNote': starred,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

}
