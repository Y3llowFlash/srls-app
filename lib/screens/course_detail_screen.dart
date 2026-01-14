import 'package:flutter/material.dart';
import '../models/module_model.dart';
import '../services/module_service.dart';

class CourseDetailScreen extends StatelessWidget {
  final String courseId;
  final String title;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final service = ModuleService();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Modules',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddModuleDialog(context, service),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<List<ModuleModel>>(
                stream: service.watchModules(courseId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final modules = snapshot.data!;
                  if (modules.isEmpty) {
                    return const Center(
                      child: Text('No modules yet. Tap + to add one.'),
                    );
                  }

                  return ReorderableListView.builder(
                    itemCount: modules.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (newIndex > oldIndex) newIndex -= 1;

                      final updated = List<ModuleModel>.from(modules);
                      final moved = updated.removeAt(oldIndex);
                      updated.insert(newIndex, moved);

                      // Save new order to Firestore
                      await service.reorderModules(courseId, updated);
                    },
                    itemBuilder: (context, i) {
                      final m = modules[i];
                      return ListTile(
                        key: ValueKey(m.id), // REQUIRED for reorder
                        title: Text(m.title),
                        subtitle: Text('Module No : ${m.order + 1}'),
                        leading: const Icon(Icons.drag_handle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          // Round 2 later
                        },
                      );
                    },
                  );



                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddModuleDialog(
    BuildContext context,
    ModuleService service,
  ) async {
    final titleCtrl = TextEditingController();
    final orderCtrl = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Module'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Module title'),
            ),
            TextField(
              controller: orderCtrl,
              decoration: const InputDecoration(labelText: 'Module No'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final title = titleCtrl.text.trim();
    final moduleNo = int.tryParse(orderCtrl.text.trim()) ?? 1;
    final order = (moduleNo <= 1) ? 0 : moduleNo - 1;

    if (title.isEmpty) return;

    await service.addModule(courseId: courseId, title: title, order: order);
  }
}
