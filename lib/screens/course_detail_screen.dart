import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:srls_app/screens/module_screen.dart';
import 'package:srls_app/screens/review/review_session_screen.dart';
import 'package:srls_app/screens/course_members_screen.dart';

import 'edit_course_screen.dart';
import 'edit_module_screen.dart';
import 'reorder_modules_screen.dart';

import '../../models/module_model.dart';
import '../../models/review_queue_item.dart';
import '../../services/firestore_paths.dart';
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

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FsPaths.courseDoc(courseId).snapshots(),
      builder: (context, courseSnap) {
        final courseData = courseSnap.data?.data() ?? {};
        final liveTitle = (courseData['title'] ?? courseTitle).toString();
        final creatorId = (courseData['creatorId'] ?? '') as String;
        final isCreator = uid != null && uid == creatorId;

        return Scaffold(
          appBar: AppBar(
            title: Text(liveTitle),
            actions: [
              if (isCreator)
                IconButton(
                  tooltip: 'Edit course',
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditCourseScreen(courseId: courseId),
                      ),
                    );
                  },
                ),
              if (isCreator)
                IconButton(
                  tooltip: 'Manage members',
                  icon: const Icon(Icons.manage_accounts),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseMembersScreen(
                          courseId: courseId,
                          courseTitle: liveTitle,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ Course Review row
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
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
                              builder: (_) => ReviewSessionScreen(
                                courseId: courseId,
                              ),
                            ),
                          );
                        },
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // ✅ Modules header row (THIS was missing)
            Row(
              children: [
                const Text(
                  'Modules',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (isCreator)
                  IconButton(
                    tooltip: 'Reorder modules',
                    icon: const Icon(Icons.swap_vert),
                    onPressed: () async {
                      final mods = await service.watchModules(courseId).first;
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReorderModulesScreen(
                            courseId: courseId,
                            modules: mods,
                          ),
                        ),
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Create module',
                  onPressed: () => _showAddModuleDialog(
                    context: context,
                    service: service,
                    courseId: courseId,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

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
                    return const Center(
                      child: Text('No modules yet. Tap + to add one.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: modules.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = modules[i];
                      return ListTile(
                        title: Text(m.title),
                        trailing: isCreator
                            ? PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditModuleScreen(
                                          courseId: courseId,
                                          moduleId: m.id,
                                          initialTitle: m.title,
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (v == 'delete') {
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

                                    try {
                                      final deleted = await service.deleteModuleIfEmpty(
                                        courseId: courseId,
                                        moduleId: m.id,
                                      );

                                      if (!context.mounted) return;

                                      if (!deleted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Cannot delete: this module still has topics.'),
                                          ),
                                        );
                                        return;
                                      }

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Module deleted.')),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to delete module: $e')),
                                      );
                                    }
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              )
                            : const Icon(Icons.chevron_right),
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
      },
    );
  }

  Future<void> _showAddModuleDialog({
    required BuildContext context,
    required ModuleService service,
    required String courseId,
  }) async {
    final titleCtrl = TextEditingController();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> add() async {
            final title = titleCtrl.text.trim();
            if (title.isEmpty) return;

            setState(() => saving = true);

            try {
              // ✅ order = current number of modules
              final snap = await FsPaths.modules(courseId).get();
              final order = snap.size;

              await service.addModule(
                courseId: courseId,
                title: title,
                order: order,
              );

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            } catch (e) {
              if (!dialogContext.mounted) return;
              setState(() => saving = false);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text('Failed to create module: $e')),
              );
            }
          }

          return AlertDialog(
            title: const Text('Create Module'),
            content: TextField(
              controller: titleCtrl,
              enabled: !saving,
              decoration: const InputDecoration(
                labelText: 'Module title',
              ),
              onSubmitted: (_) => saving ? null : add(),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving ? null : add,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}
