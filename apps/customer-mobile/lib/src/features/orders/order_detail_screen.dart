import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

final orderDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ref.read(orderClientProvider).dio.get('/api/v1/orders/$id');
  return res.data as Map<String, dynamic>;
});

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      ref.invalidate(orderDetailProvider(widget.orderId));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  bool _canCancel(String status) =>
      const {'PAYMENT_PENDING', 'PAID', 'VENDOR_ACCEPTED'}.contains(status);

  Future<void> _cancel() async {
    try {
      await ref.read(orderClientProvider).dio.post(
        '/api/v1/orders/${widget.orderId}/cancel',
        data: {'reason': 'Cancelled from app'},
      );
      ref.invalidate(orderDetailProvider(widget.orderId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractApiError(e) ?? 'Cannot cancel')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderDetailProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order details'),
        centerTitle: false,
        actions: [
          order.maybeWhen(
            data: (o) => _canCancel(o['status']?.toString() ?? '')
                ? TextButton(
                    onPressed: _cancel,
                    style: TextButton.styleFrom(
                        foregroundColor: BhookColors.danger),
                    child: const Text('Cancel'),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: order.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorRetry(
          message: 'We couldn\'t load this order.',
          onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
        ),
        data: (o) => _OrderBody(order: o, orderId: widget.orderId),
      ),
    );
  }
}

class _OrderBody extends StatelessWidget {
  const _OrderBody({required this.order, required this.orderId});
  final Map<String, dynamic> order;
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final currency = order['currency']?.toString() ?? 'INR';
    int m(dynamic v) => (v as num).toInt();
    final status = order['status']?.toString() ?? '';
    final fulfillmentMode = order['fulfillmentMode']?.toString() ?? 'DELIVERY';
    final lines =
        (order['lines'] as List? ?? const []).cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, BhookSpacing.md, BhookSpacing.screenPad, 100),
      children: [
        const PlayfulBanner(
          title: 'ORDER SNAPSHOT',
          subtitle: 'A little receipt for a big craving.',
          icon: Icons.receipt_long_rounded,
          color: BhookColors.sky,
          margin: EdgeInsets.zero,
        ),
        const SizedBox(height: BhookSpacing.xl),
        Container(
          padding: const EdgeInsets.all(BhookSpacing.md),
          decoration: BoxDecoration(
            color: BhookColors.card,
            borderRadius: BorderRadius.circular(BhookRadius.lg),
            border: Border.all(color: BhookColors.divider),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order # ${order['orderNumber']}',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text('Payment: ${order['paymentState']}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(
                        fulfillmentMode == 'SELF_PICKUP'
                            ? 'Fulfilment: Self takeaway'
                            : 'Fulfilment: Delivery',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              StatusPill(label: status, color: StatusPill.colorFor(status)),
            ],
          ),
        ),
        const SizedBox(height: BhookSpacing.lg),
        const SectionHeader(title: 'Items'),
        Container(
          decoration: BoxDecoration(
            color: BhookColors.card,
            borderRadius: BorderRadius.circular(BhookRadius.lg),
            border: Border.all(color: BhookColors.divider),
          ),
          child: Column(
            children: [
              for (int i = 0; i < lines.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: BhookColors.divider),
                Padding(
                  padding: const EdgeInsets.all(BhookSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: BhookColors.divider,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${lines[i]['quantity']}×',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(lines[i]['itemName']?.toString() ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                            if (lines[i]['variantName'] != null)
                              Text(lines[i]['variantName'].toString(),
                                  style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Text(
                          Money.format(m(lines[i]['lineTotalMinor']),
                              currency: currency),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BhookColors.inkStrong)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: BhookSpacing.lg),
        const SectionHeader(title: 'Bill'),
        Container(
          padding: const EdgeInsets.all(BhookSpacing.md),
          decoration: BoxDecoration(
            color: BhookColors.card,
            borderRadius: BorderRadius.circular(BhookRadius.lg),
            border: Border.all(color: BhookColors.divider),
          ),
          child: Column(
            children: [
              _row('Item total',
                  Money.format(m(order['subtotalMinor']), currency: currency)),
              _row('Tax',
                  Money.format(m(order['taxMinor']), currency: currency)),
              _row(
                  'Delivery',
                  Money.format(m(order['deliveryFeeMinor']),
                      currency: currency)),
              _row(
                  'Platform',
                  Money.format(m(order['platformFeeMinor']),
                      currency: currency)),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(color: BhookColors.divider, height: 1)),
              _row('Total paid',
                  Money.format(m(order['totalMinor']), currency: currency),
                  bold: true),
            ],
          ),
        ),
        const SizedBox(height: BhookSpacing.lg),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () => context.push('/orders/$orderId/track'),
            icon: const Icon(Icons.pin_drop_outlined, size: 20),
            label: const Text('Track your order'),
          ),
        ),
      ],
    );
  }

  Widget _row(String l, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l,
                style: TextStyle(
                  color: bold ? BhookColors.inkStrong : BhookColors.inkMuted,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                  fontSize: bold ? 15 : 14,
                )),
            Text(v,
                style: TextStyle(
                  color: BhookColors.inkStrong,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14,
                )),
          ],
        ),
      );
}
