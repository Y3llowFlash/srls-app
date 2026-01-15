import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewDebugSrsScreen extends StatelessWidget {
  const ReviewDebugSrsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Not logged in')));
    }

    final q = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('srs')
        .orderBy('dueAt', descending: false);

    return Scaffold(
      appBar: AppBar(title: const Text('DEBUG: SRS Docs')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No SRS docs found in users/{uid}/srs'));
          }

          final now = DateTime.now();

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();
              final dueAtRaw = m['dueAt'];
              DateTime? dueAt;

              if (dueAtRaw is Timestamp) dueAt = dueAtRaw.toDate();

              final isDue = dueAt != null && !dueAt.isAfter(now);

              return ListTile(
                title: Text('${d.id}  •  ${m['type'] ?? ''}'),
                subtitle: Text('dueAt: $dueAtRaw\nisDueNow: $isDue'),
              );
            },
          );
        },
      ),
    );
  }
}
  