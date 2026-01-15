import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/create_course_screen.dart';
import '../models/course.dart';
import 'course_detail_screen.dart';
import 'package:srls_app/screens/review/review_session_screen.dart';

import '../services/stats_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _created = false;
  final _stats = StatsService();

  @override
  void initState() {
    super.initState();
    _ensureUserDoc();
  }

  Future<void> _ensureUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final snap = await ref.get();

      if (!snap.exists) {
        await ref.set({
          'email': user.email,
          'displayName': user.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _created = true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _created = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Widget _progressCard() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _stats.watchToday(defaultGoal: 20),
      builder: (context, snapToday) {
        final done = (snapToday.data?['reviewsDone'] as int?) ?? 0;
        final goal = (snapToday.data?['goal'] as int?) ?? 20;

        final progress = goal <= 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);

        return StreamBuilder<Map<String, dynamic>>(
          stream: _stats.watchSummary(),
          builder: (context, snapSum) {
            final streak = (snapSum.data?['streakDays'] as num?)?.toInt() ?? 0;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Today',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text('🔥 $streak'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('$done / $goal reviews'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome ${user?.displayName ?? ''}\n'
              'Email verified ✅\n'
              'User doc: ${_created ? "created/exists ✅" : "checking..."}',
            ),
            const SizedBox(height: 12),

            // ✅ Daily progress + streak
            _progressCard(),

            const SizedBox(height: 14),

            // ✅ Global Review (session)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReviewSessionScreen()),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Review'),
            ),

            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateCourseScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Create New Course'),
            ),

            const SizedBox(height: 24),
            const Text(
              'My Courses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: uid == null
                  ? const Center(child: Text('Not logged in'))
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('courses')
                          .where('creatorId', isEqualTo: uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text('No courses yet. Create your first one.'),
                          );
                        }

                        final courses =
                            docs.map((d) => Course.fromMap(d.id, d.data())).toList();

                        return ListView.separated(
                          itemCount: courses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final c = courses[i];
                            return ListTile(
                              title: Text(c.title),
                              subtitle: Text(
                                '${c.visibility} • code: ${c.courseCode}'
                                '${c.duplicable ? " • duplicable" : ""}',
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CourseDetailScreen(
                                      courseId: c.id,
                                      courseTitle: c.title,
                                    ),
                                  ),
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
      ),
    );
  }
}
