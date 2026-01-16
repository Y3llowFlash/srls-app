import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/topic_model.dart';
import 'firestore_paths.dart';

class TopicService {
  /// Watch topics in a module
  Stream<List<TopicModel>> watchTopics(String courseId, String moduleId) {
    return FsPaths.topics(courseId, moduleId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TopicModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  /// ✅ Round 2: create topic with videoType + videoUrl
  /// videoType: "none" | "youtube" | "storage"
  /// videoUrl:
  ///   - youtube: full youtube link
  ///   - storage: firebase storage path like "videos/courseId/moduleId/topicId.mp4"
  ///   - none: empty string
  Future<void> addTopic({
    required String courseId,
    required String moduleId,
    required String title,
    String? notes,
    String videoType = 'none',
    String? videoUrl,
  }) async {
    final cleanType = (videoType.trim().isEmpty) ? 'none' : videoType.trim();
    final cleanUrl = (videoUrl ?? '').trim();

    await FsPaths.topics(courseId, moduleId).add({
      'title': title.trim(),
      'notes': (notes ?? '').trim(),

      // ✅ new fields
      'videoType': cleanType,
      'videoUrl': cleanUrl,

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

  /// ✅ Round 2: Update notes/video/title (+ videoType)
  /// Use this for edit later (Round 3)
  Future<void> updateTopic({
    required String courseId,
    required String moduleId,
    required String topicId,
    String? title,
    String? notes,
    String? videoType, // "none" | "youtube" | "storage"
    String? videoUrl,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) data['title'] = title.trim();
    if (notes != null) data['notes'] = notes.trim();

    if (videoType != null) data['videoType'] = videoType.trim();
    if (videoUrl != null) data['videoUrl'] = videoUrl.trim();

    await FsPaths.topics(courseId, moduleId).doc(topicId).set(
      data,
      SetOptions(merge: true),
    );
  }

  /// ✅ Utility: get topic doc reference (helps module_screen upload flow if needed)
  DocumentReference<Map<String, dynamic>> topicDocRef({
    required String courseId,
    required String moduleId,
    required String topicId,
  }) {
    return FsPaths.topics(courseId, moduleId).doc(topicId);
  }
}
