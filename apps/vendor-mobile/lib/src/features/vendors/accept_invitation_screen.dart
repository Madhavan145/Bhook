import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class AcceptInvitationScreen extends ConsumerStatefulWidget {
  const AcceptInvitationScreen({super.key});

  @override
  ConsumerState<AcceptInvitationScreen> createState() => _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState extends ConsumerState<AcceptInvitationScreen> {
  final _token = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(catalogClientProvider).dio.post(
            '/api/v1/vendors/invitations/${_token.text.trim()}/accept',
          );
      if (!mounted) return;
      setState(() => _message = 'Invitation accepted. Return to your kitchens.');
    } catch (_) {
      if (mounted) setState(() => _message = 'This invitation is invalid, expired, or already used.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accept vendor invitation')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Enter the private invitation token provided by Bhook operations.'),
            const SizedBox(height: 16),
            TextField(
              controller: _token,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Invitation token',
              ),
            ),
            const SizedBox(height: 16),
            if (_message != null) Text(_message!),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _accept,
              child: _busy ? const CircularProgressIndicator() : const Text('Accept invitation'),
            ),
          ],
        ),
      ),
    );
  }
}
