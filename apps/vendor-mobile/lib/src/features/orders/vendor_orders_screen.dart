import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

final vendorOrdersProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, vendorId) async {
  final res = await ref
      .read(orderClientProvider)
      .dio
      .get('/api/v1/vendor/orders', queryParameters: {'vendorId': vendorId});
  final orders = ((res.data as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
  orders.sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
  return orders;
});

DateTime _createdAt(Map<String, dynamic> order) =>
    DateTime.tryParse(order['createdAt']?.toString() ?? '') ?? DateTime(1970);

class VendorHistoryQuery {
  const VendorHistoryQuery({required this.vendorId, required this.day});
  final String vendorId;
  final DateTime day;

  @override
  bool operator ==(Object other) =>
      other is VendorHistoryQuery &&
      other.vendorId == vendorId &&
      other.day == day;

  @override
  int get hashCode => Object.hash(vendorId, day);
}

final vendorOrderHistoryProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, VendorHistoryQuery>(
        (ref, query) async {
  final from = DateTime.utc(query.day.year, query.day.month, query.day.day);
  final to = from.add(const Duration(days: 1));
  final res = await ref
      .read(orderClientProvider)
      .dio
      .get('/api/v1/vendor/orders/history', queryParameters: {
    'vendorId': query.vendorId,
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
  });
  return ((res.data as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
});

/// Legacy standalone route wrapper.
class VendorOrdersScreen extends StatelessWidget {
  const VendorOrdersScreen({super.key, required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: SafeArea(child: VendorOrdersBody(vendorId: vendorId)),
    );
  }
}

class VendorOrdersBody extends ConsumerStatefulWidget {
  const VendorOrdersBody({super.key, required this.vendorId});
  final String vendorId;

  @override
  ConsumerState<VendorOrdersBody> createState() => _VendorOrdersBodyState();
}

class _VendorOrdersBodyState extends ConsumerState<VendorOrdersBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
              BhookSpacing.md, BhookSpacing.screenPad, 0),
          child: TabBar(
            controller: _tabs,
            labelColor: BhookColors.primary,
            unselectedLabelColor: BhookColors.inkMuted,
            indicatorColor: BhookColors.primary,
            dividerColor: BhookColors.divider,
            tabs: const [
              Tab(text: 'Live queue'),
              Tab(text: 'History'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _LiveQueue(vendorId: widget.vendorId),
              _OrderHistory(vendorId: widget.vendorId),
            ],
          ),
        ),
      ],
    );
  }
}

class _LiveQueue extends ConsumerStatefulWidget {
  const _LiveQueue({required this.vendorId});
  final String vendorId;

  @override
  ConsumerState<_LiveQueue> createState() => _LiveQueueState();
}

class _LiveQueueState extends ConsumerState<_LiveQueue> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) ref.invalidate(vendorOrdersProvider(widget.vendorId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(vendorOrdersProvider(widget.vendorId));
    return orders.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => ErrorRetry(
        message: 'Could not load orders.',
        onRetry: () => ref.invalidate(vendorOrdersProvider(widget.vendorId)),
      ),
      data: (list) => list.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'All caught up',
              message: 'New orders will land here in real time.',
            )
          : _OrderCollection(
              orders: list,
              onRefresh: () async =>
                  ref.invalidate(vendorOrdersProvider(widget.vendorId)),
              itemBuilder: (order) =>
                  _OrderCard(vendorId: widget.vendorId, order: order),
            ),
    );
  }
}

class _OrderHistory extends ConsumerStatefulWidget {
  const _OrderHistory({required this.vendorId});
  final String vendorId;

  @override
  ConsumerState<_OrderHistory> createState() => _OrderHistoryState();
}

class _OrderHistoryState extends ConsumerState<_OrderHistory> {
  late DateTime _day = _dateOnly(DateTime.now().toUtc());

  @override
  Widget build(BuildContext context) {
    final query = VendorHistoryQuery(vendorId: widget.vendorId, day: _day);
    final orders = ref.watch(vendorOrderHistoryProvider(query));
    return Column(
      children: [
        _HistoryDateBar(
          day: _day,
          onChanged: (day) => setState(() => _day = day),
        ),
        Expanded(
            child: orders.when(
          loading: () => const ListSkeleton(),
          error: (e, _) => ErrorRetry(
            message: 'Could not load order history.',
            onRetry: () => ref.invalidate(vendorOrderHistoryProvider(query)),
          ),
          data: (list) => list.isEmpty
              ? const EmptyState(
                  icon: Icons.history,
                  title: 'No past orders',
                  message: 'Completed and cancelled orders will appear here.',
                )
              : _OrderCollection(
                  orders: list,
                  onRefresh: () async =>
                      ref.invalidate(vendorOrderHistoryProvider(query)),
                  itemBuilder: (order) => _HistoryCard(order: order),
                ),
        )),
      ],
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}

class _HistoryDateBar extends StatelessWidget {
  const _HistoryDateBar({required this.day, required this.onChanged});
  final DateTime day;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = '${day.day.toString().padLeft(2, '0')}/'
        '${day.month.toString().padLeft(2, '0')}/${day.year}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, BhookSpacing.md, BhookSpacing.screenPad, 0),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 18),
          const SizedBox(width: BhookSpacing.sm),
          Expanded(
            child: Text('Orders for $label',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                onChanged(DateTime.utc(picked.year, picked.month, picked.day));
              }
            },
            icon: const Icon(Icons.edit_calendar_outlined, size: 17),
            label: const Text('Change day'),
          ),
        ],
      ),
    );
  }
}

class _OrderCollection extends StatelessWidget {
  const _OrderCollection({
    required this.orders,
    required this.onRefresh,
    required this.itemBuilder,
  });
  final List<Map<String, dynamic>> orders;
  final Future<void> Function() onRefresh;
  final Widget Function(Map<String, dynamic> order) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const wideBreakpoint = 900.0;
        final wide = constraints.maxWidth >= wideBreakpoint;
        const padding = EdgeInsets.fromLTRB(BhookSpacing.screenPad,
            BhookSpacing.md, BhookSpacing.screenPad, BhookSpacing.xxl);
        if (!wide) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              padding: padding,
              itemCount: orders.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: BhookSpacing.md),
              itemBuilder: (_, index) => itemBuilder(orders[index]),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: GridView.builder(
            padding: padding,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 520,
              crossAxisSpacing: BhookSpacing.lg,
              mainAxisSpacing: BhookSpacing.lg,
              mainAxisExtent: 270,
            ),
            itemCount: orders.length,
            itemBuilder: (_, index) => itemBuilder(orders[index]),
          ),
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? '';
    final currency = order['currency']?.toString() ?? 'INR';
    final total = (order['totalMinor'] as num?)?.toInt() ?? 0;
    final lines = (order['lines'] as List?) ?? const [];
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
              Expanded(
                child: Text('# ${order['orderNumber'] ?? ''}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              StatusPill(
                  label: _pretty(status), color: StatusPill.colorFor(status)),
            ],
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final l in lines.whereType<Map<String, dynamic>>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('${(l['quantity'] as num?)?.toInt() ?? 1}×',
                        style: const TextStyle(
                            color: BhookColors.inkMuted,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l['itemName']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: BhookColors.ink)),
                    ),
                    Text(
                        Money.format(
                            (l['lineTotalMinor'] as num?)?.toInt() ?? 0,
                            currency: currency),
                        style: const TextStyle(
                            color: BhookColors.inkMuted, fontSize: 13)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: BhookColors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(color: BhookColors.inkMuted)),
              const Spacer(),
              Text(Money.format(total, currency: currency),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: BhookColors.inkStrong,
                      fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  String _pretty(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.vendorId, required this.order});
  final String vendorId;
  final Map<String, dynamic> order;

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _busy = false;

  Future<void> _act(String action, {String reason = ''}) async {
    setState(() => _busy = true);
    try {
      await ref.read(orderClientProvider).dio.post(
        '/api/v1/vendor/orders/${widget.order['orderId']}/$action',
        queryParameters: {'vendorId': widget.vendorId},
        data: {'reason': reason},
      );
      ref.invalidate(vendorOrdersProvider(widget.vendorId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractApiError(e) ?? 'Action failed')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject this order?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason (shown to the customer)',
            hintText: 'e.g. Out of stock, kitchen closed early',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BhookColors.danger),
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Reject order'),
          ),
        ],
      ),
    );
    if (reason == null) return;
    await _act('reject', reason: reason.isEmpty ? 'VENDOR_REJECTED' : reason);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final status = o['status']?.toString() ?? '';
    final currency = o['currency']?.toString() ?? 'INR';
    final total = (o['totalMinor'] as num).toInt();
    final lines = (o['lines'] as List?) ?? const [];

    final actions = <_Action>[
      if (status == 'PAID') const _Action('accept', 'Accept', primary: true),
      if (status == 'PAID') const _Action('reject', 'Reject', danger: true),
      if (status == 'VENDOR_ACCEPTED')
        const _Action('prepare', 'Start prep', primary: true),
      if (status == 'PREPARING')
        const _Action('ready', 'Mark ready', primary: true),
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
              Expanded(
                child: Text('# ${o['orderNumber']}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              StatusPill(label: status, color: StatusPill.colorFor(status)),
            ],
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: BhookSpacing.sm),
            for (final l in lines.whereType<Map<String, dynamic>>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text('${(l['quantity'] as num?)?.toInt() ?? 1}×',
                        style: const TextStyle(
                            color: BhookColors.inkMuted,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l['itemName']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: BhookColors.ink)),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(Money.format(total, currency: currency),
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: BhookColors.inkStrong,
                  fontSize: 20,
                  letterSpacing: -0.3)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: BhookSpacing.md),
            const Divider(height: 1, color: BhookColors.divider),
            const SizedBox(height: BhookSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in actions) _actionButton(a),
              ],
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
    if (a.action == 'reject') {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: BhookColors.danger,
          side: BorderSide(color: BhookColors.danger.withValues(alpha: 0.4)),
        ),
        onPressed: _busy ? null : _confirmReject,
        child: Text(a.label),
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: a.danger ? BhookColors.danger : BhookColors.inkStrong,
        side: BorderSide(
            color: a.danger
                ? BhookColors.danger.withValues(alpha: 0.4)
                : BhookColors.divider),
      ),
      onPressed: _busy ? null : () => _act(a.action),
      child: Text(a.label),
    );
  }
}

class _Action {
  const _Action(this.action, this.label,
      {this.primary = false, this.danger = false});
  final String action;
  final String label;
  final bool primary;
  final bool danger;
}
