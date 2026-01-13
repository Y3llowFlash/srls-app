class Course {
  final String id;
  final String title;
  final String description;
  final String courseCode;
  final String creatorId;
  final String visibility; // "public" | "private"
  final bool duplicable;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.courseCode,
    required this.creatorId,
    required this.visibility,
    required this.duplicable,
  });

  factory Course.fromMap(String id, Map<String, dynamic> data) {
    return Course(
      id: id,
      title: (data['title'] ?? '') as String,
      description: (data['description'] ?? '') as String,
      courseCode: (data['courseCode'] ?? '') as String,
      creatorId: (data['creatorId'] ?? '') as String,
      visibility: (data['visibility'] ?? 'public') as String,
      duplicable: (data['duplicable'] ?? false) as bool,
    );
  }
}
