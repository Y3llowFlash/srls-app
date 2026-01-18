import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CourseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // -----------------------------
  // Update Course (creator-only via rules)
  // -----------------------------
  Future<void> updateCourse({
    required String courseId,
    String? title,
    String? description,
    String? visibility, // "public" | "private"
    bool? duplicable,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (visibility != null) data['visibility'] = visibility;
    if (duplicable != null) data['duplicable'] = duplicable;

    // Avoid empty updates that only touch timestamps if caller passed nothing.
    if (data.length == 1) return;

    await _db.collection('courses').doc(courseId).update(data);
  }

  // -----------------------------
  // Helpers
  // -----------------------------
  String _normalizeCourseId(dynamic raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) throw Exception('Invalid courseId in invite');

    final parts = s.split('/').where((p) => p.isNotEmpty).toList();
    return parts.isEmpty ? s : parts.last;
  }

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

    await _db.collection('courseInvites').doc(code).set({
      'courseId': courseRef.id, // store doc id only
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
    if (code.isEmpty) throw Exception('Course code required');

    final inviteSnap = await _db.collection('courseInvites').doc(code).get();
    if (!inviteSnap.exists) throw Exception('Invalid course code');

    final invite = inviteSnap.data()!;
    final courseId = _normalizeCourseId(invite['courseId']);
    final visibility = (invite['visibility'] ?? '').toString();

    // PUBLIC -> instant join
    if (visibility == 'public') {
      final batch = _db.batch();

      batch.set(
        _db.collection('courses').doc(courseId).collection('members').doc(uid),
        {
          'role': 'student',
          'displayName': user.displayName ?? '',
          'emailLower': (user.email ?? '').trim().toLowerCase(),
          'joinedAt': FieldValue.serverTimestamp(),
          'source': 'public',
        },
        SetOptions(merge: true),
      );

      batch.set(
        _db.collection('users').doc(uid).collection('courseMemberships').doc(courseId),
        {
          'role': 'student',
          'joinedAt': FieldValue.serverTimestamp(),
          'source': 'public',
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      return;
    }

    // PRIVATE -> join request
    await _db
        .collection('courses')
        .doc(courseId)
        .collection('joinRequests')
        .doc(uid)
        .set({
      'uid': uid,
      'email': (user.email ?? '').trim().toLowerCase(),
      'displayName': user.displayName ?? '',
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    }, SetOptions(merge: true));
  }

  // -----------------------------
  // Streams
  // -----------------------------
  Stream<QuerySnapshot<Map<String, dynamic>>> watchJoinRequests(String courseId) {
    return _db
        .collection('courses')
        .doc(courseId)
        .collection('joinRequests')
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMembers(String courseId) {
    return _db
        .collection('courses')
        .doc(courseId)
        .collection('members')
        .orderBy('joinedAt', descending: true)
        .snapshots();
  }

  // -----------------------------
  // Approve / Reject
  // -----------------------------
  Future<void> approveJoinRequest({
    required String courseId,
    required String uid,
    required String displayName,
    required String emailLower,
  }) async {
    final batch = _db.batch();

    batch.set(
      _db.collection('courses').doc(courseId).collection('members').doc(uid),
      {
        'role': 'student',
        'displayName': displayName,
        'emailLower': emailLower.trim().toLowerCase(),
        'joinedAt': FieldValue.serverTimestamp(),
        'source': 'request',
      },
      SetOptions(merge: true),
    );

    batch.set(
      _db.collection('users').doc(uid).collection('courseMemberships').doc(courseId),
      {
        'role': 'student',
        'joinedAt': FieldValue.serverTimestamp(),
        'source': 'request',
      },
      SetOptions(merge: true),
    );

    batch.delete(_db.collection('courses').doc(courseId).collection('joinRequests').doc(uid));

    await batch.commit();
  }

  Future<void> rejectJoinRequest({
    required String courseId,
    required String uid,
  }) async {
    await _db.collection('courses').doc(courseId).collection('joinRequests').doc(uid).delete();
  }

  // -----------------------------
  // Add member by email (publicUsers)
  // -----------------------------
  Future<Map<String, String>> _userByEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) throw Exception('Email required');

    final q = await _db
        .collection('publicUsers')
        .where('emailLower', isEqualTo: e)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw Exception('No user found for $e (user must register/login once).');
    }

    final doc = q.docs.first;
    final data = doc.data();

    return {
      'uid': doc.id,
      'displayName': (data['displayName'] ?? '') as String,
      'emailLower': (data['emailLower'] ?? e) as String,
    };
  }

  Future<void> addMemberByEmail({
    required String courseId,
    required String email,
  }) async {
    final info = await _userByEmail(email);

    final uid = info['uid']!;
    final displayName = info['displayName'] ?? '';
    final emailLower = (info['emailLower'] ?? email.trim().toLowerCase()).trim().toLowerCase();

    final batch = _db.batch();

    batch.set(
      _db.collection('courses').doc(courseId).collection('members').doc(uid),
      {
        'role': 'student',
        'displayName': displayName,
        'emailLower': emailLower,
        'joinedAt': FieldValue.serverTimestamp(),
        'source': 'email',
      },
      SetOptions(merge: true),
    );

    batch.set(
      _db.collection('users').doc(uid).collection('courseMemberships').doc(courseId),
      {
        'role': 'student',
        'joinedAt': FieldValue.serverTimestamp(),
        'source': 'email',
      },
      SetOptions(merge: true),
    );

    batch.delete(_db.collection('courses').doc(courseId).collection('joinRequests').doc(uid));

    await batch.commit();
  }

  // -----------------------------
  // ✅ Remove member (creator)
  // -----------------------------
  Future<void> removeMember({
    required String courseId,
    required String memberUid,
  }) async {
    final batch = _db.batch();

    batch.delete(
      _db.collection('courses').doc(courseId).collection('members').doc(memberUid),
    );

    batch.delete(
      _db.collection('users').doc(memberUid).collection('courseMemberships').doc(courseId),
    );

    await batch.commit();
  }
}
