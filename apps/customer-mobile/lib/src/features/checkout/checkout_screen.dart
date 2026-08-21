import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

final checkoutQuoteProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, vendorId) async {
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

class CampusLocation {
  const CampusLocation(
      {required this.id,
      required this.name,
      required this.locationType,
      this.instructions});

  final String id;
  final String name;
  final String locationType;
  final String? instructions;

  factory CampusLocation.fromJson(Map<String, dynamic> json) => CampusLocation(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? 'Unnamed block',
        locationType: json['locationType']?.toString() ?? 'OTHER',
        instructions: json['instructions']?.toString(),
      );
}

final checkoutLocationsProvider =
    FutureProvider.autoDispose<List<CampusLocation>>((ref) async {
  final profile =
      await ref.read(customerClientProvider).dio.get('/api/v1/customers/me');
  final campusId = (profile.data as Map?)?['activeCampusId']?.toString();
  if (campusId == null || campusId.isEmpty) return const [];
  final response = await ref
      .read(campusClientProvider)
      .dio
      .get('/api/v1/campuses/$campusId/locations');
  return ((response.data as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .where((item) => item['status']?.toString() != 'INACTIVE')
      .map(CampusLocation.fromJson)
      .toList();
});

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.vendorId});
  final String vendorId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _busy = false;
  bool _shareWithFriends = false;
  String? _error;
  CampusLocation? _selectedLocation;
  String _fulfillmentMode = 'DELIVERY';

  Future<void> _placeOrder() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final idem = const Uuid().v4();
      final res = await ref.read(orderClientProvider).dio.post(
        '/api/v1/orders',
        options: Options(headers: {'Idempotency-Key': idem}),
        data: {
          'vendorId': widget.vendorId,
          'fulfillmentMode': _fulfillmentMode,
          if (_fulfillmentMode == 'DELIVERY')
            'pickupLocationId': _selectedLocation?.id,
          'shareWithFriends': _shareWithFriends,
        },
      );
      final order = res.data as Map<String, dynamic>;
      if (_shareWithFriends) {
        await _publishShare(order['orderId'].toString());
      }
      if (!mounted) return;
      context.go('/orders/${order['orderId']}');
    } catch (e) {
      setState(() => _error = extractApiError(e) ?? 'Order failed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishShare(String orderId) async {
    try {
      final quote =
          await ref.read(checkoutQuoteProvider(widget.vendorId).future);
      final lines = (quote['lines'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          const [];
      if (lines.isEmpty) return;
      final line = lines.reduce((a, b) =>
          ((a['lineTotalMinor'] as num?)?.toInt() ?? 0) >=
                  ((b['lineTotalMinor'] as num?)?.toInt() ?? 0)
              ? a
              : b);
      final response = await ref
          .read(catalogClientProvider)
          .dio
          .get('/api/v1/vendors/${widget.vendorId}/catalog');
      final catalog = response.data as Map<String, dynamic>;
      Map<String, dynamic>? item;
      String? categoryName;
      for (final menu in (catalog['menus'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()) {
        for (final category in (menu['categories'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()) {
          for (final candidate in (category['items'] as List? ?? const [])
              .whereType<Map<String, dynamic>>()) {
            if (candidate['itemId']?.toString() == line['itemId']?.toString()) {
              item = candidate;
              categoryName = category['name']?.toString();
            }
          }
        }
      }
      await ref.read(socialClientProvider).dio.post(
        '/api/v1/social/orders/$orderId/shares/all',
        data: {
          'vendorId': widget.vendorId,
          'vendorName': catalog['vendorName'],
          'itemId': line['itemId'],
          'itemName': line['itemName'] ?? item?['name'],
          'itemImageObjectKey': item?['imageObjectKey'],
          'categoryName': categoryName,
        },
      );
    } catch (_) {
      // Sharing is best effort and must not make a successful order look failed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = ref.watch(checkoutQuoteProvider(widget.vendorId));
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout'), centerTitle: false),
      body: quote.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorRetry(
          message: extractApiError(error) ?? 'Could not load cart items.',
          onRetry: () => ref.invalidate(checkoutQuoteProvider(widget.vendorId)),
        ),
        data: (data) {
          final unavailable = data['unavailable'] == true;
          final locations = ref.watch(checkoutLocationsProvider);
          final lines = (data['lines'] as List?)
                  ?.whereType<Map<String, dynamic>>()
                  .toList() ??
              const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
                BhookSpacing.md, BhookSpacing.screenPad, BhookSpacing.md),
            children: [
              const PlayfulBanner(
                title: 'ALMOST THERE',
                subtitle: 'One last step before the feast.',
                icon: Icons.local_dining_rounded,
                color: BhookColors.mustard,
                margin: EdgeInsets.zero,
              ),
              const SizedBox(height: BhookSpacing.xl),
              const SectionHeader(
                title: 'Your order',
                subtitle: 'Choose how you want to collect it.',
              ),
              Container(
                decoration: BoxDecoration(
                  color: BhookColors.card,
                  borderRadius: BorderRadius.circular(BhookRadius.lg),
                  border: Border.all(color: BhookColors.divider),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < lines.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: BhookColors.divider),
                      _CheckoutLine(line: lines[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: BhookSpacing.lg),
              if (unavailable)
                _ErrorBanner(
                    message: data['message']?.toString() ??
                        'Item no longer available. Remove it from your cart and try again.'),
              if (unavailable) const SizedBox(height: BhookSpacing.md),
              _FulfillmentPicker(
                selected: _fulfillmentMode,
                onChanged: (mode) => setState(() {
                  _fulfillmentMode = mode;
                  if (mode == 'SELF_PICKUP') _selectedLocation = null;
                }),
              ),
              if (_fulfillmentMode == 'DELIVERY') ...[
                const SizedBox(height: BhookSpacing.md),
                locations.when(
                  loading: () => const _LocationLoading(),
                  error: (error, _) => _LocationError(
                      message: extractApiError(error) ??
                          'Could not load campus blocks.'),
                  data: (items) => _LocationPicker(
                    locations: items,
                    selected: _selectedLocation,
                    onSelected: (location) =>
                        setState(() => _selectedLocation = location),
                  ),
                ),
              ],
              const SizedBox(height: BhookSpacing.md),
              SwitchListTile.adaptive(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: BhookSpacing.sm),
                value: _shareWithFriends,
                onChanged: (value) => setState(() => _shareWithFriends = value),
                title: const Text('Share this order with friends'),
                subtitle: const Text(
                    'Your accepted friends can see your featured dish for 24 hours.'),
                secondary: const Icon(Icons.people_outline),
              ),
              const SizedBox(height: BhookSpacing.lg),
              if (_error != null) _ErrorBanner(message: _error!),
              const SizedBox(height: 96),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
            BhookSpacing.screenPad, 0, BhookSpacing.screenPad, BhookSpacing.md),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ||
                    (_fulfillmentMode == 'DELIVERY' &&
                        _selectedLocation == null) ||
                    quote.asData?.value['unavailable'] == true
                ? null
                : _placeOrder,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline, size: 20),
            label: Text(_busy ? 'Placing order…' : 'Place order'),
          ),
        ),
      ),
    );
  }
}

class _FulfillmentPicker extends StatelessWidget {
  const _FulfillmentPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BhookSpacing.sm),
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.lg),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fulfilment',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: BhookSpacing.sm),
          SegmentedButton<String>(
            expandedInsets: EdgeInsets.zero,
            segments: const [
              ButtonSegment<String>(
                value: 'DELIVERY',
                icon: Icon(Icons.delivery_dining_outlined),
                label: Text('Delivery'),
              ),
              ButtonSegment<String>(
                value: 'SELF_PICKUP',
                icon: Icon(Icons.shopping_bag_outlined),
                label: Text('Self takeaway'),
              ),
            ],
            selected: {selected},
            onSelectionChanged: (values) => onChanged(values.first),
          ),
          const SizedBox(height: 6),
          Text(
            selected == 'DELIVERY'
                ? 'We will bring it to your selected campus block.'
                : 'Order ahead and collect it from the vendor when you arrive.',
            style: const TextStyle(color: BhookColors.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _LocationPicker extends StatelessWidget {
  const _LocationPicker(
      {required this.locations,
      required this.selected,
      required this.onSelected});

  final List<CampusLocation> locations;
  final CampusLocation? selected;
  final ValueChanged<CampusLocation> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(BhookRadius.lg),
      onTap: locations.isEmpty ? null : () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.all(BhookSpacing.md),
        decoration: BoxDecoration(
          color: BhookColors.card,
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          border: Border.all(
            color: selected == null ? BhookColors.action : BhookColors.divider,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: BhookColors.action),
            const SizedBox(width: BhookSpacing.sm),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery block',
                        style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 3),
                    Text(
                        selected?.name ??
                            (locations.isEmpty
                                ? 'No blocks available'
                                : 'Select a block'),
                        style: Theme.of(context).textTheme.titleSmall),
                    if (selected?.instructions?.isNotEmpty == true)
                      Text(selected!.instructions!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                  ]),
            ),
            if (locations.isNotEmpty) const Icon(Icons.search, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final choice = await showModalBottomSheet<CampusLocation>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _LocationSearchSheet(locations: locations, selected: selected),
    );
    if (choice != null) onSelected(choice);
  }
}

class _LocationSearchSheet extends StatefulWidget {
  const _LocationSearchSheet({required this.locations, required this.selected});

  final List<CampusLocation> locations;
  final CampusLocation? selected;

  @override
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = widget.locations
        .where((location) =>
            location.name.toLowerCase().contains(query) ||
            location.locationType.toLowerCase().contains(query))
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: BhookSpacing.screenPad,
            right: BhookSpacing.screenPad,
            bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Choose delivery block',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: BhookSpacing.md),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search), hintText: 'Search blocks'),
            ),
            const SizedBox(height: BhookSpacing.sm),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matching blocks'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final location = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.apartment_outlined),
                          title: Text(location.name),
                          subtitle:
                              Text(location.locationType.replaceAll('_', ' ')),
                          trailing: widget.selected?.id == location.id
                              ? const Icon(Icons.check,
                                  color: BhookColors.action)
                              : null,
                          onTap: () => Navigator.of(context).pop(location),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _LocationLoading extends StatelessWidget {
  const _LocationLoading();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 78,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

class _LocationError extends StatelessWidget {
  const _LocationError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: const TextStyle(color: BhookColors.danger));
}

class _CheckoutLine extends StatelessWidget {
  const _CheckoutLine({required this.line});
  final Map<String, dynamic> line;

  @override
  Widget build(BuildContext context) {
    final name = line['itemName']?.toString() ?? 'Unnamed item';
    final quantity = (line['quantity'] as num?)?.toInt() ?? 0;
    final total = (line['lineTotalMinor'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.all(BhookSpacing.md),
      child: Row(
        children: [
          Expanded(
              child: Text('$quantity × $name',
                  style: Theme.of(context).textTheme.titleSmall)),
          const SizedBox(width: 12),
          Text(Money.format(total),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: BhookColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(BhookRadius.md),
          border: Border.all(color: BhookColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 18, color: BhookColors.danger),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(color: BhookColors.danger))),
        ]),
      );
}
