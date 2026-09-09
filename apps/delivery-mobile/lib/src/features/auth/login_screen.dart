import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      final res = await ref.read(identityClientProvider).dio.post(
        '/api/v1/auth/login',
        data: {'email': _email.text.trim(), 'password': _password.text},
      );
      final data = res.data as Map<String, dynamic>;
      final roles = ((data['user'] as Map<String, dynamic>)['roles'] as List? ?? [])
          .map((e) => e.toString()).toList();
      if (!roles.any((r) => r.startsWith('DELIVERY_'))) {
        setState(() => _error = 'This account is not a delivery partner.');
        return;
      }
      await ref.read(tokenStorageProvider).save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: (data['user'] as Map<String, dynamic>)['userId'] as String,
      );
      ref.invalidate(authSessionProvider);
      if (!mounted) return;
      context.go('/');
    } catch (_) {
      setState(() => _error = 'Invalid credentials');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery partner sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(controller: _email, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Password')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: BhookColors.danger)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Sign in'),
          ),
        ]),
      ),
    );
  }
}
