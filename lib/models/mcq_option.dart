class McqOption {
  final String id; // "A", "B", "C", "D"
  final String text;

  /// Firebase Storage path (NOT a download URL)
  /// Example: mcq_images/<courseId>/<moduleId>/<topicId>/<questionId>/opt_a.jpg
  final String? imagePath;

  McqOption({
    required this.id,
    required this.text,
    this.imagePath,
  });

  factory McqOption.fromMap(Map<String, dynamic> map) {
    return McqOption(
      id: (map['id'] ?? 'A') as String,
      text: (map['text'] ?? '') as String,
      // backward compatibility with old field
      imagePath: (map['imagePath'] as String?) ?? (map['imageMediaId'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'imagePath': imagePath,
    };
  }
}
