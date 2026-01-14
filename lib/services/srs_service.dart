import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/srs_item.dart';
import '../utils/srs_math.dart';

enum SrsCollection { notes, questions }

class SrsService {
  final _db = FirebaseFirestore.instance;

  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw Exception('Not logged in');
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> _srsNotes() => _db
      .collection('users')
      .doc(_uid)
      .collection('srs')
      .doc('notes')
      .collection('items');

  CollectionReference<Map<String, dynamic>> _srsQuestions() => _db
      .collection('users')
      .doc(_uid)
      .collection('srs')
      .doc('questions')
      .collection('items');

  Future<void> setQuestionSrsStarred({
    required String questionId,
    required bool starred,
  }) async {
    final ref = _srsQuestions().doc(questionId);
    await ref.set({
      'isStarred': starred,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setNoteSrsStarred({
    required String topicId,
    required bool starred,
  }) async {
    final ref = _srsNotes().doc(topicId);
    await ref.set({
      'isStarred': starred,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteQuestionSrs(String questionId) async {
    await _srsQuestions().doc(questionId).delete();
  }

  Future<void> deleteNoteSrs(String topicId) async {
    await _srsNotes().doc(topicId).delete();
  }

  Future<void> applyReview({
    required SrsCollection collection,
    required String itemId,
    required bool isStarred,
    required int reps,
    required int intervalDays,
    required double easeFactor,
    required ReviewRating rating,
  }) async {
    final col = collection == SrsCollection.notes ? _srsNotes() : _srsQuestions();
    final ref = col.doc(itemId);

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
      'dueAt': result.dueAt,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> ensureNoteSrs({
    required String courseId,
    required String moduleId,
    required String topicId,
    required bool isStarred,
  }) async {
    final ref = _srsNotes().doc(topicId);
    final snap = await ref.get();
    if (snap.exists) return;

    final item = SrsItem(
      id: topicId,
      kind: SrsKind.note,
      courseId: courseId,
      moduleId: moduleId,
      topicId: topicId,
      questionId: null,
      isStarred: isStarred,
      reps: 0,
      easeFactor: 2.5,
      intervalDays: 0,
      dueAt: Timestamp.now(),
    );

    await ref.set(item.toMapForCreate());
  }

  Future<void> ensureQuestionSrs({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
    required bool isStarred,
  }) async {
    final ref = _srsQuestions().doc(questionId);
    final snap = await ref.get();
    if (snap.exists) return;

    final item = SrsItem(
      id: questionId,
      kind: SrsKind.question,
      courseId: courseId,
      moduleId: moduleId,
      topicId: topicId,
      questionId: questionId,
      isStarred: isStarred,
      reps: 0,
      easeFactor: 2.5,
      intervalDays: 0,
      dueAt: Timestamp.now(),
    );

    await ref.set(item.toMapForCreate());
  }
}
