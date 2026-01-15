// screens/review/review_debug_srs_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReviewDebugSrsScreen extends StatelessWidget {
  const ReviewDebugSrsScreen({super.key});

  String _fmtTs(dynamic v) {
    if (v is Timestamp) return v.toDate().toString();
    return v?.toString() ?? '-';
  }

  bool _isDueNow(dynamic v) {
    if (v is! Timestamp) return false;
    return !v.toDate().isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('srs');

    return Scaffold(
      appBar: AppBar(
        title: const Text('DEBUG: SRS Docs'),
        actions: [
          IconButton(
            tooltip: 'Delete broken (empty refId)',
            icon: const Icon(Icons.cleaning_services),
            onPressed: () async {
              final snap = await col.get();
              int deleted = 0;
              for (final d in snap.docs) {
                final data = d.data();
                final refId = (data['refId'] ?? '').toString().trim();
                if (refId.isEmpty) {
                  await d.reference.delete();
                  deleted++;
                }
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted $deleted broken SRS docs')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Set all due now (DEV)',
            icon: const Icon(Icons.schedule),
            onPressed: () async {
              final snap = await col.get();
              final batch = FirebaseFirestore.instance.batch();
              for (final d in snap.docs) {
                batch.set(
                  d.reference,
                  {
                    'dueAt': Timestamp.now(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  },
                  SetOptions(merge: true),
                );
              }
              await batch.commit();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All SRS docs set to due now')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.orderBy('dueAt', descending: false).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No SRS docs found in users/{uid}/srs'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();

              final type = (data['type'] ?? 'unknown').toString();
              final refId = (data['refId'] ?? '').toString();
              final topicId = (data['topicId'] ?? '').toString();
              final courseId = (data['courseId'] ?? '').toString();
              final moduleId = (data['moduleId'] ?? '').toString();

              final dueAt = data['dueAt'];
              final isDue = _isDueNow(dueAt);

              final isStarred = (data['isStarred'] ?? false).toString();
              final reps = (data['reps'] ?? 0).toString();
              final intervalDays = (data['intervalDays'] ?? 0).toString();
              final easeFactor = (data['easeFactor'] ?? 2.5).toString();

              final broken = refId.trim().isEmpty;

              return ListTile(
                leading: Icon(
                  type == 'note' ? Icons.note : (type == 'question' ? Icons.quiz : Icons.help_outline),
                  color: broken ? Colors.red : null,
                ),
                title: Text('${d.id} • $type'),
                subtitle: Text(
                  'refId: ${broken ? "❌ EMPTY" : refId}\n'
                  'topicId: ${topicId.isEmpty ? "-" : topicId}\n'
                  'courseId: ${courseId.isEmpty ? "-" : courseId}\n'
                  'moduleId: ${moduleId.isEmpty ? "-" : moduleId}\n'
                  'dueAt: ${_fmtTs(dueAt)}\n'
                  'isDueNow: $isDue\n'
                  'starred: $isStarred • reps: $reps • int: $intervalDays • ease: $easeFactor',
                ),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      tooltip: 'Set due now',
                      icon: const Icon(Icons.bolt),
                      onPressed: () async {
                        await d.reference.set(
                          {
                            'dueAt': Timestamp.now(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                          SetOptions(merge: true),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Set due now: ${d.id}')),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await d.reference.delete();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Deleted: ${d.id}')),
                          );
                        }
                      },
                    ),
                  ],
                ),
                // quick dev gesture
                onLongPress: () async {
                  await d.reference.delete();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted (long-press): ${d.id}')),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
