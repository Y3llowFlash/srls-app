import 'package:flutter/material.dart';
import '../../models/mcq_option.dart';
import '../../models/mcq_question.dart';
import '../../services/question_service.dart';

class CreateMcqQuestionScreen extends StatefulWidget {
  const CreateMcqQuestionScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.topicId,
    this.initialQuestion, // null => create
    this.questionId, // required when editing
  });

  final String courseId;
  final String moduleId;
  final String topicId;

  final McqQuestion? initialQuestion;
  final String? questionId;

  @override
  State<CreateMcqQuestionScreen> createState() =>
      _CreateMcqQuestionScreenState();
}

class _CreateMcqQuestionScreenState extends State<CreateMcqQuestionScreen> {
  final _service = QuestionService();

  final _qController = TextEditingController();
  final _aController = TextEditingController();
  final _bController = TextEditingController();
  final _cController = TextEditingController();
  final _dController = TextEditingController();

  String _correctOptionId = 'A';
  bool _isStarred = false;
  bool _saving = false;

  bool get _isEditMode => widget.initialQuestion != null;

  @override
  void initState() {
    super.initState();

    // ✅ Prefill when editing
    final q = widget.initialQuestion;
    if (q != null) {
      _qController.text = q.questionText;
      _correctOptionId = q.correctOptionId;
      _isStarred = q.isStarred;

      for (final opt in q.options) {
        switch (opt.id) {
          case 'A':
            _aController.text = opt.text;
            break;
          case 'B':
            _bController.text = opt.text;
            break;
          case 'C':
            _cController.text = opt.text;
            break;
          case 'D':
            _dController.text = opt.text;
            break;
        }
      }
    }
  }

  @override
  void dispose() {
    _qController.dispose();
    _aController.dispose();
    _bController.dispose();
    _cController.dispose();
    _dController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _validate() {
    final q = _qController.text.trim();
    final a = _aController.text.trim();
    final b = _bController.text.trim();
    final c = _cController.text.trim();
    final d = _dController.text.trim();

    if (q.isEmpty) {
      _snack('Question text is required');
      return false;
    }
    if (a.isEmpty || b.isEmpty) {
      _snack('At least options A and B are required');
      return false;
    }

    final correctText = switch (_correctOptionId) {
      'A' => a,
      'B' => b,
      'C' => c,
      'D' => d,
      _ => a,
    };

    if (correctText.isEmpty) {
      _snack('Correct answer option must have text');
      return false;
    }

    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validate()) return;

    // edit mode safety
    if (_isEditMode && (widget.questionId == null || widget.questionId!.isEmpty)) {
      _snack('Edit mode error: questionId is missing');
      return;
    }

    setState(() => _saving = true);

    try {
      final options = <McqOption>[
        McqOption(id: 'A', text: _aController.text.trim(), imageMediaId: null),
        McqOption(id: 'B', text: _bController.text.trim(), imageMediaId: null),
      ];

      final cText = _cController.text.trim();
      final dText = _dController.text.trim();
      if (cText.isNotEmpty) options.add(McqOption(id: 'C', text: cText));
      if (dText.isNotEmpty) options.add(McqOption(id: 'D', text: dText));

      final question = McqQuestion(
        // for create: ignored
        // for edit: still not needed because we pass questionId separately
        id: _isEditMode ? widget.questionId! : '',
        questionText: _qController.text.trim(),
        options: options,
        correctOptionId: _correctOptionId,
        isStarred: _isStarred,
        questionImageMediaId: null,
      );

      if (!_isEditMode) {
        // ✅ CREATE
        await _service.createMcqQuestion(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          topicId: widget.topicId,
          question: question,
        );
      } else {
        // ✅ UPDATE
        await _service.updateMcqQuestion(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          topicId: widget.topicId,
          questionId: widget.questionId!,
          question: question,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _correctPicker() {
    Widget item(String id) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Radio<String>(
              value: id,
              groupValue: _correctOptionId,
              onChanged: (v) => setState(() => _correctOptionId = v ?? 'A'),
            ),
            Text(id),
          ],
        );

    return Wrap(
      spacing: 12,
      children: [item('A'), item('B'), item('C'), item('D')],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit MCQ' : 'Create MCQ'),
        actions: [
          Row(
            children: [
              const Text('⭐'),
              Switch(
                value: _isStarred,
                onChanged: (v) => setState(() => _isStarred = v),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _qController,
              decoration: const InputDecoration(
                labelText: 'Question text',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 16),

            const Text('Options'),
            const SizedBox(height: 8),

            TextField(
              controller: _aController,
              decoration: const InputDecoration(
                labelText: 'A',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _bController,
              decoration: const InputDecoration(
                labelText: 'B',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _cController,
              decoration: const InputDecoration(
                labelText: 'C (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _dController,
              decoration: const InputDecoration(
                labelText: 'D (optional)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),
            const Text('Correct answer'),
            _correctPicker(),

            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : (_isEditMode ? 'Update' : 'Save')),
            ),
          ],
        ),
      ),
    );
  }
}
