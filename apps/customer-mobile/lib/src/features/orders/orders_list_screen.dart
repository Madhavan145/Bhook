import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';
import '../../core/ui/responsive.dart';

final ordersListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ref.read(orderClientProvider).dio.get('/api/v1/orders');
  return ((res.data as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
});

class OrdersListScreen extends ConsumerWidget {
  const OrdersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your orders'),
        centerTitle: false,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/')),
      ),
      body: orders.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorRetry(
          message: 'Could not load your orders.',
          onRetry: () => ref.invalidate(ordersListProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No orders yet',
                message: 'Your past orders will appear here.',
                action: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Browse vendors'),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(ordersListProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      BhookSpacing.screenPad,
                      BhookSpacing.md,
                      BhookSpacing.screenPad,
                      BhookSpacing.xxl),
                  children: [
                    const PlayfulBanner(
                      title: 'YOUR FOOD TRAIL',
                      subtitle: 'Every order has a story.',
                      icon: Icons.receipt_long_rounded,
                      color: BhookColors.sky,
                      margin: EdgeInsets.zero,
                    ),
                    const SizedBox(height: BhookSpacing.xl),
                    context.isCustomerWide
                        ? CustomerResponsiveGrid(
                            children: [
                              for (final order in list)
                                _OrderCard(order: order),
                            ],
                          )
                        : Column(
                            children: [
                              for (int i = 0; i < list.length; i++) ...[
                                if (i > 0)
                                  const SizedBox(height: BhookSpacing.md),
                                _OrderCard(order: list[i]),
                              ],
                            ],
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final status = order['status']?.toString() ?? '';
    final number = order['orderNumber']?.toString() ?? '';
    final total = (order['totalMinor'] as num).toInt();
    final currency = order['currency']?.toString() ?? 'INR';
    final vendor = order['vendorName']?.toString() ?? 'Vendor';
    final fulfillmentMode = order['fulfillmentMode']?.toString() ?? 'DELIVERY';
    return InkWell(
      onTap: () => context.push('/orders/${order['orderId']}'),
      borderRadius: BorderRadius.circular(BhookRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(BhookSpacing.md),
        decoration: BoxDecoration(
          color: BhookColors.card,
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          border: Border.all(color: BhookColors.inkStrong, width: 0.8),
          boxShadow: const [
            BoxShadow(
              color: BhookColors.divider,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(vendor,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                StatusPill(
                    label: _label(status), color: StatusPill.colorFor(status)),
              ],
            ),
            const SizedBox(height: 4),
            Text('# $number', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                    fulfillmentMode == 'SELF_PICKUP'
                        ? Icons.shopping_bag_outlined
                        : Icons.delivery_dining_outlined,
                    size: 16,
                    color: BhookColors.primary),
                const SizedBox(width: 6),
                Text(
                    fulfillmentMode == 'SELF_PICKUP'
                        ? 'Self takeaway'
                        : 'Delivery',
                    style: const TextStyle(
                        color: BhookColors.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: BhookSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(Money.format(total, currency: currency),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: BhookColors.inkStrong)),
                const Spacer(),
                const Text('View details',
                    style: TextStyle(
                        color: BhookColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right,
                    size: 18, color: BhookColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String status) {
    switch (status) {
      case 'PAYMENT_PENDING':
        return 'Awaiting payment';
      case 'PAID':
        return 'Paid';
      case 'VENDOR_ACCEPTED':
        return 'Accepted';
      case 'VENDOR_REJECTED':
        return 'Rejected';
      case 'PREPARING':
        return 'Preparing';
      case 'READY_FOR_PICKUP':
        return 'Ready';
      case 'DELIVERY_ASSIGNED':
        return 'Assigned';
      case 'PICKED_UP':
        return 'Picked up';
      case 'OUT_FOR_DELIVERY':
        return 'On the way';
      case 'COMPLETED':
        return 'Delivered';
      case 'CANCELLED':
        return 'Cancelled';
      case 'REFUNDED':
        return 'Refunded';
      default:
        return status;
    }
  }
}
