
import '../models/mcq_question.dart';
import 'firestore_paths.dart';
import 'srs_service.dart';

class QuestionService {

  final _srs = SrsService();

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
    // 1) update question doc
    await FsPaths.questionDoc(courseId, moduleId, topicId, questionId).update({
      'isStarred': starred,
    });

    // 2) if starring, ensure SRS doc exists
    if (starred) {
      await _srs.ensureQuestionSrs(
        courseId: courseId,
        moduleId: moduleId,
        topicId: topicId,
        questionId: questionId,
        isStarred: true,
      );
    }

    // 3) ALWAYS update SRS starred flag (true OR false)
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
    // 1) delete question doc
    await FsPaths.questionDoc(courseId, moduleId, topicId, questionId).delete();

    // 2) delete SRS doc (cleanup)
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

  // ✅ Round 2: stream all questions under a topic
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

  // ✅ Round 2: read one question by id (for view screen)
  Future<McqQuestion?> getQuestion({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
  }) async {
    final doc = await FsPaths.questionDoc(courseId, moduleId, topicId, questionId).get();
    if (!doc.exists) return null;
    return McqQuestion.fromDoc(doc);


    
  }
}
