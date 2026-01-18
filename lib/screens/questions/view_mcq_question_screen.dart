import 'package:flutter/material.dart';
// firebase_auth / cloud_firestore not needed here (SrsService handles auth/db)

import '../../models/mcq_question.dart';
import '../../services/question_service.dart';
import '../../services/srs_service.dart';

import '../../widgets/mcq_storage_image.dart';
import 'create_mcq_question_screen.dart';

class ViewMcqQuestionScreen extends StatefulWidget {
  const ViewMcqQuestionScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.topicId,
    required this.questionId,
  });

  final String courseId;
  final String moduleId;
  final String topicId;
  final String questionId;

  @override
  State<ViewMcqQuestionScreen> createState() => _ViewMcqQuestionScreenState();
}

class _ViewMcqQuestionScreenState extends State<ViewMcqQuestionScreen> {
  final service = QuestionService();
  final srs = SrsService();

  McqQuestion? _question;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final q = await service.getQuestion(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        topicId: widget.topicId,
        questionId: widget.questionId,
      );

      setState(() {
        _question = q;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _toggleStar() async {
    final q = _question;
    if (q == null) return;

    final newValue = !q.isStarred;

    setState(() {
      _question = q.copyWith(isStarred: newValue);
    });

    if (newValue) {
      await srs.ensureQuestionSrs(
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        topicId: widget.topicId,
        questionId: q.id,
        isStarred: true,
      );
    }

    await service.setStarQuestion(
      courseId: widget.courseId,
      moduleId: widget.moduleId,
      topicId: widget.topicId,
      questionId: q.id,
      starred: newValue,
    );

    await srs.setQuestionSrsStarred(questionId: q.id, starred: newValue);
  }

  Future<void> _onEdit() async {
    final q = _question;
    if (q == null) return;

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMcqQuestionScreen(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          topicId: widget.topicId,
          initialQuestion: q,
          questionId: q.id,
        ),
      ),
    );

    if (ok == true && mounted) {
      await _fetch();
    }
  }

  Future<void> _onDelete() async {
    final q = _question;
    if (q == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete question?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // cleanup known image paths
    for (final p in q.questionImagePaths) {
      await service.deleteStoragePathIfAny(p);
    }
    for (final o in q.options) {
      await service.deleteStoragePathIfAny(o.imagePath);
    }

    await service.deleteMcqQuestion(
      courseId: widget.courseId,
      moduleId: widget.moduleId,
      topicId: widget.topicId,
      questionId: q.id,
    );

    await srs.deleteQuestionSrs(q.id);

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  /// Adds this question into the user's SRS (no need to star/unstar first).
  /// Uses current star state to influence future interval math.
  Future<void> _addToSrs() async {
    final q = _question;
    if (q == null) return;

    final created = await srs.addQuestionToSrs(
      courseId: widget.courseId,
      moduleId: widget.moduleId,
      topicId: widget.topicId,
      questionId: q.id,
      isStarred: q.isStarred,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(created ? 'Added to your SRS' : 'Already in your SRS (set due now)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _question;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Question'),
        actions: [
          if (q != null) ...[
            IconButton(
              icon: Icon(q.isStarred ? Icons.star : Icons.star_border),
              tooltip: q.isStarred ? 'Unstar question' : 'Star question',
              onPressed: _toggleStar,
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: _onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: _onDelete,
            ),
            IconButton(
              icon: const Icon(Icons.bolt),
              tooltip: 'Add to SRS',
              onPressed: _addToSrs,
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(child: Text('Error: $_error'))
              : (q == null)
                  ? const Center(child: Text('Question not found'))
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: ListView(
                        children: [
                          if (q.isStarred)
                            const Row(
                              children: [
                                Icon(Icons.star),
                                SizedBox(width: 6),
                                Text('Starred'),
                              ],
                            ),
                          const SizedBox(height: 12),

                          Text(
                            q.questionText,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          if (q.questionImagePaths.isNotEmpty) ...[
                            const Text('Diagrams'),
                            const SizedBox(height: 8),
                            ...q.questionImagePaths.map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: McqStorageImage(path: p),
                                )),
                            const SizedBox(height: 12),
                          ],

                          const Text('Options'),
                          const SizedBox(height: 8),

                          ...q.options.map((opt) {
                            final isCorrect = opt.id == q.correctOptionId;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${opt.id}. ',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Expanded(child: Text(opt.text.isEmpty ? '(no text)' : opt.text)),
                                      if (isCorrect) const Icon(Icons.check_circle),
                                    ],
                                  ),
                                  if ((opt.imagePath ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    McqStorageImage(path: opt.imagePath!.trim(), height: 160),
                                  ],
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 10),
                          Text('Correct Answer: ${q.correctOptionId}', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
    );
  }
}
