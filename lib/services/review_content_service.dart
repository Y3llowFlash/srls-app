import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/topic_model.dart';
import '../models/mcq_question.dart';
import 'firestore_paths.dart';
import 'question_service.dart';

class ReviewContentService {
  // ignore: unused_field
  final FirebaseFirestore _db;
  final QuestionService _questionService;

  ReviewContentService({FirebaseFirestore? db, QuestionService? questionService})
      : _db = db ?? FirebaseFirestore.instance,
        _questionService = questionService ?? QuestionService();

  Future<TopicModel> getTopic({
    required String courseId,
    required String moduleId,
    required String topicId,
  }) async {
    final snap = await FsPaths.topicDoc(courseId, moduleId, topicId).get();
    if (!snap.exists) {
      throw Exception('Topic not found: $topicId');
    }
    final data = snap.data() as Map<String, dynamic>;
    return TopicModel.fromMap(snap.id, data);
  }

  Future<McqQuestion?> getQuestion({
    required String courseId,
    required String moduleId,
    required String topicId,
    required String questionId,
  }) {
    // Reuse your existing QuestionService logic
    return _questionService.getQuestion(
      courseId: courseId,
      moduleId: moduleId,
      topicId: topicId,
      questionId: questionId,
    );
  }
}
