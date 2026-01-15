import 'package:cloud_firestore/cloud_firestore.dart';

class FsPaths {
  static final db = FirebaseFirestore.instance;

  // -----------------------------
  // Content hierarchy (existing)
  // -----------------------------
  static CollectionReference<Map<String, dynamic>> courses() =>
      db.collection('courses');

  static DocumentReference<Map<String, dynamic>> courseDoc(String courseId) =>
      courses().doc(courseId);

  static CollectionReference<Map<String, dynamic>> modules(String courseId) =>
      courseDoc(courseId).collection('modules');

  static DocumentReference<Map<String, dynamic>> moduleDoc(
    String courseId,
    String moduleId,
  ) =>
      modules(courseId).doc(moduleId);

  static CollectionReference<Map<String, dynamic>> topics(
    String courseId,
    String moduleId,
  ) =>
      moduleDoc(courseId, moduleId).collection('topics');

  static DocumentReference<Map<String, dynamic>> topicDoc(
    String courseId,
    String moduleId,
    String topicId,
  ) =>
      topics(courseId, moduleId).doc(topicId);

  static CollectionReference<Map<String, dynamic>> questions(
    String courseId,
    String moduleId,
    String topicId,
  ) =>
      topicDoc(courseId, moduleId, topicId).collection('questions');

  static DocumentReference<Map<String, dynamic>> questionDoc(
    String courseId,
    String moduleId,
    String topicId,
    String questionId,
  ) =>
      questions(courseId, moduleId, topicId).doc(questionId);

  // -----------------------------
  // ✅ User SRS (NEW unified)
  // -----------------------------
  static DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      db.collection('users').doc(uid);

  static CollectionReference<Map<String, dynamic>> userSrs(String uid) =>
      userDoc(uid).collection('srs');

  /// Doc id format:
  /// - Note: n_{topicId}
  /// - Question: q_{questionId}
  static DocumentReference<Map<String, dynamic>> srsNoteDoc(
    String uid,
    String topicId,
  ) =>
      userSrs(uid).doc('n_$topicId');

  static DocumentReference<Map<String, dynamic>> srsQuestionDoc(
    String uid,
    String questionId,
  ) =>
      userSrs(uid).doc('q_$questionId');
}
