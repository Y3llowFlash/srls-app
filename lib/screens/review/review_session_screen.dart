import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/review_queue_item.dart';
import '../../models/topic_model.dart';
import '../../models/mcq_question.dart';
import '../../services/review_queue_service.dart';
import '../../services/review_content_service.dart';
import '../../services/srs_service.dart';
import '../../utils/srs_math.dart';

class ReviewSessionScreen extends StatefulWidget {
  const ReviewSessionScreen({
    super.key,
    this.courseId,
    this.moduleId,
    this.topicId,
    this.type, // "note" | "question" | null
  });

  final String? courseId;
  final String? moduleId;
  final String? topicId;
  final String? type;

  @override
  State<ReviewSessionScreen> createState() => _ReviewSessionScreenState();
}

class _ReviewSessionScreenState extends State<ReviewSessionScreen> {
  final _queue = ReviewQueueService();
  final _content = ReviewContentService();
  final _srs = SrsService();

  bool _loading = true;
  Object? _error;

  List<ReviewQueueItem> _items = [];
  int _index = 0;

  bool _revealed = false;

  TopicModel? _topic;
  McqQuestion? _question;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  String _extractQuestionId(String srsDocId) {
    if (srsDocId.startsWith('q_')) return srsDocId.substring(2);
    return srsDocId;
  }

  Future<void> _loadQueue() async {
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _index = 0;
      _revealed = false;
      _topic = null;
      _question = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      // One-time fetch for a “session”
      final items = await _queue.getDueReviews(
        uid: uid,
        type: widget.type,
        courseId: widget.courseId,
        moduleId: widget.moduleId,
        topicId: widget.topicId,
        limit: 100,
      );

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });

      if (items.isNotEmpty) {
        await _loadCurrentContent();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadCurrentContent() async {
    final it = _items[_index];

    setState(() {
      _revealed = false;
      _topic = null;
      _question = null;
    });

    try {
      if (it.type == 'note') {
        final t = await _content.getTopic(
          courseId: it.courseId,
          moduleId: it.moduleId,
          topicId: it.topicId,
        );
        if (!mounted) return;
        setState(() => _topic = t);
      } else {
        final qid = _extractQuestionId(it.id);
        final q = await _content.getQuestion(
          courseId: it.courseId,
          moduleId: it.moduleId,
          topicId: it.topicId,
          questionId: qid,
        );
        if (!mounted) return;
        setState(() => _question = q);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _rate(ReviewRating rating) async {
    final it = _items[_index];

    await _srs.applyReviewUnified(
      srsDocId: it.id,
      isStarred: true,
      reps: it.reps,
      intervalDays: it.intervalDays,
      easeFactor: it.easeFactor,
      rating: rating,
    );

    // Move to next card in session
    if (!mounted) return;

    setState(() {
      _index += 1;
    });

    if (_index >= _items.length) {
      // Session done
      return;
    }

    await _loadCurrentContent();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: Center(child: Text('Error: $_error')),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: const Center(child: Text('No reviews due 🎉')),
      );
    }

    if (_index >= _items.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Session complete 🎉'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    final it = _items[_index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('${_index + 1}/${_items.length}'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(child: _buildCard(it)),
            const SizedBox(height: 12),

            // Reveal + rating row
            if (!_revealed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: const Text('Reveal'),
                ),
              )
            else
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

  Widget _buildCard(ReviewQueueItem it) {
    // Loading content placeholders
    if (it.type == 'note' && _topic == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (it.type == 'question' && _question == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // ✅ Note card
    if (it.type == 'note') {
      final t = _topic!;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListView(
          children: [
            Text(
              t.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_revealed)
              Text(t.notes ?? '(No notes)')
            else
              const Text('Recall the notes in your mind…'),
          ],
        ),
      );
    }

    // ✅ Question card
    final q = _question!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView(
        children: [
          Text(
            q.questionText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          ...q.options.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${o.id}. ${o.text}'),
              )),
          const SizedBox(height: 12),
          if (_revealed)
            Text(
              '✅ Correct: ${q.correctOptionId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
