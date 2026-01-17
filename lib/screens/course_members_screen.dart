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
  late final TabController _tab;
  final _service = CourseService();

  final Set<String> _busy = {}; // prevents double taps

  bool _isBusy(String uid) => _busy.contains(uid);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _runBusy(String uid, Future<void> Function() action) async {
    setState(() => _busy.add(uid));
    try {
      await action();
    } finally {
      if (!mounted) return;
      setState(() => _busy.remove(uid));
    }
  }

  Future<void> _addByEmailDialog() async {
    final ctrl = TextEditingController();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> submit() async {
            final email = ctrl.text.trim();
            if (email.isEmpty) return;

            setState(() => saving = true);
            try {
              await _service.addMemberByEmail(
                courseId: widget.courseId,
                email: email,
              );

              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);

              _snack('Member added ✅');
            } catch (e) {
              if (!dialogContext.mounted) return;
              setState(() => saving = false);
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                SnackBar(content: Text(e.toString())),
              );
            }
          }

          return AlertDialog(
            title: const Text('Add member by email'),
            content: TextField(
              controller: ctrl,
              enabled: !saving,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: 'student@example.com'),
              onSubmitted: (_) => saving ? null : submit(),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving ? null : submit,
                child: saving ? const Text('Adding...') : const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _requestsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchJoinRequests(widget.courseId),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No pending requests.'));

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final uid = d.id;
            final data = d.data();

            final name = (data['displayName'] ?? '') as String;
            final email = (data['email'] ?? '') as String;

            final busy = _isBusy(uid);

            return ListTile(
              leading: const Icon(Icons.person_add_alt_1),
              title: Text(name.isNotEmpty ? name : email),
              subtitle: Text(email),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _runBusy(uid, () async {
                              await _service.rejectJoinRequest(
                                courseId: widget.courseId,
                                uid: uid,
                              );
                              _snack('Rejected');
                            }),
                    child: const Text('Reject'),
                  ),
                  ElevatedButton(
                    onPressed: busy
                        ? null
                        : () => _runBusy(uid, () async {
                              await _service.approveJoinRequest(
                                courseId: widget.courseId,
                                uid: uid,
                                displayName: name,
                                emailLower: email.toLowerCase(),
                              );
                              _snack('Approved ✅');
                            }),
                    child: busy ? const Text('...') : const Text('Approve'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _membersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.watchMembers(widget.courseId),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No members yet.'));

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();

            final role = (data['role'] ?? 'student') as String;
            final name = (data['displayName'] ?? '') as String;
            final email = (data['emailLower'] ?? '') as String;

            final title = name.isNotEmpty ? name : d.id;
            final subtitle = email.isNotEmpty ? '$email • Role: $role' : 'Role: $role';

            return ListTile(
              leading: const Icon(Icons.group),
              title: Text(title),
              subtitle: Text(subtitle),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Members • ${widget.courseTitle}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _addByEmailDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _requestsTab(),
          _membersTab(),
        ],
      ),
    );
  }
}
