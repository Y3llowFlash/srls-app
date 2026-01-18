import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/course_service.dart';
import '../services/firestore_paths.dart';

class EditCourseScreen extends StatefulWidget {
  final String courseId;

  const EditCourseScreen({
    super.key,
    required this.courseId,
  });

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _visibility = 'public';
  bool _duplicable = false;

  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be empty.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await CourseService().updateCourse(
        courseId: widget.courseId,
        title: title,
        description: desc,
        visibility: _visibility,
        duplicable: _duplicable,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update course: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FsPaths.courseDoc(widget.courseId).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Course')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snap.error}'),
            ),
          );
        }

        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit Course')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data() ?? {};

        // Initialize controllers only once from Firestore.
        if (!_initialized) {
          _titleCtrl.text = (data['title'] ?? '').toString();
          _descCtrl.text = (data['description'] ?? '').toString();
          _visibility = (data['visibility'] ?? 'public').toString();
          _duplicable = (data['duplicable'] ?? false) == true;
          _initialized = true;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit Course'),
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
                    labelText: 'Course title',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  enabled: !_saving,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _visibility,
                  decoration: const InputDecoration(
                    labelText: 'Visibility',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _visibility = v ?? 'public'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Duplicable'),
                  subtitle: const Text('Allow others to duplicate this course.'),
                  value: _duplicable,
                  onChanged: _saving ? null : (v) => setState(() => _duplicable = v),
                ),
                const SizedBox(height: 12),
                if (_saving) const LinearProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }
}
