import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

final jobsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(deliveryClientProvider).dio.get('/api/v1/delivery/jobs');
  return ((res.data as List?) ?? const []).whereType<Map<String, dynamic>>().toList();
});

class JobsListScreen extends ConsumerWidget {
  const JobsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(jobsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My jobs'), centerTitle: false),
      body: jobs.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorRetry(
          message: 'Could not load your jobs.',
          onRetry: () => ref.invalidate(jobsProvider),
        ),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.local_shipping_outlined,
                title: 'No active jobs',
                message: 'When you\'re online, new offers will land here.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(jobsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                      BhookSpacing.screenPad, BhookSpacing.md, BhookSpacing.screenPad, BhookSpacing.xxl),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: BhookSpacing.md),
                  itemBuilder: (context, i) => _JobCard(job: list[i]),
                ),
              ),
      ),
    );
  }
}

class _JobCard extends ConsumerStatefulWidget {
  const _JobCard({required this.job});
  final Map<String, dynamic> job;

  @override
  ConsumerState<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends ConsumerState<_JobCard> {
  bool _busy = false;

  Future<void> _act(String action) async {
    setState(() => _busy = true);
    try {
      await ref.read(deliveryClientProvider).dio.post('/api/v1/delivery/jobs/${widget.job['id']}/$action');
      ref.invalidate(jobsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    final status = j['status']?.toString() ?? '';
    final orderId = j['orderId']?.toString() ?? '';
    final actions = <_Action>[
      if (status == 'OFFERED') const _Action('accept', 'Accept', primary: true),
      if (status == 'OFFERED') const _Action('reject', 'Decline', danger: true),
      if (status == 'ACCEPTED') const _Action('pickup', 'Picked up', primary: true),
      if (status == 'PICKED_UP') const _Action('handoff', 'Handed off', primary: true),
    ];

    return Container(
      padding: const EdgeInsets.all(BhookSpacing.md),
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.lg),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: BhookColors.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(BhookRadius.md),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: BhookColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ${orderId.length >= 8 ? orderId.substring(0, 8) : orderId}…',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text('Job #${j['id'].toString().substring(0, 6)}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              StatusPill(label: status, color: StatusPill.colorFor(status)),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: BhookSpacing.md),
            const Divider(height: 1, color: BhookColors.divider),
            const SizedBox(height: BhookSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final a in actions) _actionButton(a)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(_Action a) {
    if (a.primary) {
      return FilledButton(
        onPressed: _busy ? null : () => _act(a.action),
        child: Text(a.label),
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: a.danger ? BhookColors.danger : BhookColors.inkStrong,
        side: BorderSide(color: a.danger ? BhookColors.danger.withValues(alpha: 0.4) : BhookColors.divider),
      ),
      onPressed: _busy ? null : () => _act(a.action),
      child: Text(a.label),
    );
  }
}

class _Action {
  const _Action(this.action, this.label, {this.primary = false, this.danger = false});
  final String action;
  final String label;
  final bool primary;
  final bool danger;
}
