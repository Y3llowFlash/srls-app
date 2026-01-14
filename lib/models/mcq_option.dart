// lib/models/mcq_option.dart

class McqOption {
  final String id;              // "A", "B", "C", "D"
  final String text;            // option text
  final String? imageMediaId;   // optional image reference

  McqOption({
    required this.id,
    required this.text,
    this.imageMediaId,
  });

  /// Convert Firestore map → McqOption
  factory McqOption.fromMap(Map<String, dynamic> map) {
    return McqOption(
      id: map['id'] as String,
      text: map['text'] as String,
      imageMediaId: map['imageMediaId'] as String?,
    );
  }

  /// Convert McqOption → Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'imageMediaId': imageMediaId,
    };
  }
}
