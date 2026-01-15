import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../practice/practice_session_screen.dart';

import '../../models/mcq_question.dart';
import '../../services/firestore_paths.dart';
import '../../services/topic_service.dart';
import '../questions/create_mcq_question_screen.dart';
import '../questions/view_mcq_question_screen.dart';
import '../review/review_session_screen.dart';

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

  late bool _starredNote = widget.isStarredNote;

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
    // Reviews BOTH notes + questions for this topic
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

  void _startQuestionReview() {
    // Reviews ONLY questions in this topic
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewSessionScreen(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          topicId: widget.topicId,
          type: 'question',
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

  @override
  Widget build(BuildContext context) {
    final video = widget.videoUrl?.trim() ?? '';
    final notes = widget.notes.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicTitle),
        actions: [
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
            // =======================
            // VIDEO (TOP)
            // =======================
            const Text(
              'Video',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (video.isEmpty)
              const Text('(No video attached)')
            else
              SelectableText(video),

            const SizedBox(height: 24),

            // =======================
            // NOTES (UNDER VIDEO)
            // =======================
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

            // =======================
            // MCQ SECTION HEADER + BUTTONS
            // =======================
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

            // =======================
            // MCQ LIST (Firestore stream)
            // =======================
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FsPaths.questions(
                widget.courseId,
                widget.moduleId,
                widget.topicId,
              ).orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Text('Error: ${snap.error}');
                }
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

                final questions =
                    docs.map((d) => McqQuestion.fromDoc(d)).toList();

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
