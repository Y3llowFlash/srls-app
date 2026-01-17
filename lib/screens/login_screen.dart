import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text;

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // If AuthGate already swapped screens, stop here safely.
      if (!mounted) return;

      await cred.user?.reload();

      // Screen might still get disposed during reload -> guard again
      if (!mounted) return;

      final user = FirebaseAuth.instance.currentUser;

      // Block unverified users
      if (user != null && !user.emailVerified) {
        if (!mounted) return;
        setState(() {
          _error =
              'Email not verified yet. Please verify. You can resend from the next screen.';
        });
        // Do NOT sign out. AuthGate will route to VerifyEmailScreen.
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = switch (e.code) {
          'user-not-found' => 'No account found with that email.',
          'wrong-password' => 'Wrong password.',
          'invalid-email' => 'Invalid email format.',
          'too-many-requests' => 'Too many attempts. Try again later.',
          _ => e.message ?? 'Login failed.',
        };
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'Enter your email first, then tap "Forgot password".');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? 'Could not send reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: Text(_loading ? 'Signing in...' : 'Login'),
              ),
            ),
            TextButton(
              onPressed: _loading ? null : _forgotPassword,
              child: const Text('Forgot password?'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _loading
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
              child: const Text('Create new account'),
            ),
          ],
        ),
      ),
    );
  }
}
