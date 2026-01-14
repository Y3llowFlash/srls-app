import 'package:flutter/material.dart';
import '../../services/topic_service.dart';

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
            onPressed: _toggleStar,
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

          ],
        ),
      ),
    );
  }
}
