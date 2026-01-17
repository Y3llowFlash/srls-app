import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/course_service.dart';

class CourseMembersScreen extends StatefulWidget {
  final String courseId;
  final String courseTitle;

  const CourseMembersScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseMembersScreen> createState() => _CourseMembersScreenState();
}

class _CourseMembersScreenState extends State<CourseMembersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = CourseService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // -------------------------
  // Requests tab
  // -------------------------
  Widget _requestsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchJoinRequests(widget.courseId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No pending requests.'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final uid = d.id;
            final data = d.data();

            final name = (data['displayName'] ?? '') as String;
            final email = (data['email'] ?? '') as String;

            return ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: Text(name.isNotEmpty ? name : email),
              subtitle: Text(email),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () async {
                      try {
                        await _service.rejectJoinRequest(
                          courseId: widget.courseId,
                          uid: uid,
                        );
                        _showSnack('Request rejected');
                      } catch (e) {
                        _showSnack(e.toString());
                      }
                    },
                    child: const Text('Reject'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _service.approveJoinRequest(
                          courseId: widget.courseId,
                          uid: uid,
                        );
                        _showSnack('Member approved');
                      } catch (e) {
                        _showSnack(e.toString());
                      }
                    },
                    child: const Text('Approve'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // -------------------------
  // Members tab
  // -------------------------
  Widget _membersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchMembers(widget.courseId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No members yet.'));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final role = (d.data()['role'] ?? 'student') as String;

            return ListTile(
              leading: const Icon(Icons.group),
              title: Text(d.id),
              subtitle: Text('Role: $role'),
            );
          },
        );
      },
    );
  }

  // -------------------------
  // UI
  // -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Members • ${widget.courseTitle}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _requestsTab(),
          _membersTab(),
        ],
      ),
    );
  }
}
