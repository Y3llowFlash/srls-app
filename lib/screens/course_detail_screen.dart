import 'package:flutter/material.dart';
import 'package:srls_app/screens/module_screen.dart';
import 'package:srls_app/screens/review/review_session_screen.dart';

import '../../models/module_model.dart';
import '../../services/module_service.dart';
class CourseDetailScreen extends StatelessWidget {
  final String courseId;
  final String courseTitle;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    final service = ModuleService();

    return Scaffold(
      appBar: AppBar(
        title: Text(courseTitle),
        actions: [
          // ▶ Review entire course
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Review this course',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReviewSessionScreen(
                    courseId: courseId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
              return const Center(child: Text('No modules yet.'));
            }

            return ListView.separated(
              itemCount: modules.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final m = modules[i];
                return ListTile(
                  title: Text(m.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModuleScreen(
                          courseId: courseId,
                          moduleId: m.id,
                          moduleTitle: m.title,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
