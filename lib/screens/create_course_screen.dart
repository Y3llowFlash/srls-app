import 'package:flutter/material.dart';
import '../services/course_service.dart';
import '../utils/course_code.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();

  String _visibility = 'private';
  bool _duplicable = true;
  bool _loading = false;

  Future<void> _create() async {
    if (_title.text.isEmpty) return;

    setState(() => _loading = true);

    try {
      final code = generateCourseCode();

      await CourseService().createCourse(
        title: _title.text.trim(),
        description: _description.text.trim(),
        visibility: _visibility,
        duplicable: _duplicable,
        courseCode: code,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              controller: _title,
              decoration: const InputDecoration(labelText: 'Course title'),
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),

            DropdownButton<String>(
              value: _visibility,
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(value: 'private', child: Text('Private')),
              ],
              onChanged: (v) => setState(() => _visibility = v!),
            ),

            SwitchListTile(
              value: _duplicable,
              onChanged: (v) => setState(() => _duplicable = v),
              title: const Text('Allow cloning'),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: _loading ? null : _create,
              child:
                  _loading ? const CircularProgressIndicator() : const Text('Create'),
            )
          ],
        ),
      ),
    );
  }
}
