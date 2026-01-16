import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/mcq_option.dart';
import '../../models/mcq_question.dart';
import '../../services/firestore_paths.dart';
import '../../services/question_service.dart';

class CreateMcqQuestionScreen extends StatefulWidget {
  const CreateMcqQuestionScreen({
    super.key,
    required this.courseId,
    required this.moduleId,
    required this.topicId,
    this.initialQuestion,
    this.questionId,
  });

  final String courseId;
  final String moduleId;
  final String topicId;

  final McqQuestion? initialQuestion;
  final String? questionId;

  @override
  State<CreateMcqQuestionScreen> createState() => _CreateMcqQuestionScreenState();
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

  // Question images (0..3)
  final List<File?> _pickedQuestionFiles = [null, null, null];
  late List<String> _existingQuestionPaths; // from Firestore

  // Option images (0..1 each)
  final Map<String, File?> _pickedOptionFiles = {'A': null, 'B': null, 'C': null, 'D': null};
  late Map<String, String?> _existingOptionPaths;

  @override
  void initState() {
    super.initState();

    final q = widget.initialQuestion;
    _existingQuestionPaths = List<String>.from(q?.questionImagePaths ?? const []);
    _existingOptionPaths = {
      'A': null,
      'B': null,
      'C': null,
      'D': null,
    };

    if (q != null) {
      _qController.text = q.questionText;
      _correctOptionId = q.correctOptionId;
      _isStarred = q.isStarred;

      for (final opt in q.options) {
        switch (opt.id) {
          case 'A':
            _aController.text = opt.text;
            _existingOptionPaths['A'] = opt.imagePath;
            break;
          case 'B':
            _bController.text = opt.text;
            _existingOptionPaths['B'] = opt.imagePath;
            break;
          case 'C':
            _cController.text = opt.text;
            _existingOptionPaths['C'] = opt.imagePath;
            break;
          case 'D':
            _dController.text = opt.text;
            _existingOptionPaths['D'] = opt.imagePath;
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

    final correctHasImage = (_existingOptionPaths[_correctOptionId] ?? '').trim().isNotEmpty ||
        _pickedOptionFiles[_correctOptionId] != null;

    if (correctText.isEmpty && !correctHasImage) {
      _snack('Correct option must have text or an image');
      return false;
    }

    return true;
  }

  Future<File?> _pickOneImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  Future<void> _pickQuestionSlot(int i) async {
    final f = await _pickOneImage();
    if (f == null) return;
    setState(() => _pickedQuestionFiles[i] = f);
  }

  void _removeQuestionSlot(int i) {
    setState(() {
      // if slot is in existing list, remove it (and delete later on save)
      if (i < _existingQuestionPaths.length) {
        _existingQuestionPaths[i] = '';
      }
      _pickedQuestionFiles[i] = null;
    });
  }

  Future<void> _pickOptionImage(String id) async {
    final f = await _pickOneImage();
    if (f == null) return;
    setState(() => _pickedOptionFiles[id] = f);
  }

  void _removeOptionImage(String id) {
    setState(() {
      _existingOptionPaths[id] = '';
      _pickedOptionFiles[id] = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validate()) return;

    if (_isEditMode && (widget.questionId == null || widget.questionId!.isEmpty)) {
      _snack('Edit mode error: questionId is missing');
      return;
    }

    setState(() => _saving = true);

    final questionId = _isEditMode
        ? widget.questionId!
        : FsPaths.questions(widget.courseId, widget.moduleId, widget.topicId).doc().id;

    try {
      // 1) Upload/resolve question image paths (0..3)
      final List<String> finalQuestionPaths = [];
      for (int i = 0; i < 3; i++) {
        final existing = (i < _existingQuestionPaths.length) ? _existingQuestionPaths[i].trim() : '';
        final picked = _pickedQuestionFiles[i];

        // if removed existing
        if (existing.isNotEmpty && picked == null) {
          // keep existing
          finalQuestionPaths.add(existing);
          continue;
        }

        // if user cleared it
        if (existing.isNotEmpty && (i < _existingQuestionPaths.length) && _existingQuestionPaths[i].trim().isEmpty) {
          await _service.deleteStoragePathIfAny(existing);
          continue;
        }

        if (picked != null) {
          // replacing old image if existed
          if (existing.isNotEmpty) {
            await _service.deleteStoragePathIfAny(existing);
          }
          final newPath = await _service.uploadQuestionImage(
            courseId: widget.courseId,
            moduleId: widget.moduleId,
            topicId: widget.topicId,
            questionId: questionId,
            slotIndex: i,
            file: picked,
          );
          finalQuestionPaths.add(newPath);
        } else if (existing.isNotEmpty) {
          finalQuestionPaths.add(existing);
        }
      }

      // remove blanks
      finalQuestionPaths.removeWhere((e) => e.trim().isEmpty);

      // 2) Upload/resolve option images
      Future<String?> resolveOptionPath(String id) async {
        final existing = (_existingOptionPaths[id] ?? '').trim();
        final picked = _pickedOptionFiles[id];

        // Only treat as "removed" if user explicitly clicked remove (we set it to '')
        final explicitlyRemoved = _existingOptionPaths[id] == '';

        if (explicitlyRemoved && picked == null) {
          if (widget.initialQuestion != null) {
            final old = widget.initialQuestion!.options
                .firstWhere((o) => o.id == id, orElse: () => McqOption(id: id, text: ''))
                .imagePath;
            await _service.deleteStoragePathIfAny(old);
          }
          return null;
        }

        // If user picked a new image, upload it (create OR edit)
        if (picked != null) {
          if (existing.isNotEmpty) {
            await _service.deleteStoragePathIfAny(existing);
          }
          final newPath = await _service.uploadOptionImage(
            courseId: widget.courseId,
            moduleId: widget.moduleId,
            topicId: widget.topicId,
            questionId: questionId,
            optionId: id,
            file: picked,
          );
          return newPath;
        }

        // Otherwise keep whatever was already there
        return existing.isEmpty ? null : existing;
      }


      final aImg = await resolveOptionPath('A');
      final bImg = await resolveOptionPath('B');
      final cImg = await resolveOptionPath('C');
      final dImg = await resolveOptionPath('D');

      final options = <McqOption>[
        McqOption(id: 'A', text: _aController.text.trim(), imagePath: aImg),
        McqOption(id: 'B', text: _bController.text.trim(), imagePath: bImg),
      ];

      final cText = _cController.text.trim();
      final dText = _dController.text.trim();
      if (cText.isNotEmpty || (cImg != null && cImg.trim().isNotEmpty)) {
        options.add(McqOption(id: 'C', text: cText, imagePath: cImg));
      }
      if (dText.isNotEmpty || (dImg != null && dImg.trim().isNotEmpty)) {
        options.add(McqOption(id: 'D', text: dText, imagePath: dImg));
      }

      final question = McqQuestion(
        id: questionId,
        questionText: _qController.text.trim(),
        questionImagePaths: finalQuestionPaths,
        options: options,
        correctOptionId: _correctOptionId,
        isStarred: _isStarred,
      );

      if (!_isEditMode) {
        // create with chosen id
        await FsPaths.questionDoc(widget.courseId, widget.moduleId, widget.topicId, questionId)
            .set(question.toMapForCreate());
      } else {
        await _service.updateMcqQuestion(
          courseId: widget.courseId,
          moduleId: widget.moduleId,
          topicId: widget.topicId,
          questionId: questionId,
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
              onChanged: _saving ? null : (v) => setState(() => _correctOptionId = v ?? 'A'),
            ),
            Text(id),
          ],
        );

    return Wrap(spacing: 12, children: [item('A'), item('B'), item('C'), item('D')]);
  }

  Widget _questionImageSlot(int i) {
    final existing = (i < _existingQuestionPaths.length) ? _existingQuestionPaths[i].trim() : '';
    final picked = _pickedQuestionFiles[i];

    final label = picked != null
        ? picked.path.split(Platform.pathSeparator).last
        : existing.isNotEmpty
            ? 'Image attached'
            : 'Empty';

    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(border: Border.all(), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(child: Text('Q Image ${i + 1}: $label', maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _saving ? null : () => _pickQuestionSlot(i),
            child: const Text('Pick'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Remove',
            onPressed: _saving ? null : () => _removeQuestionSlot(i),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _optionImageRow(String id) {
    final existing = (_existingOptionPaths[id] ?? '').trim();
    final picked = _pickedOptionFiles[id];

    final label = picked != null
        ? picked.path.split(Platform.pathSeparator).last
        : existing.isNotEmpty
            ? 'Image attached'
            : 'None';

    return Row(
      children: [
        Expanded(child: Text('Image: $label', maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _saving ? null : () => _pickOptionImage(id),
          child: const Text('Pick'),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Remove',
          onPressed: _saving ? null : () => _removeOptionImage(id),
          icon: const Icon(Icons.close),
        ),
      ],
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
                onChanged: _saving ? null : (v) => setState(() => _isStarred = v),
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
            const SizedBox(height: 14),

            const Text('Question Images (0–3)'),
            const SizedBox(height: 8),
            _questionImageSlot(0),
            _questionImageSlot(1),
            _questionImageSlot(2),

            const SizedBox(height: 16),
            const Text('Options'),
            const SizedBox(height: 8),

            TextField(
              controller: _aController,
              decoration: const InputDecoration(labelText: 'A', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            _optionImageRow('A'),
            const SizedBox(height: 12),

            TextField(
              controller: _bController,
              decoration: const InputDecoration(labelText: 'B', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            _optionImageRow('B'),
            const SizedBox(height: 12),

            TextField(
              controller: _cController,
              decoration: const InputDecoration(labelText: 'C (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            _optionImageRow('C'),
            const SizedBox(height: 12),

            TextField(
              controller: _dController,
              decoration: const InputDecoration(labelText: 'D (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            _optionImageRow('D'),

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
