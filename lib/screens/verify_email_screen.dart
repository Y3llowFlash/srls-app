import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _sending = false;
  String? _msg;

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _msg = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Not signed in.';
      await user.sendEmailVerification();
      setState(() => _msg = 'Verification email resent. Check your inbox.');
    } catch (e) {
      setState(() => _msg = e.toString());
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _iVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    final refreshed = FirebaseAuth.instance.currentUser;

    if (refreshed != null && refreshed.emailVerified) {
      if (!mounted) return;

      setState(() => _msg = 'Verified ✅ Redirecting...');

      // Small delay to allow StreamBuilder to catch the updated user state
      await Future.delayed(const Duration(milliseconds: 300));

      // This will rebuild AuthGate above and it should route to Home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SizedBox.shrink()),
        (route) => false,
      );
      return;
    }
    setState(() => _msg = 'Still not verified. Open the email link, then try again.');
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('We sent a verification link to:\n$email'),
            const SizedBox(height: 12),
            const Text('Open your inbox, tap the link, then come back.'),
            const SizedBox(height: 16),
            if (_msg != null) Text(_msg!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sending ? null : _iVerified,
                child: const Text("I’ve verified"),
              ),
            ),
            TextButton(
              onPressed: _sending ? null : _resend,
              child: Text(_sending ? 'Sending...' : 'Resend email'),
            ),
            TextButton(
              onPressed: _logout,
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
