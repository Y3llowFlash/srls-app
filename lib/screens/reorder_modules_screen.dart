import 'package:flutter/material.dart';

import '../models/module_model.dart';
import '../services/module_service.dart';

class ReorderModulesScreen extends StatefulWidget {
  final String courseId;
  final List<ModuleModel> modules;

  const ReorderModulesScreen({
    super.key,
    required this.courseId,
    required this.modules,
  });

  @override
  State<ReorderModulesScreen> createState() => _ReorderModulesScreenState();
}

class _ReorderModulesScreenState extends State<ReorderModulesScreen> {
  late List<ModuleModel> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = List<ModuleModel>.from(widget.modules);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ModuleService().reorderModules(widget.courseId, _items);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reorder modules: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Modules'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_saving) const LinearProgressIndicator(),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _items.removeAt(oldIndex);
                  _items.insert(newIndex, item);
                });
              },
              itemBuilder: (context, i) {
                final m = _items[i];
                return ListTile(
                  key: ValueKey(m.id),
                  title: Text(m.title),
                  leading: const Icon(Icons.drag_handle),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
