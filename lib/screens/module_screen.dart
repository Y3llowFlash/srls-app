import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'package:srls_app/models/review_queue_item.dart';
import 'package:srls_app/screens/review/review_session_screen.dart';
import 'package:srls_app/screens/topic/topic_screen.dart';

import '../../models/topic_model.dart';
import '../../services/firestore_paths.dart';
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
            // ✅ Review CTA row
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
                      moduleId: moduleId,
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
                              builder: (_) => ReviewSessionScreen(
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

            // ✅ Topics header row
            Row(
              children: [
                const Text(
                  'Topics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddTopicDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ✅ Topic list
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

                      final type = t.videoType.trim();
                      final hasVideo =
                          t.videoUrl != null && t.videoUrl!.trim().isNotEmpty;

                      final subtitle = (!hasVideo || type == 'none')
                          ? 'No video'
                          : (type == 'youtube')
                              ? '🔗 YouTube video'
                              : '🎥 Uploaded video';

                      return ListTile(
                        title: Text(t.title),
                        subtitle: Text(subtitle),
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

  Future<void> _showAddTopicDialog(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final youtubeCtrl = TextEditingController();

    String selected = 'none'; // none | youtube | upload
    File? pickedFile;
    bool saving = false;

    Future<String> uploadToStorage({
      required String courseId,
      required String moduleId,
      required String topicId,
      required File file,
    }) async {
      final ext = file.path.contains('.')
          ? file.path.substring(file.path.lastIndexOf('.'))
          : '.mp4';

      final storagePath = 'videos/$courseId/$moduleId/$topicId$ext';
      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putFile(file);
      return storagePath;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> save() async {
            final title = titleCtrl.text.trim();
            final notes = notesCtrl.text.trim();
            final yt = youtubeCtrl.text.trim();

            if (title.isEmpty) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Topic title is required.')),
              );
              return;
            }
            if (selected == 'youtube' && yt.isEmpty) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Please paste a YouTube link.')),
              );
              return;
            }
            if (selected == 'upload' && pickedFile == null) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Please choose a video file.')),
              );
              return;
            }

            setState(() => saving = true);

            final doc = FsPaths.topics(courseId, moduleId).doc();

            String videoType = 'none';
            String videoUrl = '';

            try {
              if (selected == 'youtube') {
                videoType = 'youtube';
                videoUrl = yt;
              } else if (selected == 'upload') {
                videoType = 'storage';
                videoUrl = await uploadToStorage(
                  courseId: courseId,
                  moduleId: moduleId,
                  topicId: doc.id,
                  file: pickedFile!,
                );
              }

              await doc.set({
                'title': title,
                'notes': notes,
                'videoType': videoType,
                'videoUrl': videoUrl,
                'isStarredNote': false,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              });

              if (!dialogContext.mounted) {
                return;
              }
              Navigator.pop(dialogContext);
            } catch (e) {
              if (!dialogContext.mounted) {
                return;
              }
              setState(() => saving = false);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text('Failed to add topic: $e')),
              );
            }
          }

          return AlertDialog(
            title: const Text('Add Topic'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleCtrl,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Topic title'),
                  ),
                  TextField(
                    controller: notesCtrl,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    minLines: 3,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 16),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Video',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    value: 'none',
                    groupValue: selected,
                    onChanged: saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              selected = v;
                              youtubeCtrl.clear();
                              pickedFile = null;
                            });
                          },
                    title: const Text('No video'),
                  ),

                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    value: 'youtube',
                    groupValue: selected,
                    onChanged: saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              selected = v;
                              pickedFile = null;
                            });
                          },
                    title: const Text('YouTube link'),
                  ),

                  if (selected == 'youtube')
                    TextField(
                      controller: youtubeCtrl,
                      enabled: !saving,
                      decoration: const InputDecoration(
                        labelText: 'YouTube URL',
                        hintText:
                            'https://youtu.be/... or https://youtube.com/watch?v=...',
                      ),
                    ),

                  // ignore: deprecated_member_use
                  RadioListTile<String>(
                    value: 'upload',
                    groupValue: selected,
                    onChanged: saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              selected = v;
                              youtubeCtrl.clear();
                            });
                          },
                    title: const Text('Upload video'),
                  ),

                  if (selected == 'upload')
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pickedFile == null
                                ? 'No file selected'
                                : pickedFile!.path
                                    .split(Platform.pathSeparator)
                                    .last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose'),
                          onPressed: saving
                              ? null
                              : () async {
                                  final result =
                                      await FilePicker.platform.pickFiles(
                                    type: FileType.video,
                                    allowMultiple: false,
                                  );
                                  if (result == null || result.files.isEmpty) {
                                    return;
                                  }
                                  final path = result.files.single.path;
                                  if (path == null) return;

                                  setState(() {
                                    pickedFile = File(path);
                                  });
                                },
                        ),
                      ],
                    ),

                  if (saving) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Saving...'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}
