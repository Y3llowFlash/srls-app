import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/topic_model.dart';
import 'firestore_paths.dart';

class TopicService {
  /// Watch topics in a module
  Stream<List<TopicModel>> watchTopics(String courseId, String moduleId) {
    return FsPaths.topics(courseId, moduleId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => TopicModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// ✅ This matches your ModuleScreen usage
  Future<void> addTopic({
    required String courseId,
    required String moduleId,
    required String title,
    String? notes,
    String? videoUrl,
  }) async {
    await FsPaths.topics(courseId, moduleId).add({
      'title': title,
      'notes': notes ?? '',
      'videoUrl': videoUrl ?? '',
      'isStarredNote': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle starred note flag on a topic
  Future<void> setStarNote({
    required String courseId,
    required String moduleId,
    required String topicId,
    required bool starred,
  }) async {
    await FsPaths.topics(courseId, moduleId).doc(topicId).set(
      {
        'isStarredNote': starred,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// (Optional) Update notes/video/title
  Future<void> updateTopic({
    required String courseId,
    required String moduleId,
    required String topicId,
    String? title,
    String? notes,
    String? videoUrl,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (title != null) data['title'] = title;
    if (notes != null) data['notes'] = notes;
    if (videoUrl != null) data['videoUrl'] = videoUrl;

    await FsPaths.topics(courseId, moduleId).doc(topicId).set(
      data,
      SetOptions(merge: true),
    );
  }
}
