import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:srls_app/models/review_queue_item.dart';
import 'package:srls_app/screens/review/review_queue_screen.dart';
import 'package:srls_app/screens/topic/topic_screen.dart';

import '../../models/topic_model.dart';
import '../../services/topic_service.dart';
import '../../services/review_queue_service.dart';
class ModuleScreen extends StatelessWidget {
  final String courseId;
  final String moduleId;
  final String moduleTitle;

  const ModuleScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.moduleTitle,
  });

  @override
  Widget build(BuildContext context) {
    final topicService = TopicService();
    final reviewService = ReviewQueueService();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(moduleTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Review CTA row (RemNote-style: practice this "document/module")
            Row(
              children: [
                const Text(
                  'Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),

                // Due count badge
                if (uid != null)
                  StreamBuilder<List<ReviewQueueItem>>(
                    stream: reviewService.watchDueReviews(
                      uid: uid,
                      courseId: courseId,
                      moduleId: moduleId,
                      limit: 999, // just for count (MVP)
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
                  )
                else
                  const SizedBox.shrink(),

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
                              builder: (_) => ReviewQueueScreen(
                                courseId: courseId,
                                moduleId: moduleId,
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

            // ✅ Topics header row (your existing UI)
            Row(
              children: [
                const Text(
                  'Topics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddTopicDialog(context, topicService),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ✅ Topic list (unchanged)
            Expanded(
              child: StreamBuilder<List<TopicModel>>(
                stream: topicService.watchTopics(courseId, moduleId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final topics = snapshot.data!;
                  if (topics.isEmpty) {
                    return const Center(
                      child: Text('No topics yet. Tap + to add one.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final t = topics[i];
                      return ListTile(
                        title: Text(t.title),
                        subtitle: (t.videoUrl != null)
                            ? const Text('🎥 Video attached')
                            : const Text('No video'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TopicScreen(
                                courseId: courseId,
                                moduleId: moduleId,
                                topicId: t.id,
                                topicTitle: t.title,
                                notes: t.notes,
                                videoUrl: t.videoUrl,
                                isStarredNote: t.isStarredNote,
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

  Future<void> _showAddTopicDialog(
    BuildContext context,
    TopicService service,
  ) async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final videoCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Topic'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Topic title'),
              ),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(labelText: 'Notes'),
                minLines: 3,
                maxLines: 6,
              ),
              TextField(
                controller: videoCtrl,
                decoration: const InputDecoration(labelText: 'Video URL (optional)'),
              ),
            ],
          ),
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
    final notes = notesCtrl.text.trim();
    final videoUrl = videoCtrl.text.trim();

    if (title.isEmpty) return;

    await service.addTopic(
      courseId: courseId,
      moduleId: moduleId,
      title: title,
      notes: notes,
      videoUrl: videoUrl.isEmpty ? null : videoUrl,
    );
  }
}
