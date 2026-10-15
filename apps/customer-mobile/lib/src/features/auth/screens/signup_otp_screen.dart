import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';
import '../auth_service.dart';
import '../auth_state.dart';
import 'auth_page_frame.dart';

class SignupOtpScreen extends ConsumerStatefulWidget {
  const SignupOtpScreen({super.key, required this.challenge});

  final EmailChallenge challenge;

  @override
  ConsumerState<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends ConsumerState<SignupOtpScreen> {
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _selectedCampusId;
  bool _busy = false;
  bool _hidePwd = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.challenge.matches.length == 1) {
      _selectedCampusId = widget.challenge.matches.first.campusId;
    }
  }

  @override
  void dispose() {
    _otp.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).completeSignup(
            challengeId: widget.challenge.challengeId,
            otp: _otp.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
            phoneE164: _phone.text.trim(),
            campusId: _selectedCampusId,
          );
      ref.invalidate(authSessionProvider);
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.challenge.matches;
    return AuthPageFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Verify your email',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: BhookColors.inkStrong)),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: BhookColors.inkMuted, fontSize: 15),
              children: [
                const TextSpan(text: 'We sent a code to '),
                TextSpan(
                    text: widget.challenge.email,
                    style: const TextStyle(
                        color: BhookColors.inkStrong,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(
                fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              labelText: 'Verification code',
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Your name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _hidePwd,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'At least 10 characters',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_hidePwd ? Icons.visibility_off : Icons.visibility,
                    color: BhookColors.inkMuted),
                onPressed: () => setState(() => _hidePwd = !_hidePwd),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              hintText: '+919876543210',
              helperText: 'Include +91 with no spaces',
              prefixIcon: Icon(Icons.phone_iphone),
            ),
          ),
          if (matches.length > 1) ...[
            const SizedBox(height: 20),
            const Text('Choose membership',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: -0.2)),
            const SizedBox(height: 8),
            ...matches.map((m) {
              final selected = _selectedCampusId == m.campusId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedCampusId = m.campusId),
                  borderRadius: BorderRadius.circular(BhookRadius.md),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          selected ? BhookColors.primarySoft : BhookColors.card,
                      borderRadius: BorderRadius.circular(BhookRadius.md),
                      border: Border.all(
                        color: selected
                            ? BhookColors.primary
                            : BhookColors.divider,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                          color: selected
                              ? BhookColors.primary
                              : BhookColors.inkFaint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${m.campusName} — ${m.membershipType}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                                m.autoVerify
                                    ? 'Verified instantly'
                                    : 'Requires manual review',
                                style: const TextStyle(
                                    color: BhookColors.inkMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            }),
          ] else if (matches.length == 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BhookColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(BhookRadius.md),
                border:
                    Border.all(color: BhookColors.info.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.school, size: 18, color: BhookColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${matches.first.campusName} · ${matches.first.membershipType}',
                    style: const TextStyle(
                        color: BhookColors.info, fontWeight: FontWeight.w700),
                  ),
                ),
              ]),
            ),
          ],
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
                  : const Text('Verify and finish'),
            ),
          ),
        ],
      ),
    );
  }
}
