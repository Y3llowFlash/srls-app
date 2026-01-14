class TopicModel {
  final String id;
  final String title;
  final String notes;
  final bool isStarredNote;
  final String? videoUrl;
  

  TopicModel({
    required this.id,
    required this.title,
    required this.notes,
    required this.isStarredNote,
    required this.videoUrl,
  });

  factory TopicModel.fromMap(String id, Map<String, dynamic> data) {
    return TopicModel(
      id: id,
      title: (data['title'] ?? '') as String,
      notes: (data['notes'] ?? '') as String,
      isStarredNote: (data['isStarredNote'] ?? false) as bool,
      videoUrl: (data['videoUrl'] as String?)?.trim().isEmpty == true
          ? null
          : (data['videoUrl'] as String?),
    );
  }
}
