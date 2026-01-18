import 'package:flutter/material.dart';

import '../services/module_service.dart';

class EditModuleScreen extends StatefulWidget {
  final String courseId;
  final String moduleId;
  final String initialTitle;

  const EditModuleScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.initialTitle,
  });

  @override
  State<EditModuleScreen> createState() => _EditModuleScreenState();
}

class _EditModuleScreenState extends State<EditModuleScreen> {
  final _titleCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl.text = widget.initialTitle;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Module title cannot be empty.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ModuleService().renameModule(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        title: title,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename module: $e')),
      );
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete module?'),
        content: const Text(
          'This will delete the module only if it has no topics.\n\n'
          'If topics exist, you must delete the topics first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final deleted = await ModuleService().deleteModuleIfEmpty(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
      );

      if (!mounted) return;

      if (!deleted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot delete: this module still has topics.'),
          ),
        );
        return;
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete module: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Module'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _titleCtrl,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Module title',
              ),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
            const SizedBox(height: 12),
            if (_saving) const LinearProgressIndicator(),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete module'),
              onPressed: _saving ? null : _delete,
            ),
          ],
        ),
      ),
    );
  }
}
