
import '../models/mcq_question.dart';
import 'firestore_paths.dart';

class QuestionService {
  
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

  Future<void> deleteMcqQuestion({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
  }) async {
    await FsPaths.questionDoc(courseId, moduleId, topicId, questionId).delete();
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
