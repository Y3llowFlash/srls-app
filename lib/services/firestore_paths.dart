import 'package:cloud_firestore/cloud_firestore.dart';

class FsPaths {
  static final db = FirebaseFirestore.instance;

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
}
