import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

final cartProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, vendorId) async {
  final cartResponse = await ref
      .read(orderClientProvider)
      .dio
      .get('/api/v1/cart', queryParameters: {'vendorId': vendorId});
  final cart = cartResponse.data as Map<String, dynamic>;
  Map<String, dynamic> catalog = const {};
  try {
    final response = await ref
        .read(catalogClientProvider)
        .dio
        .get('/api/v1/vendors/$vendorId/catalog');
    catalog = response.data as Map<String, dynamic>;
  } catch (_) {}
  final catalogItems = <String, Map<String, dynamic>>{};
  for (final menu in (catalog['menus'] as List? ?? const [])) {
    for (final category
        in ((menu as Map<String, dynamic>)['categories'] as List? ??
            const [])) {
      for (final item
          in ((category as Map<String, dynamic>)['items'] as List? ??
              const [])) {
        final data = item as Map<String, dynamic>;
        final itemId = data['itemId']?.toString();
        if (itemId != null) catalogItems[itemId] = data;
      }
    }
  }
  final items = ((cart['items'] as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map((line) {
    final catalogItem = catalogItems[line['itemId']?.toString()];
    return {
      ...line,
      'itemName': catalogItem?['name'] ?? line['itemName'],
      'imageObjectKey': catalogItem?['imageObjectKey'],
      'available': catalogItem?['available'] ?? true,
      'status': catalogItem?['status'] ?? 'ACTIVE',
    };
  }).toList();
  return {...cart, 'items': items};
});

final quoteProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, vendorId) async {
  try {
    final res = await ref
        .read(orderClientProvider)
        .dio
        .post('/api/v1/orders/quote', data: {'vendorId': vendorId});
    return res.data as Map<String, dynamic>;
  } on DioException catch (error) {
    if (error.response?.statusCode == 404 ||
        error.response?.statusCode == 422) {
      return {
        'unavailable': true,
        'message': extractApiError(error) ?? 'Item no longer available',
      };
    }
    rethrow;
  }
});

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key, required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider(vendorId));
    final quote = ref.watch(quoteProvider(vendorId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your cart'),
        centerTitle: false,
      ),
      body: cart.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorRetry(
          message: 'Cart is unavailable right now.',
          onRetry: () => ref.invalidate(cartProvider(vendorId)),
        ),
        data: (cartData) {
          final items = (cartData['items'] as List?) ?? const [];
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Your cart is empty',
              message: 'Browse the menu and add items to get started.',
              action: FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Back to menu'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
                BhookSpacing.md, BhookSpacing.screenPad, BhookSpacing.md),
            children: [
              const PlayfulBanner(
                title: 'GOOD CHOICES',
                subtitle: 'Your next comfort meal is right here.',
                icon: Icons.shopping_bag_rounded,
                color: BhookColors.sky,
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: BhookSpacing.xl),
              const SectionHeader(title: 'Items'),
              Container(
                decoration: BoxDecoration(
                  color: BhookColors.card,
                  borderRadius: BorderRadius.circular(BhookRadius.lg),
                  border: Border.all(color: BhookColors.divider),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: BhookColors.divider),
                      _CartLine(
                        vendorId: vendorId,
                        line: items[i] as Map<String, dynamic>,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: BhookSpacing.lg),
              const SectionHeader(title: 'Bill details'),
              _QuotePanel(quote: quote),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
      bottomNavigationBar: _CheckoutBar(quote: quote, vendorId: vendorId),
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({required this.vendorId, required this.line});
  final String vendorId;
  final Map<String, dynamic> line;

  Future<void> _setQty(WidgetRef ref, int qty) async {
    if (line['available'] == false || line['status'] != 'ACTIVE') return;
    await ref.read(orderClientProvider).dio.patch(
      '/api/v1/cart/items/${line['lineId']}',
      data: {'vendorId': vendorId, 'quantity': qty},
    );
    ref.invalidate(cartProvider(vendorId));
    ref.invalidate(quoteProvider(vendorId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qty = (line['quantity'] as num).toInt();
    final total = (line['lineTotalMinor'] as num).toInt();
    final name = line['itemName']?.toString() ??
        'Item ${line['itemId'].toString().substring(0, 8)}…';
    final available = line['available'] != false && line['status'] == 'ACTIVE';
    return Padding(
      padding: const EdgeInsets.all(BhookSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DishImage(
              objectKey: line['imageObjectKey']?.toString(),
              size: 64,
              radius: BhookRadius.md),
          const SizedBox(width: BhookSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleSmall),
                if (!available) ...[
                  const SizedBox(height: 4),
                  const Text('UNAVAILABLE',
                      style: TextStyle(
                          color: BhookColors.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ],
                const SizedBox(height: 8),
                _QtyStepper(
                  quantity: qty,
                  onDecrement: available ? () => _setQty(ref, qty - 1) : null,
                  onIncrement: available ? () => _setQty(ref, qty + 1) : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(Money.format(total),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: BhookColors.inkStrong)),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });
  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BhookColors.primarySoft,
        borderRadius: BorderRadius.circular(BhookRadius.md),
        border: Border.all(color: BhookColors.action.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(
            icon: quantity <= 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            onTap: onDecrement,
          ),
          SizedBox(
            width: 30,
            child: Text('$quantity',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: BhookColors.action,
                    fontSize: 15)),
          ),
          _StepBtn(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BhookRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon,
            size: 18,
            color: onTap == null ? BhookColors.inkFaint : BhookColors.action),
      ),
    );
  }
}

class _QuotePanel extends StatelessWidget {
  const _QuotePanel({required this.quote});
  final AsyncValue<Map<String, dynamic>> quote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BhookSpacing.md),
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.lg),
        border: Border.all(color: BhookColors.divider),
      ),
      child: quote.when(
        loading: () => const SizedBox(
            height: 100, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text(
            'Quote unavailable: ${extractApiError(e) ?? 'error'}',
            style: const TextStyle(color: BhookColors.danger)),
        data: (q) {
          if (q['unavailable'] == true) {
            return Text(
              q['message']?.toString() ?? 'Item no longer available',
              style: const TextStyle(color: BhookColors.danger),
            );
          }
          if (q.isEmpty) {
            return const Text('Add items to see your total.',
                style: TextStyle(color: BhookColors.inkMuted));
          }
          final currency = q['currency']?.toString() ?? 'INR';
          int m(num v) => v.toInt();
          Widget row(String l, int v, {bool bold = false}) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l,
                        style: TextStyle(
                          color: bold
                              ? BhookColors.inkStrong
                              : BhookColors.inkMuted,
                          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                          fontSize: bold ? 15 : 14,
                        )),
                    Text(Money.format(v, currency: currency),
                        style: TextStyle(
                          color: BhookColors.inkStrong,
                          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                          fontSize: bold ? 16 : 14,
                        )),
                  ],
                ),
              );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row('Item total', m(q['subtotalMinor'] as num)),
              row('Tax', m(q['taxMinor'] as num)),
              row('Platform fee', m(q['platformFeeMinor'] as num)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(color: BhookColors.divider, height: 1),
              ),
              row('To pay', m(q['totalMinor'] as num), bold: true),
            ],
          );
        },
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.quote, required this.vendorId});
  final AsyncValue<Map<String, dynamic>> quote;
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final q = quote.asData?.value;
    if (q == null || q['unavailable'] == true || q['totalMinor'] == null) {
      return const SizedBox.shrink();
    }
    final total = (q['totalMinor'] as num).toInt();
    final currency = q['currency']?.toString() ?? 'INR';
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, 0, BhookSpacing.screenPad, BhookSpacing.md),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: BhookSpacing.md),
        decoration: BoxDecoration(
          color: BhookColors.action,
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          boxShadow: [
            BoxShadow(
              color: BhookColors.action.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => context.push('/vendors/$vendorId/checkout'),
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(Money.format(total, currency: currency),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17)),
                  const Text('TOTAL',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              const Spacer(),
              const Text('Checkout',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
