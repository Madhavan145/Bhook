import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';

class BefriendScreen extends ConsumerStatefulWidget {
  const BefriendScreen({super.key, required this.friendCode});

  final String friendCode;

  @override
  ConsumerState<BefriendScreen> createState() => _BefriendScreenState();
}

class _BefriendScreenState extends ConsumerState<BefriendScreen> {
  bool _busy = false;
  String? _message;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final response = await ref.read(customerClientProvider).dio.get(
        '/api/v1/customers/directory/code/${widget.friendCode}',
      );
      if (mounted) setState(() => _profile = (response.data as Map).cast<String, dynamic>());
    } catch (error) {
      if (mounted) setState(() => _message = extractApiError(error) ?? 'This friend link is no longer available.');
    }
  }

  Future<void> _sendRequest() async {
    final friendCode = _profile?['friendCode'];
    if (friendCode == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(socialClientProvider).dio.post(
        '/api/v1/social/friends/request',
        data: {'friendCode': friendCode},
      );
      if (mounted) setState(() => _message = 'Friend request sent. They need to accept it.');
    } catch (error) {
      if (mounted) setState(() => _message = extractApiError(error) ?? 'Could not send friend request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile?['displayName']?.toString() ?? 'your friend';
    return Scaffold(
      appBar: AppBar(title: const Text('Add a friend')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(BhookSpacing.screenPad),
          child: _profile == null && _message == null
              ? const CircularProgressIndicator()
              : Card(
                  child: Padding(
                    padding: const EdgeInsets.all(BhookSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 38,
                          child: Icon(Icons.person_add_alt_1, size: 34),
                        ),
                        const SizedBox(height: BhookSpacing.md),
                        Text(
                          _profile == null ? 'Friend link unavailable' : 'Add $name as a friend?',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: BhookSpacing.sm),
                          Text(_message!, textAlign: TextAlign.center,
                              style: const TextStyle(color: BhookColors.inkMuted)),
                        ],
                        if (_profile != null && _message == null) ...[
                          const SizedBox(height: BhookSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _sendRequest,
                              icon: _busy ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.person_add_alt_1),
                              label: Text(_busy ? 'Sending...' : 'Send friend request'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
