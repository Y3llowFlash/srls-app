import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../practice/practice_session_screen.dart';

import '../../models/mcq_question.dart';
import '../../services/firestore_paths.dart';
import '../../services/topic_service.dart';
import '../questions/create_mcq_question_screen.dart';
import '../questions/view_mcq_question_screen.dart';
import '../review/review_session_screen.dart';
import '../../widgets/topic_video_player.dart';

class TopicScreen extends StatefulWidget {
  final String courseId;
  final String moduleId;
  final String topicId;

  final String topicTitle;
  final String notes;
  final String? videoUrl;
  final bool isStarredNote;

  const TopicScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.topicId,
    required this.topicTitle,
    required this.notes,
    required this.videoUrl,
    required this.isStarredNote,
  });

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _topicService = TopicService();

  late bool _starredNote;

  // ✅ Local state so edit updates UI without reopening screen
  late String _title;
  late String _notes;
  String? _videoUrl;
  late String _videoType; // none | youtube | storage

  @override
  void initState() {
    super.initState();
    _starredNote = widget.isStarredNote;

    _title = widget.topicTitle;
    _notes = widget.notes;
    _videoUrl = widget.videoUrl?.trim();

    _videoType = _inferVideoType(_videoUrl);
  }

  String _inferVideoType(String? url) {
    final v = (url ?? '').trim();
    if (v.isEmpty) return 'none';
    if (v.contains('youtube.com') || v.contains('youtu.be')) return 'youtube';
    // if it's storage path OR direct mp4 link, treat as storage/video file
    return 'storage';
  }

  Future<void> _toggleStarNote() async {
    final newValue = !_starredNote;

    setState(() => _starredNote = newValue);

    await _topicService.setStarNote(
      courseId: widget.courseId,
      moduleId: widget.moduleId,
      topicId: widget.topicId,
      starred: newValue,
    );
  }

  void _startTopicReview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSessionScreen(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          topicId: widget.topicId,
        ),
      ),
    );
  }

  Future<void> _createQuestion() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMcqQuestionScreen(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          topicId: widget.topicId,
        ),
      ),
    );

    if (ok == true && mounted) {
      setState(() {}); // refresh
    }
  }

  Future<String> _uploadToStorage({
    required File file,
  }) async {
    final ext = file.path.contains('.')
        ? file.path.substring(file.path.lastIndexOf('.'))
        : '.mp4';

    // ✅ same topicId (replace video for this topic)
    final storagePath =
        'videos/${widget.courseId}/${widget.moduleId}/${widget.topicId}$ext';

    final ref = FirebaseStorage.instance.ref(storagePath);
    await ref.putFile(file);

    return storagePath; // store path (not download url)
  }

  Future<void> _deleteStorageIfNeeded(String? type, String? url) async {
    if (type != 'storage') return;
    final p = (url ?? '').trim();
    if (p.isEmpty) return;

    // Only delete when it's a storage path or gs://
    if (p.startsWith('gs://')) {
      final ref = FirebaseStorage.instance.refFromURL(p);
      await ref.delete();
      return;
    }

    // If it's a plain path like videos/...
    if (!p.startsWith('http://') && !p.startsWith('https://')) {
      await FirebaseStorage.instance.ref(p).delete();
    }
  }

  Future<void> _editTopic() async {
    final titleCtrl = TextEditingController(text: _title);
    final notesCtrl = TextEditingController(text: _notes);
    final youtubeCtrl = TextEditingController(
      text: _videoType == 'youtube' ? (_videoUrl ?? '') : '',
    );

    String selected = _videoType; // none | youtube | storage
    File? pickedFile;
    bool saving = false;

    final oldType = _videoType;
    final oldUrl = _videoUrl;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> save() async {
            final newTitle = titleCtrl.text.trim();
            final newNotes = notesCtrl.text.trim();
            final yt = youtubeCtrl.text.trim();

            if (newTitle.isEmpty) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Title is required.')),
              );
              return;
            }

            if (selected == 'youtube' && yt.isEmpty) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Paste a YouTube link.')),
              );
              return;
            }

            if (selected == 'storage' && pickedFile == null) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Please choose a video file.')),
              );
              return;
            }

            setState(() => saving = true);

            try {
              String newVideoType = selected;
              String newVideoUrl = '';

              if (selected == 'none') {
                newVideoType = 'none';
                newVideoUrl = '';
              } else if (selected == 'youtube') {
                newVideoType = 'youtube';
                newVideoUrl = yt;
              } else if (selected == 'storage') {
                // upload new file
                newVideoType = 'storage';
                newVideoUrl = await _uploadToStorage(file: pickedFile!);
              }

              // ✅ Update firestore first
              await _topicService.updateTopic(
                courseId: widget.courseId,
                moduleId: widget.moduleId,
                topicId: widget.topicId,
                title: newTitle,
                notes: newNotes,
                videoType: newVideoType,
                videoUrl: newVideoUrl,
              );

              // ✅ Delete old storage ONLY if we switched away OR replaced with a different path
              final switchedAwayFromStorage =
                  oldType == 'storage' && newVideoType != 'storage';

              final replacedStorage =
                  oldType == 'storage' && newVideoType == 'storage' && oldUrl != newVideoUrl;

              if (switchedAwayFromStorage || replacedStorage) {
                await _deleteStorageIfNeeded(oldType, oldUrl);
              }

              // ✅ Update local UI state
              if (mounted) {
                setState(() {
                  _title = newTitle;
                  _notes = newNotes;
                  _videoType = newVideoType;
                  _videoUrl = newVideoUrl.isEmpty ? null : newVideoUrl;
                });
              }

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            } catch (e) {
              if (!dialogContext.mounted) return;
              setState(() => saving = false);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text('Failed to update topic: $e')),
              );
            }
          }

          return AlertDialog(
            title: const Text('Edit Topic'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: titleCtrl,
                    enabled: !saving,
                    decoration: const InputDecoration(labelText: 'Title'),
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
                    value: 'storage',
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

                  if (selected == 'storage')
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
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = _notes.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit topic',
            onPressed: _editTopic,
          ),
          IconButton(
            icon: Icon(_starredNote ? Icons.star : Icons.star_border),
            tooltip: _starredNote ? 'Unstar note' : 'Star note',
            onPressed: _toggleStarNote,
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Review this topic',
            onPressed: _startTopicReview,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // VIDEO
            const Text(
              'Video',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TopicVideoPlayer(videoUrl: _videoUrl),
            const SizedBox(height: 24),

            // NOTES
            const Text(
              'Notes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              notes.isEmpty ? '(No notes yet)' : notes,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 24),

            // MCQ HEADER
            Row(
              children: [
                const Text(
                  'MCQ Questions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Practice',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PracticeSessionScreen(
                          courseId: widget.courseId,
                          moduleId: widget.moduleId,
                          topicId: widget.topicId,
                          shuffle: false,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.school),
                ),
                IconButton(
                  tooltip: 'Create question',
                  onPressed: _createQuestion,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // MCQ LIST
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FsPaths.questions(
                widget.courseId,
                widget.moduleId,
                widget.topicId,
              ).orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Text('Error: ${snap.error}');
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('No questions yet. Tap Create to add one.'),
                  );
                }

                final questions = docs.map((d) => McqQuestion.fromDoc(d)).toList();

                return Column(
                  children: questions.map((q) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: q.isStarred
                          ? const Icon(Icons.star)
                          : const Icon(Icons.help_outline),
                      title: Text(
                        q.questionText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ViewMcqQuestionScreen(
                              courseId: widget.courseId,
                              moduleId: widget.moduleId,
                              topicId: widget.topicId,
                              questionId: q.id,
                            ),
                          ),
                        );

                        if (changed == true && mounted) {
                          setState(() {});
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
