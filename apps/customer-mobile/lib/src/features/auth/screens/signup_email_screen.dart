import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../auth_service.dart';
import 'auth_page_frame.dart';

class SignupEmailScreen extends ConsumerStatefulWidget {
  const SignupEmailScreen({super.key});

  @override
  ConsumerState<SignupEmailScreen> createState() => _SignupEmailScreenState();
}

class _SignupEmailScreenState extends ConsumerState<SignupEmailScreen> {
  final _emailCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authServiceProvider)
          .startSignup(_emailCtrl.text.trim());
      if (!mounted) return;
      context.push('/signup/otp', extra: challenge);
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('EMAIL_DOMAIN_NOT_SUPPORTED') ||
        s.contains('not registered with any campus')) {
      return 'This email domain isn\'t linked to a campus yet.';
    }
    if (s.contains('Email already registered')) {
      return 'That email is already registered. Try signing in.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Join Bhook',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: BhookColors.inkStrong)),
          const SizedBox(height: 6),
          const Text(
              'We verify hostellers with a campus email so vendors know you\'re on-site.',
              style: TextStyle(color: BhookColors.inkMuted, fontSize: 15)),
          const SizedBox(height: 28),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Campus email',
              hintText: 'you@vitstudent.ac.in',
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          const SizedBox(height: 8),
          const Text('We\'ll send a 6-digit verification code.',
              style: TextStyle(color: BhookColors.inkFaint, fontSize: 12)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.error_outline,
                  color: BhookColors.danger, size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(_error!,
                      style: const TextStyle(color: BhookColors.danger))),
            ]),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send verification code'),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Already have an account?  ',
                    style: TextStyle(color: BhookColors.inkMuted)),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
              ]),
        ],
      ),
    );
  }
}
