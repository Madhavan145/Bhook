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
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(sessionMessageProvider.notifier).state = null;
    setState(() { _busy = true; _error = null; });
    try {
      final res = await ref.read(identityClientProvider).dio.post(
        '/api/v1/auth/login',
        data: {'email': _email.text.trim(), 'password': _password.text},
      );
      final data = res.data as Map<String, dynamic>;
      final roles = ((data['user'] as Map<String, dynamic>)['roles'] as List? ?? [])
          .map((e) => e.toString()).toList();
      if (!roles.any((r) => r.startsWith('VENDOR_'))) {
        setState(() => _error = 'This account is not a vendor.');
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
      setState(() => _error = 'Invalid email or password');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionMessage = ref.watch(sessionMessageProvider);
    return Scaffold(
      backgroundColor: BhookColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: BhookSpacing.xl, vertical: BhookSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: BhookColors.primary,
                        borderRadius: BorderRadius.circular(BhookRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: BhookColors.primary.withValues(alpha: 0.28),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: BhookSpacing.lg),
                  Text(
                    'Bhook for Vendors',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: BhookColors.inkStrong,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in to manage your kitchen, menu, and orders.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BhookColors.inkMuted, fontSize: 14),
                  ),
                  const SizedBox(height: BhookSpacing.xl),
                  if (sessionMessage != null) ...[
                    _Banner(
                      message: sessionMessage,
                      onDismiss: () => ref.read(sessionMessageProvider.notifier).state = null,
                    ),
                    const SizedBox(height: BhookSpacing.md),
                  ],
                  Container(
                    padding: const EdgeInsets.all(BhookSpacing.xl),
                    decoration: BoxDecoration(
                      color: BhookColors.card,
                      borderRadius: BorderRadius.circular(BhookRadius.xl),
                      border: Border.all(color: BhookColors.divider),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                          ),
                          const SizedBox(height: BhookSpacing.md),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _busy ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: BhookSpacing.md),
                            Row(
                              children: [
                                const Icon(Icons.error_outline, size: 16, color: BhookColors.danger),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(_error!, style: const TextStyle(color: BhookColors.danger, fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: BhookSpacing.xl),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: BhookSpacing.xl),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push('/apply'),
                      icon: const Icon(Icons.add_business_outlined, size: 18),
                      label: const Text('New vendor? Apply to join Bhook'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: BhookColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(BhookRadius.md),
        border: Border.all(color: BhookColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: BhookColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: BhookColors.info, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          InkWell(
            onTap: onDismiss,
            borderRadius: BorderRadius.circular(BhookRadius.pill),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 16, color: BhookColors.info),
            ),
          ),
        ],
      ),
    );
  }
}
