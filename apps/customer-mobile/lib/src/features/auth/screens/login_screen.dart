import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../auth_service.dart';
import '../auth_state.dart';
import 'auth_page_frame.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  bool _hidePwd = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authServiceProvider)
          .login(_email.text.trim(), _password.text);
      ref.invalidate(authSessionProvider);
      if (!mounted) return;
      context.go(widget.returnTo ?? '/');
    } on UnsupportedError catch (error) {
      setState(() => _error = error.message?.toString() ??
          'This account cannot use the customer app.');
    } catch (_) {
      setState(() => _error = 'Incorrect email or password.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Welcome back',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: BhookColors.inkStrong)),
          const SizedBox(height: 6),
          const Text('Sign in to continue ordering from your campus vendors.',
              style: TextStyle(color: BhookColors.inkMuted, fontSize: 15)),
          const SizedBox(height: 28),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Campus email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _hidePwd,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_hidePwd ? Icons.visibility_off : Icons.visibility,
                    color: BhookColors.inkMuted),
                onPressed: () => setState(() => _hidePwd = !_hidePwd),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.error_outline,
                  color: BhookColors.danger, size: 16),
              const SizedBox(width: 6),
              Text(_error!, style: const TextStyle(color: BhookColors.danger)),
            ]),
          ],
          const SizedBox(height: 24),
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
                  : const Text('Sign in'),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : () => context.go('/forgot-password'),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('New to Bhook?  ',
                style: TextStyle(color: BhookColors.inkMuted)),
            TextButton(
              onPressed: () => context.go('/signup'),
              child: const Text('Create account'),
            ),
          ]),
        ],
      ),
    );
  }
}
