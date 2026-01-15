import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/review_queue_item.dart';
import '../../services/review_queue_service.dart';
import '../../services/srs_service.dart';
import 'review_debug_srs_screen.dart';

class ReviewQueueScreen extends StatefulWidget {
  const ReviewQueueScreen({
    super.key,
    this.courseId,
    this.moduleId,
    this.topicId,
    this.type,
  });

  final String? courseId;
  final String? moduleId;
  final String? topicId;
  final String? type; // "note" | "question" | null

  @override
  State<ReviewQueueScreen> createState() => _ReviewQueueScreenState();
}

class _ReviewQueueScreenState extends State<ReviewQueueScreen> {
  final _queueService = ReviewQueueService();
  final _srsService = SrsService();

  bool _migrationDone = false;
  bool _migrationError = false;

  @override
  void initState() {
    super.initState();
    _runMigration();
  }

  Future<void> _runMigration() async {
    try {
      await _srsService.migrateLegacyToUnified();
      if (!mounted) return;
      setState(() {
        _migrationDone = true;
        _migrationError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _migrationDone = true;
        _migrationError = true;
      });
      // optional: print for debugging
      // debugPrint('SRS migration failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Queue'),
        actions: [
          IconButton(
            tooltip: 'Debug SRS',
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReviewDebugSrsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Migration status banner (small + helpful)
          if (!_migrationDone)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Preparing reviews...'),
                ],
              ),
            )
          else if (_migrationError)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Migration warning: legacy SRS not copied. New items should still work.',
              ),
            ),

          Expanded(
            child: StreamBuilder<List<ReviewQueueItem>>(
              stream: _queueService.watchDueReviews(
                uid: uid,
                type: widget.type,
                courseId: widget.courseId,
                moduleId: widget.moduleId,
                topicId: widget.topicId,
                limit: 100,
              
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('No reviews due 🎉'));
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final icon = it.type == 'note' ? Icons.note : Icons.quiz;

                    return ListTile(
                      leading: Icon(icon),
                      title: Text('${it.type.toUpperCase()} • ${it.id}'),
                      subtitle: Text('dueAt: ${it.dueAt}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // Round 2 will open the Review Screen.
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Round 2: open review for ${it.id}')),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
