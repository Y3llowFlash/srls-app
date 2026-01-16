import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:srls_app/models/mcq_option.dart';

class McqQuestion {
  final String id; // Firestore doc id
  final String questionText;

  /// Optional images for the question (0..3). Each is a Firebase Storage path.
  final List<String> questionImagePaths;

  final List<McqOption> options;
  final String correctOptionId; // "A"/"B"/"C"/"D"
  final bool isStarred;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  McqQuestion({
    required this.id,
    required this.questionText,
    this.questionImagePaths = const [],
    required this.options,
    required this.correctOptionId,
    this.isStarred = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Read from Firestore
  factory McqQuestion.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final rawOptions = (data['options'] as List?) ?? [];

    // Backward compatible:
    // - new: questionImagePaths (List<String>)
    // - legacy: questionImageMediaId (String)
    final List<String> imgPaths = [];
    final rawImgList = data['questionImagePaths'];
    if (rawImgList is List) {
      imgPaths.addAll(rawImgList.whereType<String>());
    } else {
      final legacy = data['questionImageMediaId'];
      if (legacy is String && legacy.trim().isNotEmpty) {
        imgPaths.add(legacy.trim());
      }
    }

    return McqQuestion(
      id: doc.id,
      questionText: data['questionText'] ?? '',
      questionImagePaths: imgPaths,
      options: rawOptions.map((o) => McqOption.fromMap(Map<String, dynamic>.from(o))).toList(),
      correctOptionId: data['correctOptionId'] ?? 'A',
      isStarred: data['isStarred'] ?? false,
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  /// Write when creating
  Map<String, dynamic> toMapForCreate() {
    return {
      'questionText': questionText,
      'questionImagePaths': questionImagePaths,
      'options': options.map((o) => o.toMap()).toList(),
      'correctOptionId': correctOptionId,
      'isStarred': isStarred,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Write when updating
  Map<String, dynamic> toMapForUpdate() {
    return {
      'questionText': questionText,
      'questionImagePaths': questionImagePaths,
      'options': options.map((o) => o.toMap()).toList(),
      'correctOptionId': correctOptionId,
      'isStarred': isStarred,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  McqQuestion copyWith({bool? isStarred}) {
    return McqQuestion(
      id: id,
      questionText: questionText,
      questionImagePaths: questionImagePaths,
      options: options,
      correctOptionId: correctOptionId,
      isStarred: isStarred ?? this.isStarred,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
