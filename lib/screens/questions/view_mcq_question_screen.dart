import 'package:flutter/material.dart';
import '../../models/mcq_question.dart';
import '../../services/question_service.dart';
import 'create_mcq_question_screen.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/srs_service.dart';
import '../../utils/srs_math.dart';


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

    // optimistic UI update without copyWith
    setState(() {
      _question = McqQuestion(
        id: q.id,
        questionText: q.questionText,
        options: q.options,
        correctOptionId: q.correctOptionId,
        isStarred: newValue,
        questionImageMediaId: q.questionImageMediaId,
      );
    });

    await service.setStarQuestion(
      courseId: widget.courseId,
      moduleId: widget.moduleId,
      topicId: widget.topicId,
      questionId: q.id,
      starred: newValue,
    );
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
      await _fetch(); // refresh the view
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

    await service.deleteMcqQuestion(
      courseId: widget.courseId,
      moduleId: widget.moduleId,
      topicId: widget.topicId,
      questionId: q.id,
    );

    if (!mounted) return;
    Navigator.pop(context, true); // tell Topic screen to refresh list
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
                tooltip: 'Test: review EASY',
                onPressed: () async {
                  final q = _question;
                  if (q == null) return;

                  // you need the srs doc to exist already (star first)
                  final srs = SrsService();

                  // read srs doc current fields (simple fetch)
                  final snap = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .collection('srs')
                      .doc('questions')
                      .collection('items')
                      .doc(q.id)
                      .get();

                  final d = snap.data() ?? {};
                  final reps = (d['reps'] ?? 0) as int;
                  final intervalDays = (d['intervalDays'] ?? 0) as int;
                  final easeFactor = ((d['easeFactor'] ?? 2.5) as num).toDouble();
                  final isStarred = (d['isStarred'] ?? true) as bool;

                  await srs.applyReview(
                    collection: SrsCollection.questions,
                    itemId: q.id,
                    isStarred: isStarred,
                    reps: reps,
                    intervalDays: intervalDays,
                    easeFactor: easeFactor,
                    rating: ReviewRating.easy,
                  );

                  if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Applied EASY review (check Firestore dueAt)')),
                  );
                },
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...q.options.map((opt) {
                            final isCorrect = opt.id == q.correctOptionId;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    '${opt.id}. ',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(child: Text(opt.text)),
                                  if (isCorrect)
                                    const Icon(Icons.check_circle),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 10),
                          Text(
                            'Correct Answer: ${q.correctOptionId}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
