// lib/models/mcq_question.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'mcq_option.dart';

class McqQuestion {
  final String id; // Firestore doc id
  final String questionText;
  final List<McqOption> options;
  final String correctOptionId; // "A"/"B"/"C"/"D"
  final bool isStarred;

  // Optional for later (keep now but allow null)
  final String? questionImageMediaId;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  McqQuestion copyWith({
      bool? isStarred,
    }) {
      return McqQuestion(
        id: id,
        questionText: questionText,
        options: options,
        correctOptionId: correctOptionId,
        isStarred: isStarred ?? this.isStarred,
        questionImageMediaId: questionImageMediaId,
      );
    }

  McqQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctOptionId,
    required this.isStarred,
    this.questionImageMediaId,
    this.createdAt,
    this.updatedAt,
  });

  factory McqQuestion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawOptions = (data['options'] as List<dynamic>? ?? []);

    return McqQuestion(
      id: doc.id,
      questionText: (data['questionText'] ?? '') as String,
      options: rawOptions
          .map((e) => McqOption.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      correctOptionId: (data['correctOptionId'] ?? 'A') as String,
      isStarred: (data['isStarred'] ?? false) as bool,
      questionImageMediaId: data['questionImageMediaId'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMapForCreate() {
    return {
      'questionText': questionText,
      'questionImageMediaId': questionImageMediaId,
      'options': options.map((o) => o.toMap()).toList(),
      'correctOptionId': correctOptionId,
      'isStarred': isStarred,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    return {
      'questionText': questionText,
      'questionImageMediaId': questionImageMediaId,
      'options': options.map((o) => o.toMap()).toList(),
      'correctOptionId': correctOptionId,
      'isStarred': isStarred,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
