import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import '../models/mcq_question.dart';
import 'firestore_paths.dart';
import 'srs_service.dart';

class QuestionService {
  final _srs = SrsService();

  // -----------------------------
  // Storage helpers (MCQ Images)
  // -----------------------------
  String _base({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
  }) =>
      'mcq_images/$courseId/$moduleId/$topicId/$questionId';

  Future<String> uploadQuestionImage({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
    required int slotIndex, // 0..2
    required File file,
  }) async {
    final ext = file.path.contains('.')
        ? file.path.substring(file.path.lastIndexOf('.'))
        : '.jpg';

    final path = '${_base(courseId: courseId, moduleId: moduleId, topicId: topicId, questionId: questionId)}/q_${slotIndex + 1}$ext';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(file);
    return path;
  }

  Future<String> uploadOptionImage({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
    required String optionId, // A/B/C/D
    required File file,
  }) async {
    final ext = file.path.contains('.')
        ? file.path.substring(file.path.lastIndexOf('.'))
        : '.jpg';

    final safe = optionId.toLowerCase();
    final path = '${_base(courseId: courseId, moduleId: moduleId, topicId: topicId, questionId: questionId)}/opt_$safe$ext';
    final ref = FirebaseStorage.instance.ref(path);
    await ref.putFile(file);
    return path;
  }

  Future<void> deleteStoragePathIfAny(String? path) async {
    final p = path?.trim() ?? '';
    if (p.isEmpty) return;
    try {
      await FirebaseStorage.instance.ref(p).delete();
    } catch (_) {
      // ignore
    }
  }

  // -----------------------------
  // CRUD
  // -----------------------------
  Future<void> updateMcqQuestion({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
    required McqQuestion question,
  }) async {
    await FsPaths.questionDoc(courseId, moduleId, topicId, questionId)
        .update(question.toMapForUpdate());
  }

  Future<void> setStarQuestion({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
    required bool starred,
  }) async {
    await FsPaths.questionDoc(courseId, moduleId, topicId, questionId).update({
      'isStarred': starred,
    });

    if (starred) {
      await _srs.ensureQuestionSrs(
        courseId: courseId,
        moduleId: moduleId,
        topicId: topicId,
        questionId: questionId,
        isStarred: true,
      );
    }

    await _srs.setQuestionSrsStarred(
      questionId: questionId,
      starred: starred,
    );
  }

  Future<void> deleteMcqQuestion({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
  }) async {
    // optional cleanup: delete the entire folder is not possible directly,
    // but we delete known paths in screens / future improvements.
    await FsPaths.questionDoc(courseId, moduleId, topicId, questionId).delete();
    await _srs.deleteQuestionSrs(questionId);
  }

  Future<String> createMcqQuestion({
    required String courseId,
    required String moduleId,
    required String topicId,
    required McqQuestion question,
  }) async {
    final col = FsPaths.questions(courseId, moduleId, topicId);
    final doc = col.doc();
    await doc.set(question.toMapForCreate());
    return doc.id;
  }

  Stream<List<McqQuestion>> streamQuestions({
    required String courseId,
    required String moduleId,
    required String topicId,
  }) {
    return FsPaths.questions(courseId, moduleId, topicId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => McqQuestion.fromDoc(d)).toList());
  }

  Future<McqQuestion?> getQuestion({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
  }) async {
    final doc = await FsPaths
        .questionDoc(courseId, moduleId, topicId, questionId)
        .get();
    if (!doc.exists) return null;
    return McqQuestion.fromDoc(doc);
  }
}
