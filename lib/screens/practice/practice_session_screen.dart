import 'package:flutter/material.dart';

import '../../models/mcq_question.dart';
import '../../services/firestore_paths.dart';

class PracticeSessionScreen extends StatefulWidget {
  const PracticeSessionScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.topicId,
    this.shuffle = false,
  });

  final String courseId;
  final String moduleId;
  final String topicId;
  final bool shuffle;

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  bool _loading = true;
  Object? _error;

  List<McqQuestion> _questions = [];
  int _index = 0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _questions = [];
      _index = 0;
      _revealed = false;
    });

    try {
      final snap = await FsPaths.questions(
        widget.courseId,
        widget.moduleId,
        widget.topicId,
      ).get();

      final qs = snap.docs.map((d) => McqQuestion.fromDoc(d)).toList();
      if (widget.shuffle) {
        qs.shuffle();
      }

      if (!mounted) return;
      setState(() {
        _questions = qs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _next() {
    setState(() {
      _revealed = false;
      _index += 1;
    });
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
        appBar: AppBar(title: const Text('Practice')),
        body: Center(child: Text('Error: $_error')),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: const Center(child: Text('No questions in this topic.')),
      );
    }

    if (_index >= _questions.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Practice')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Practice complete 🎉'),
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

    final q = _questions[_index];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('${_index + 1}/${_questions.length}'),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView(
                  children: [
                    Text(
                      q.questionText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
              ),
            ),
            const SizedBox(height: 12),

            if (!_revealed)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: const Text('Reveal'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: const Text('Next'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
