import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../auth_service.dart';
import 'auth_page_frame.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _requested = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _challengeId;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final challenge = await ref
          .read(authServiceProvider)
          .requestPasswordReset(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _challengeId = challenge.challengeId;
        _requested = true;
        _message =
            'We logged the OTP for now. It will be emailed when SMTP is connected.';
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            extractApiError(error) ?? 'Could not start password reset.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).confirmPasswordReset(
            challengeId: _challengeId!,
            otp: _otp.text.trim(),
            newPassword: _password.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. You can sign in now.')),
      );
      context.go('/login');
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = extractApiError(error) ?? 'Invalid OTP or password.');
      }
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
          const Text('Reset your password',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: BhookColors.inkStrong)),
          const SizedBox(height: 6),
          Text(
            _requested
                ? 'Enter the code sent to your campus email and choose a new password.'
                : 'We will verify your campus email before changing anything.',
            style: const TextStyle(color: BhookColors.inkMuted, fontSize: 15),
          ),
          const SizedBox(height: 26),
          TextField(
            controller: _email,
            enabled: !_requested,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Campus email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
          ),
          if (!_requested) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _requestOtp,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Send verification code'),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(
                  fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                  labelText: 'Email verification code', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hidePassword,
              decoration: InputDecoration(
                labelText: 'New password',
                helperText: 'At least 10 characters',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      _hidePassword ? Icons.visibility_off : Icons.visibility,
                      color: BhookColors.inkMuted),
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPassword,
              obscureText: _hidePassword,
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _busy ? null : _resetPassword,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Update password'),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _requested = false;
                          _challengeId = null;
                          _message = null;
                          _error = null;
                        }),
                child: const Text('Use a different email'),
              ),
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 14),
            Text(_message!,
                style: const TextStyle(
                    color: BhookColors.info, fontWeight: FontWeight.w600)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.error_outline,
                  color: BhookColors.danger, size: 16),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(_error!,
                      style: const TextStyle(color: BhookColors.danger))),
            ]),
          ],
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }
}
