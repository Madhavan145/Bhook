import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

final partnerProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  try {
    final res = await ref.read(deliveryClientProvider).dio.get('/api/v1/delivery/partners/me');
    return res.data as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
});

class PartnerHomeScreen extends ConsumerWidget {
  const PartnerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(partnerProfileProvider);
    return Scaffold(
      body: SafeArea(
        child: profile.when(
          loading: () => const ListSkeleton(),
          error: (e, _) => ErrorRetry(
            message: 'Could not load your profile.',
            onRetry: () => ref.invalidate(partnerProfileProvider),
          ),
          data: (p) => p == null ? const _RegisterView() : _ProfileView(profile: p),
        ),
      ),
    );
  }
}

class _RegisterView extends ConsumerStatefulWidget {
  const _RegisterView();

  @override
  ConsumerState<_RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends ConsumerState<_RegisterView> {
  final _campusId = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _register() async {
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(deliveryClientProvider).dio.post(
        '/api/v1/delivery/partners/register',
        data: {'campusId': _campusId.text.trim()},
      );
      ref.invalidate(partnerProfileProvider);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: BhookSpacing.screenPad, vertical: BhookSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: BhookColors.primarySoft,
              borderRadius: BorderRadius.circular(BhookRadius.lg),
            ),
            child: const Center(
              child: Icon(Icons.delivery_dining_rounded, size: 34, color: BhookColors.primary),
            ),
          ),
          const SizedBox(height: BhookSpacing.xl),
          Text('Become a partner',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text(
            'Deliver on your campus and earn per drop. Enter your campus ID to submit an application.',
            style: TextStyle(color: BhookColors.inkMuted, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: BhookSpacing.xl),
          TextField(
            controller: _campusId,
            decoration: const InputDecoration(
              labelText: 'Assigned campus ID',
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: BhookSpacing.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BhookColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(BhookRadius.md),
                border: Border.all(color: BhookColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: BhookColors.danger, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: BhookColors.danger))),
              ]),
            ),
          ],
          const SizedBox(height: BhookSpacing.xl),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _busy ? null : _register,
              child: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit application'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileView extends ConsumerStatefulWidget {
  const _ProfileView({required this.profile});
  final Map<String, dynamic> profile;

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView> {
  bool _busy = false;

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final currently = widget.profile['availabilityStatus']?.toString() ?? 'OFFLINE';
      final next = currently == 'ONLINE' ? 'OFFLINE' : 'ONLINE';
      await ref.read(deliveryClientProvider).dio.put(
        '/api/v1/delivery/partners/me/availability',
        data: {'status': next},
      );
      ref.invalidate(partnerProfileProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(tokenStorageProvider).clear();
    ref.invalidate(authSessionProvider);
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final status = p['status']?.toString() ?? '';
    final availability = p['availabilityStatus']?.toString() ?? 'OFFLINE';
    final active = availability == 'ONLINE';
    final isActiveAccount = status == 'ACTIVE';
    final activeTasks = p['activeTaskCount'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, BhookSpacing.md, BhookSpacing.screenPad, BhookSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hey partner', style: TextStyle(color: BhookColors.inkMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(active ? 'You\'re online' : 'You\'re offline',
                        style: Theme.of(context).textTheme.headlineSmall),
                  ],
                ),
              ),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: BhookColors.card,
                  side: const BorderSide(color: BhookColors.divider),
                ),
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: _logout,
              ),
            ],
          ),
          const SizedBox(height: BhookSpacing.xl),

          // Big status card
          Container(
            padding: const EdgeInsets.all(BhookSpacing.lg),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: active
                    ? [BhookColors.success, BhookColors.success.withValues(alpha: 0.75)]
                    : [const Color(0xFF191A1F), const Color(0xFF2E2F35)],
              ),
              borderRadius: BorderRadius.circular(BhookRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: (active ? BhookColors.success : BhookColors.inkStrong).withValues(alpha: 0.2),
                  blurRadius: 24, offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(active ? 'LIVE' : 'OFFLINE',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 2)),
                ]),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$activeTasks',
                        style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1)),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('active jobs', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isActiveAccount)
                  SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: active ? BhookColors.success : BhookColors.inkStrong,
                      ),
                      onPressed: _busy ? null : _toggle,
                      icon: Icon(active ? Icons.pause_circle_outline : Icons.play_circle_outline),
                      label: Text(active ? 'Go offline' : 'Go online'),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: BhookSpacing.lg),

          if (!isActiveAccount)
            Container(
              padding: const EdgeInsets.all(BhookSpacing.md),
              decoration: BoxDecoration(
                color: BhookColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(BhookRadius.md),
                border: Border.all(color: BhookColors.info.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.hourglass_bottom, color: BhookColors.info),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Waiting for platform approval. Your account is $status. Jobs unlock when you\'re ACTIVE.',
                    style: const TextStyle(color: BhookColors.info, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ]),
            )
          else ...[
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => context.push('/jobs'),
                  icon: const Icon(Icons.list_alt, size: 18),
                  label: const Text('My jobs'),
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
