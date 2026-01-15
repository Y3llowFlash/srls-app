import 'package:flutter/material.dart';

import '../../models/review_queue_item.dart';
import '../../models/topic_model.dart';
import '../../models/mcq_question.dart';
import '../../services/review_content_service.dart';
import '../../services/srs_service.dart';
import '../../utils/srs_math.dart';

class ReviewItemScreen extends StatefulWidget {
  const ReviewItemScreen({
    super.key,
    required this.item,
  });

  final ReviewQueueItem item;

  @override
  State<ReviewItemScreen> createState() => _ReviewItemScreenState();
}

class _ReviewItemScreenState extends State<ReviewItemScreen> {
  final _content = ReviewContentService();
  final _srs = SrsService();

  bool _loading = true;
  Object? _error;

  TopicModel? _topic;
  McqQuestion? _question;

  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  String _extractQuestionId(String srsDocId) {
    // unified id is "q_{questionId}"
    if (srsDocId.startsWith('q_')) return srsDocId.substring(2);
    return srsDocId;
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
      _topic = null;
      _question = null;
      _revealed = false;
    });

    try {
      final it = widget.item;

      if (it.type == 'note') {
        final t = await _content.getTopic(
          courseId: it.courseId,
          moduleId: it.moduleId,
          topicId: it.topicId,
        );
        if (!mounted) return;
        setState(() {
          _topic = t;
          _loading = false;
        });
      } else {
        final questionId = _extractQuestionId(it.id);

        final q = await _content.getQuestion(
          courseId: it.courseId,
          moduleId: it.moduleId,
          topicId: it.topicId,
          questionId: questionId,
        );
        if (!mounted) return;
        setState(() {
          _question = q;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _rate(ReviewRating rating) async {
    final it = widget.item;

    await _srs.applyReviewUnified(
      srsDocId: it.id,
      // Review queue only shows due items that are starred, so keep true.
      // (Your ReviewQueueItem model doesn’t store isStarred)
      isStarred: true,
      reps: it.reps,
      intervalDays: it.intervalDays,
      easeFactor: it.easeFactor,
      rating: rating,
    );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(it.type == 'note' ? 'Review Note' : 'Review Question'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _revealed = !_revealed),
            child: Text(_revealed ? 'Hide' : 'Reveal'),
          ),
          
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(child: Text('Error: $_error'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(child: _buildContent(it)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _rate(ReviewRating.hard),
                              child: const Text('Hard'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _rate(ReviewRating.medium),
                              child: const Text('Medium'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _rate(ReviewRating.easy),
                              child: const Text('Easy'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildContent(ReviewQueueItem it) {
    if (it.type == 'note') {
      final t = _topic;
      if (t == null) return const Text('Topic not found');

      return ListView(
        children: [
          Text(
            t.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('Try recalling the notes.'),
          const SizedBox(height: 12),
          if (_revealed)
            Text(t.notes)
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Tap “Reveal” to show notes.'),
            ),
          const SizedBox(height: 12),
          if (t.videoUrl != null && t.videoUrl!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('🎥 Video: ${t.videoUrl}'),
          ],
        ],
      );
    }

    final q = _question;
    if (q == null) return const Text('Question not found');

    return ListView(
      children: [
        Text(
          q.questionText,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        ...q.options.map((o) {
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
                  '${o.id}. ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Expanded(child: Text(o.text)),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        if (_revealed)
          Text(
            '✅ Correct: ${q.correctOptionId}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Tap “Reveal” to show the correct answer.'),
          ),
      ],
    );
  }
}
