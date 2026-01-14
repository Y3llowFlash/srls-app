import 'package:cloud_firestore/cloud_firestore.dart';

class FsPaths {
  static final db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> courses() =>
      db.collection('courses');

  static CollectionReference<Map<String, dynamic>> modules(String courseId) =>
      courses().doc(courseId).collection('modules');
}
