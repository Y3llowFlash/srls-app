import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_paths.dart';
import '../utils/srs_math.dart';

class SrsService {
  final FirebaseFirestore _db;

  SrsService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception('Not logged in');
    return u.uid;
  }

  // ✅ Unified SRS collection: users/{uid}/srs
  CollectionReference<Map<String, dynamic>> _srs() => FsPaths.userSrs(_uid);

  // ✅ Legacy SRS locations:
  // users/{uid}/srs/notes/items/*
  CollectionReference<Map<String, dynamic>> _legacyNotes() => _db
      .collection('users')
      .doc(_uid)
      .collection('srs')
      .doc('notes')
      .collection('items');

  // users/{uid}/srs/questions/items/*
  CollectionReference<Map<String, dynamic>> _legacyQuestions() => _db
      .collection('users')
      .doc(_uid)
      .collection('srs')
      .doc('questions')
      .collection('items');

  // ✅ Unified doc ids
  String _noteDocId(String topicId) => 'n_$topicId';
  String _questionDocId(String questionId) => 'q_$questionId';

  // -----------------------------
  // Migration (Legacy -> Unified)
  // -----------------------------
  /// Run this once (safe to call multiple times).
  /// Copies legacy docs into unified /users/{uid}/srs docs.
  /// Does NOT delete legacy docs automatically.
  Future<void> migrateLegacyToUnified() async {
    // ---- notes ----
    final notesSnap = await _legacyNotes().get();
    for (final d in notesSnap.docs) {
      final m = d.data();

      final topicId = (m['topicId'] ?? d.id).toString();
      final courseId = (m['courseId'] ?? '').toString();
      final moduleId = (m['moduleId'] ?? '').toString();

      await _srs().doc(_noteDocId(topicId)).set({
        'type': 'note',
        'refId': topicId,
        'courseId': courseId,
        'moduleId': moduleId,
        'topicId': topicId,

        // keep old compat fields if you want (optional)
        'kind': 'note',
        'questionId': null,

        'isStarred': m['isStarred'] ?? true,
        'reps': m['reps'] ?? 0,
        'intervalDays': m['intervalDays'] ?? 0,
        'easeFactor': _asDouble(m['easeFactor'], 2.5),
        'dueAt': m['dueAt'] ?? Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
        'migratedFrom': 'legacy_notes',
      }, SetOptions(merge: true));
    }

    // ---- questions ----
    final qSnap = await _legacyQuestions().get();
    for (final d in qSnap.docs) {
      final m = d.data();

      final questionId = (m['questionId'] ?? d.id).toString();
      final courseId = (m['courseId'] ?? '').toString();
      final moduleId = (m['moduleId'] ?? '').toString();
      final topicId = (m['topicId'] ?? '').toString();

      await _srs().doc(_questionDocId(questionId)).set({
        'type': 'question',
        'refId': questionId,
        'courseId': courseId,
        'moduleId': moduleId,
        'topicId': topicId,

        // keep old compat fields if you want (optional)
        'kind': 'question',
        'questionId': questionId,

        'isStarred': m['isStarred'] ?? true,
        'reps': m['reps'] ?? 0,
        'intervalDays': m['intervalDays'] ?? 0,
        'easeFactor': _asDouble(m['easeFactor'], 2.5),
        'dueAt': m['dueAt'] ?? Timestamp.now(),
        'updatedAt': FieldValue.serverTimestamp(),
        'migratedFrom': 'legacy_questions',
      }, SetOptions(merge: true));
    }
  }

  // -----------------------------
  // Ensure docs exist on Star
  // -----------------------------
  Future<void> ensureNoteSrs({
    required String courseId,
    required String moduleId,
    required String topicId,
    required bool isStarred,
  }) async {
    final ref = _srs().doc(_noteDocId(topicId));
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'type': 'note',
      'refId': topicId,
      'courseId': courseId,
      'moduleId': moduleId,
      'topicId': topicId,
      'kind': 'note',
      'questionId': null,

      'isStarred': isStarred,
      'reps': 0,
      'intervalDays': 0,
      'easeFactor': 2.5,
      'dueAt': Timestamp.now(), // ✅ make it due immediately
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> ensureQuestionSrs({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
    required bool isStarred,
  }) async {
    final ref = _srs().doc(_questionDocId(questionId));
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'type': 'question',
      'refId': questionId,
      'courseId': courseId,
      'moduleId': moduleId,
      'topicId': topicId,
      'kind': 'question',
      'questionId': questionId,

      'isStarred': isStarred,
      'reps': 0,
      'intervalDays': 0,
      'easeFactor': 2.5,
      'dueAt': Timestamp.now(), // ✅ due immediately
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // -----------------------------
  // Star toggles (unified)
  // -----------------------------
  Future<void> setNoteSrsStarred({
    required String topicId,
    required bool starred,
  }) async {
    await _srs().doc(_noteDocId(topicId)).set({
      'isStarred': starred,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setQuestionSrsStarred({
    required String questionId,
    required bool starred,
  }) async {
    await _srs().doc(_questionDocId(questionId)).set({
      'isStarred': starred,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -----------------------------
  // Deletes (unified)
  // -----------------------------
  Future<void> deleteNoteSrs(String topicId) async {
    await _srs().doc(_noteDocId(topicId)).delete();
  }

  Future<void> deleteQuestionSrs(String questionId) async {
    await _srs().doc(_questionDocId(questionId)).delete();
  }

  // -----------------------------
  // Apply review (unified)
  // -----------------------------
  /// Update SRS based on rating.
  /// srsDocId should be 'n_{topicId}' or 'q_{questionId}'.
  Future<void> applyReviewUnified({
    required String srsDocId,
    required bool isStarred,
    required int reps,
    required int intervalDays,
    required double easeFactor,
    required ReviewRating rating,
  }) async {
    final ref = _srs().doc(srsDocId);

    final result = SrsMath.next(
      reps: reps,
      intervalDays: intervalDays,
      easeFactor: easeFactor,
      isStarred: isStarred,
      rating: rating,
    );

    await ref.set({
      'isStarred': isStarred,
      'reps': result.reps,
      'intervalDays': result.intervalDays,
      'easeFactor': result.easeFactor,
      'dueAt': result.dueAt, // should be Timestamp from SrsMath.next()
      'lastReviewedAt': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // -----------------------------
  // Helpers
  // -----------------------------
  double _asDouble(dynamic v, double fallback) {
    if (v == null) return fallback;
    if (v is num) return v.toDouble();
    return fallback;
  }
}
