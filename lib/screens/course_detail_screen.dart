import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:srls_app/screens/module_screen.dart';
import 'package:srls_app/screens/review/review_session_screen.dart';

import '../../models/module_model.dart';
import '../../models/review_queue_item.dart';
import '../../services/module_service.dart';
import '../../services/review_queue_service.dart';

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
    final reviewService = ReviewQueueService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(courseTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ Course Review row (like Module)
            Row(
              children: [
                const Text(
                  'Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                if (uid != null)
                  StreamBuilder<List<ReviewQueueItem>>(
                    stream: reviewService.watchDueReviews(
                      uid: uid,
                      courseId: courseId,
                      limit: 999,
                    ),
                    builder: (context, snap) {
                      final n = snap.data?.length ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(),
                        ),
                        child: Text('Due: $n'),
                      );
                    },
                  ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                  onPressed: uid == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewSessionScreen(courseId: courseId),
                            ),
                          );
                        },
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Modules list
            Expanded(
              child: StreamBuilder<List<ModuleModel>>(
                stream: service.watchModules(courseId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Error: ${snapshot.error}');
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
          ],
        ),
      ),
    );
  }
}
