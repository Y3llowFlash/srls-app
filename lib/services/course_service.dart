import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<DocumentReference<Map<String, dynamic>>> createCourse({
    required String title,
    required String description,
    required String visibility,
    required bool duplicable,
    required String courseCode,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return _db.collection('courses').add({
      'title': title,
      'description': description,
      'courseCode': courseCode,
      'creatorId': uid,
      'visibility': visibility, // "public" | "private"
      'duplicable': duplicable,
      'isClone': false,
      'clonedFromCourseId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
