class ModuleModel {
  final String id;
  final String title;
  final int order;

  ModuleModel({required this.id, required this.title, required this.order});

  factory ModuleModel.fromMap(String id, Map<String, dynamic> data) {
    return ModuleModel(
      id: id,
      title: (data['title'] ?? '') as String,
      order: (data['order'] ?? 0) as int,
    );
  }
}
