import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/review_queue_item.dart';
import '../../models/topic_model.dart';
import '../../models/mcq_question.dart';
import '../../services/review_queue_service.dart';
import '../../services/review_content_service.dart';
import '../../services/srs_service.dart';
import '../../services/stats_service.dart';
import '../../utils/srs_math.dart';
import 'review_debug_srs_screen.dart';
import '../../widgets/mcq_storage_image.dart';

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
  final _stats = StatsService();

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
      // If this happens, it’s usually legacy/orphan SRS pointing to deleted content.
      // For MVP: show an error but also allow user to move forward by rating "Hard" after reveal.
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _rate(ReviewRating rating) async {
    final it = _items[_index];

    // Guard: don’t allow rating until reveal (Anki/RemNote feel)
    if (!_revealed) return;

    try {
      await _srs.applyReviewUnified(
        srsDocId: it.id,
        isStarred: true,
        reps: it.reps,
        intervalDays: it.intervalDays,
        easeFactor: it.easeFactor,
        rating: rating,
      );

      // ✅ Progress + streak update after each successful review
      await _stats.recordReview(defaultGoal: 20);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      return;
    }

    if (!mounted) return;

    setState(() {
      _index += 1;
      _error = null; // clear any prior content error once review passes
    });

    if (_index >= _items.length) return;

    await _loadCurrentContent();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'Debug SRS',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReviewDebugSrsScreen()),
                );
              },
            ),
          ],
        ),
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
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug SRS',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReviewDebugSrsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(child: _buildCard(it)),
            const SizedBox(height: 12),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Content issue: $_error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Reveal + rating
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
    if (it.type == 'note' && _topic == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (it.type == 'question' && _question == null) {
      return const Center(child: CircularProgressIndicator());
    }

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
              Text(t.notes)
            else
              const Text('Recall the notes in your mind…'),
          ],
        ),
      );
    }

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

          // ✅ Question images (0..3)
          if (q.questionImagePaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...q.questionImagePaths
                .where((p) => p.trim().isNotEmpty)
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: McqStorageImage(path: p, height: 200),
                  ),
                ),
          ],

          const SizedBox(height: 14),

          // ✅ Options (text + optional image)
          ...q.options.map((o) {
            final img = o.imagePath?.trim();
            final hasImg = img != null && img.isNotEmpty;

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
                  Text('${o.id}. ${o.text}'),
                  if (hasImg) ...[
                    const SizedBox(height: 8),
                    McqStorageImage(path: img, height: 140),
                  ],
                ],
              ),
            );
          }),

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
