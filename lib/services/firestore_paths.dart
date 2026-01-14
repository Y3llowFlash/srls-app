import 'package:cloud_firestore/cloud_firestore.dart';

class FsPaths {
  static final db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> courses() =>
      db.collection('courses');

  static CollectionReference<Map<String, dynamic>> modules(String courseId) =>
      courses().doc(courseId).collection('modules');

  static CollectionReference<Map<String, dynamic>> topics(
    String courseId,
    String moduleId,
  ) =>
      modules(courseId).doc(moduleId).collection('topics');

  

}
