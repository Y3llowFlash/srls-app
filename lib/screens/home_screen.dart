import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/course_service.dart';
import '../utils/course_code.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _created = false;

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
      final snap = await ref.get(); // may fail on poor net

      if (!snap.exists) {
        await ref.set({
          'email': user.email,
          'displayName': user.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _created = true);
    } catch (e) {
      // If offline/unavailable, DO NOT crash the app.
      // Just show "checking..." and let it succeed later.
      if (!mounted) return;
      setState(() => _created = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),


      body: Center(
        child: Column(
          children: [
            Text(
              'Welcome ${user?.displayName ?? ''}\n'
              'Email verified ✅\n'
              'User doc: ${_created ? "created/exists ✅" : "checking..."}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                try {
                  final code = generateCourseCode();
                  await CourseService().createCourse(
                    title: 'Math 101',
                    description: 'Demo course created from Day 2 test',
                    visibility: 'public',
                    duplicable: true,
                    courseCode: code,
                  );

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Course saved ✅ Code: $code')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed ❌ $e')),
                  );
                }
              },
              child: const Text('Create Test Course'),
            ),
          ],
        ),
        
      ),



      
    );
  }
}
