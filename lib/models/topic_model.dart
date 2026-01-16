class TopicModel {
  final String id;
  final String title;
  final String notes;
  final String videoType; // none | youtube | storage
  final String? videoUrl;
  final bool isStarredNote;

  TopicModel({
    required this.id,
    required this.title,
    required this.notes,
    required this.videoType,
    required this.videoUrl,
    required this.isStarredNote,
  });

  factory TopicModel.fromMap(String id, Map<String, dynamic> data) {
    final rawUrl = (data['videoUrl'] as String?)?.trim();
    final inferredType = (data['videoType'] as String?) ??
        ((rawUrl == null || rawUrl.isEmpty) ? 'none' : 'youtube');

    return TopicModel(
      id: id,
      title: data['title'] ?? '',
      notes: data['notes'] ?? '',
      videoType: inferredType,
      videoUrl: rawUrl,
      isStarredNote: data['isStarredNote'] ?? false,
    );
  }
}
