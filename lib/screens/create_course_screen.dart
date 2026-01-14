import 'package:flutter/material.dart';
import '../services/course_service.dart';
import '../utils/course_code.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String visibility = 'public';
  bool duplicable = true;
  bool loading = false;

  Future<void> _createCourse() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => loading = true);

    try {
      final code = generateCourseCode();

      await CourseService().createCourse(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        visibility: visibility,
        duplicable: duplicable,
        courseCode: code,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Course')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Course Title'),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField(
              value: visibility,
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'private', child: Text('Private')),
              ],
              onChanged: (v) => setState(() => visibility = v!),
              decoration: const InputDecoration(labelText: 'Visibility'),
            ),

            SwitchListTile(
              title: const Text('Allow Duplicating'),
              value: duplicable,
              onChanged: (v) => setState(() => duplicable = v),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: loading ? null : _createCourse,
              child: Text(loading ? 'Creating...' : 'Create Course'),
            ),
          ],
        ),
      ),
    );
  }
}
