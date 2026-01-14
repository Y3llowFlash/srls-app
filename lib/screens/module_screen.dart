import 'package:flutter/material.dart';
import '../../models/topic_model.dart';
import '../../services/topic_service.dart';
import '../screens/topic/topic_screen.dart';

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
    final service = TopicService();

    return Scaffold(
      appBar: AppBar(title: Text(moduleTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Topics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddTopicDialog(context, service),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<TopicModel>>(
                stream: service.watchTopics(courseId, moduleId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final topics = snapshot.data!;
                  if (topics.isEmpty) {
                    return const Center(child: Text('No topics yet. Tap + to add one.'));
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
