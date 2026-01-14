import 'package:flutter/material.dart';
import 'package:srls_app/screens/questions/create_mcq_question_screen.dart' show CreateMcqQuestionScreen;
import '../../services/topic_service.dart';
import '../../services/question_service.dart';
import '../../models/mcq_question.dart';
import '../questions/view_mcq_question_screen.dart';



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
  late bool starred;
  final service = TopicService();
  final questionService = QuestionService();



  @override
  void initState() {
    super.initState();
    starred = widget.isStarredNote;
  }

  Future<void> _toggleStar() async {
    final newValue = !starred;
    setState(() => starred = newValue);

    await service.setStarNote(
      courseId: widget.courseId,
      moduleId: widget.moduleId,
      topicId: widget.topicId,
      starred: newValue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicTitle),
        actions: [
          IconButton(
            icon: Icon(starred ? Icons.star : Icons.star_border),
            tooltip: starred ? 'Unstar note' : 'Star note',
            onPressed: _toggleStar,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Question',
            onPressed: () async {
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

              if (ok == true) setState(() {});
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [

            const Text('Video',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.videoUrl == null)
              const Text('(No video attached)')
            else
              SelectableText(widget.videoUrl!),

            const SizedBox(height: 24),
            const Text('Notes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              widget.notes.isEmpty ? '(No notes yet)' : widget.notes,
              style: const TextStyle(fontSize: 16, height: 1.4),
            ),

            const SizedBox(height: 24),
            const Text('Questions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            StreamBuilder<List<McqQuestion>>(
              stream: questionService.streamQuestions(
                courseId: widget.courseId,
                moduleId: widget.moduleId,
                topicId: widget.topicId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                final questions = snapshot.data ?? [];

                if (questions.isEmpty) {
                  return const Text('(No questions yet)');
                }

                return Column(
                  children: questions.map((q) {
                    return ListTile(
                      leading: q.isStarred ? const Icon(Icons.star) : const Icon(Icons.help_outline),
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

                        if (changed == true) {
                          setState(() {}); // refresh list after edit/delete
                        }
                      },
                    );
                  }).toList(),
                );
              },
            ),


            ElevatedButton(
              onPressed: () async {
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

                if (ok == true) {
                  setState(() {}); // refresh if needed
                }
              },
              child: const Text('Add Question'),
            ),


          ],
        ),
      ),
    );
  }
}
