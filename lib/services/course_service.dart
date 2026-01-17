import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseService {
  final _db = FirebaseFirestore.instance;

  // -----------------------------
  // Create Course
  // -----------------------------
  Future<DocumentReference<Map<String, dynamic>>> createCourse({
    required String title,
    required String description,
    required String visibility, // "public" | "private"
    required bool duplicable,
    required String courseCode,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final code = courseCode.trim().toUpperCase();

    final courseRef = await _db.collection('courses').add({
      'title': title,
      'description': description,
      'creatorId': uid,
      'visibility': visibility,
      'duplicable': duplicable,
      'courseCode': code,
      'isClone': false,
      'clonedFromCourseId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // ✅ create / update invite
    await _db.collection('courseInvites').doc(code).set({
      'courseId': courseRef.id,
      'visibility': visibility,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return courseRef;
  }

  // -----------------------------
  // Join Course by Code
  // -----------------------------
  Future<void> joinCourseByCode(String inputCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');

    final uid = user.uid;
    final code = inputCode.trim().toUpperCase();

    if (code.isEmpty) {
      throw Exception('Course code required');
    }

    // 1️⃣ lookup invite
    final inviteSnap =
        await _db.collection('courseInvites').doc(code).get();

    if (!inviteSnap.exists) {
      throw Exception('Invalid course code');
    }

    final invite = inviteSnap.data()!;
    final courseId = invite['courseId'] as String;
    final visibility = invite['visibility'] as String;

    // 2️⃣ PUBLIC → instant join
    if (visibility == 'public') {
      final batch = _db.batch();

      batch.set(
        _db.collection('courses').doc(courseId).collection('members').doc(uid),
        {
          'role': 'student',
          'joinedAt': FieldValue.serverTimestamp(),
        },
      );

      batch.set(
        _db
            .collection('users')
            .doc(uid)
            .collection('courseMemberships')
            .doc(courseId),
        {
          'role': 'student',
          'joinedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
      return;
    }

    // 3️⃣ PRIVATE → create / overwrite join request
    await _db
        .collection('courses')
        .doc(courseId)
        .collection('joinRequests')
        .doc(uid)
        .set({
      'uid': uid,
      'email': user.email,
      'displayName': user.displayName ?? '',
      'requestedAt': FieldValue.serverTimestamp(),
    });

    // no membership yet
  }
}
