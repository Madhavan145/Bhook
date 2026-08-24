import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

final vendorProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final res =
      await ref.read(catalogClientProvider).dio.get('/api/v1/vendors/$id');
  return res.data as Map<String, dynamic>;
});

final vendorCatalogProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ref
      .read(catalogClientProvider)
      .dio
      .get('/api/v1/vendors/$id/catalog');
  return res.data as Map<String, dynamic>;
});

final cartLinesProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>, String>((ref, vendorId) async {
  try {
    final res = await ref
        .read(orderClientProvider)
        .dio
        .get('/api/v1/cart', queryParameters: {'vendorId': vendorId});
    return res.data as Map<String, dynamic>;
  } catch (_) {
    return const {'items': []};
  }
});

final cartCountProvider =
    FutureProvider.family.autoDispose<int, String>((ref, vendorId) async {
  final cart = await ref.watch(cartLinesProvider(vendorId).future);
  final items = (cart['items'] as List?) ?? const [];
  return items.fold<int>(0,
      (a, e) => a + ((e as Map<String, dynamic>)['quantity'] as num).toInt());
});

class VendorDetailScreen extends ConsumerStatefulWidget {
  const VendorDetailScreen(
      {super.key,
      required this.vendorId,
      this.initialCategory,
      this.initialItem});
  final String vendorId;
  final String? initialCategory;
  final String? initialItem;

  @override
  ConsumerState<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends ConsumerState<VendorDetailScreen> {
  String _diet = 'all';
  String? _category;
  final _scrollController = ScrollController();
  final _initialItemKey = GlobalKey();
  bool _revealedInitialItem = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vendor = ref.watch(vendorProvider(widget.vendorId));
    final catalog = ref.watch(vendorCatalogProvider(widget.vendorId));
    final cartCount =
        ref.watch(cartCountProvider(widget.vendorId)).asData?.value ?? 0;

    return Scaffold(
      body: catalog.when(
        loading: () => const _LoadingScaffold(),
        error: (e, _) => _ErrorScaffold(
            onRetry: () =>
                ref.invalidate(vendorCatalogProvider(widget.vendorId))),
        data: (data) {
          final menus = (data['menus'] as List?) ?? const [];
          String? itemCategory;
          if (widget.initialItem != null) {
            for (final menu in menus) {
              for (final category
                  in (menu['categories'] as List? ?? const [])) {
                final items = (category['items'] as List?) ?? const [];
                if (items.any((item) => item['itemId'] == widget.initialItem)) {
                  itemCategory = category['name']?.toString();
                }
              }
            }
          }
          final selectedCategory = _category ?? itemCategory;
          if (!_revealedInitialItem && widget.initialItem != null) {
            _revealedInitialItem = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final target = _initialItemKey.currentContext;
              if (target != null) {
                Scrollable.ensureVisible(target,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    alignment: 0.2);
              }
            });
          }
          final categories = [
            for (final menu in menus)
              for (final category in (menu['categories'] as List? ?? const []))
                if (((category as Map<String, dynamic>)['items'] as List?)
                        ?.isNotEmpty ??
                    false)
                  category['name']?.toString() ?? 'Category',
          ].toSet().toList();
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar.large(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: BhookColors.surface,
                surfaceTintColor: Colors.transparent,
                leading: BackButton(
                    color: BhookColors.inkStrong,
                    onPressed: () => context.pop()),
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(
                      start: 56, bottom: 14, end: 16),
                  title: vendor.when(
                    data: (v) => Text(
                      v['displayName']?.toString() ?? 'Vendor',
                      style: const TextStyle(
                          color: BhookColors.inkStrong,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: -0.3),
                    ),
                    loading: () => const Text(''),
                    error: (_, __) => const Text('Vendor',
                        style: TextStyle(color: BhookColors.inkStrong)),
                  ),
                  background: _VendorHero(vendor: vendor),
                ),
              ),
              SliverToBoxAdapter(
                child: _MenuWelcome(vendor: vendor),
              ),
              SliverToBoxAdapter(
                child: _MenuFilters(
                  diet: _diet,
                  category: selectedCategory,
                  categories: categories,
                  onDietChanged: (value) => setState(() => _diet = value),
                  onCategoryChanged: (value) =>
                      setState(() => _category = value),
                ),
              ),
              SliverToBoxAdapter(child: _VendorInfoStrip(vendor: vendor)),
              if (menus.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.restaurant_menu_outlined,
                    title: 'Menu coming soon',
                    message: 'This vendor hasn\'t published items yet.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 120),
                  sliver: SliverList.list(
                    children: [
                      for (final menu in menus)
                        for (final cat in (menu['categories'] as List? ?? []))
                          _CategoryBlock(
                            vendorId: widget.vendorId,
                            category: cat as Map<String, dynamic>,
                            diet: _diet,
                            selectedCategory: selectedCategory,
                            highlightedItemId: widget.initialItem,
                            highlightedItemKey: _initialItemKey,
                          ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: cartCount > 0
          ? _CartFab(vendorId: widget.vendorId, count: cartCount)
          : null,
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: ListSkeleton(),
      );
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ErrorRetry(
        message: 'We couldn\'t load this vendor\'s menu.',
        onRetry: onRetry,
      );
}

class _VendorHero extends StatelessWidget {
  const _VendorHero({required this.vendor});
  final AsyncValue<Map<String, dynamic>> vendor;

  @override
  Widget build(BuildContext context) {
    final v = vendor.asData?.value;
    final coverUrl = AppConfig.imageUrl(v?['coverObjectKey']?.toString());
    return Container(
      decoration: BoxDecoration(
        color: BhookColors.mint,
        image: coverUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(coverUrl),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                    BhookColors.inkStrong.withValues(alpha: 0.18),
                    BlendMode.darken),
              ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            bottom: 22,
            child: Transform.rotate(
              angle: -0.035,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                color: BhookColors.mustard,
                child: const Text('OPEN KITCHEN',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorInfoStrip extends StatelessWidget {
  const _VendorInfoStrip({required this.vendor});
  final AsyncValue<Map<String, dynamic>> vendor;

  @override
  Widget build(BuildContext context) {
    final v = vendor.asData?.value;
    final desc = v?['description']?.toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, 4, BhookSpacing.screenPad, BhookSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (desc != null && desc.isNotEmpty) ...[
            Text(desc, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MenuWelcome extends StatelessWidget {
  const _MenuWelcome({required this.vendor});
  final AsyncValue<Map<String, dynamic>> vendor;

  @override
  Widget build(BuildContext context) {
    final name = vendor.asData?.value['displayName']?.toString() ?? 'This spot';
    return Container(
      margin: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, BhookSpacing.md, BhookSpacing.screenPad, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: BhookColors.sky,
        borderRadius: BorderRadius.circular(BhookRadius.xl),
        border: Border.all(color: BhookColors.inkStrong, width: 1),
        boxShadow: const [
          BoxShadow(
            color: BhookColors.inkStrong,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Transform.rotate(
            angle: -0.08,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              color: BhookColors.mustard,
              child: const Text('TODAY\'S MENU',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: BhookSpacing.md),
          Expanded(
            child: Text('Pick a plate from $name',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    )),
          ),
        ],
      ),
    );
  }
}

class _MenuFilters extends StatelessWidget {
  const _MenuFilters({
    required this.diet,
    required this.category,
    required this.categories,
    required this.onDietChanged,
    required this.onCategoryChanged,
  });
  final String diet;
  final String? category;
  final List<String> categories;
  final ValueChanged<String> onDietChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, BhookSpacing.md, BhookSpacing.screenPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Build your plate',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: BhookSpacing.sm),
          _DietToggle(diet: diet, onChanged: onDietChanged),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: BhookSpacing.md),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, index) {
                  final label =
                      index == 0 ? 'All dishes' : categories[index - 1];
                  final selected =
                      index == 0 ? category == null : category == label;
                  return InkWell(
                    onTap: () => onCategoryChanged(index == 0 ? null : label),
                    borderRadius: BorderRadius.circular(BhookRadius.pill),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected ? BhookColors.action : BhookColors.card,
                        borderRadius: BorderRadius.circular(BhookRadius.pill),
                        border: Border.all(
                            color: selected
                                ? BhookColors.action
                                : BhookColors.divider),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.white : BhookColors.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DietToggle extends StatelessWidget {
  const _DietToggle({required this.diet, required this.onChanged});
  final String diet;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('all', 'All'),
    ('veg', 'Veg'),
    ('non-veg', 'Non-veg'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BhookColors.primarySoft,
        borderRadius: BorderRadius.circular(BhookRadius.md),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Row(
        children: [
          for (final option in _options)
            Expanded(
              child: _DietSegment(
                label: option.$2,
                selected: diet == option.$1,
                onTap: () => onChanged(option.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _DietSegment extends StatelessWidget {
  const _DietSegment(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BhookRadius.sm),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? BhookColors.action : BhookColors.card,
          borderRadius: BorderRadius.circular(BhookRadius.sm),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : BhookColors.inkMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _CategoryBlock extends ConsumerWidget {
  const _CategoryBlock(
      {required this.vendorId,
      required this.category,
      required this.diet,
      this.selectedCategory,
      this.highlightedItemId,
      this.highlightedItemKey});
  final String vendorId;
  final Map<String, dynamic> category;
  final String diet;
  final String? selectedCategory;
  final String? highlightedItemId;
  final GlobalKey? highlightedItemKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedCategory != null &&
        selectedCategory != category['name']?.toString()) {
      return const SizedBox.shrink();
    }
    final allItems = (category['items'] as List?) ?? const [];
    final items = allItems.where((raw) {
      if (diet == 'all') return true;
      final item = raw as Map<String, dynamic>;
      final tags = ((item['dietaryTags'] as List?) ?? const [])
          .map((tag) => tag.toString().toLowerCase())
          .toSet();
      final vegetarian = item['vegetarian'] as bool? ??
          tags.contains('veg') ||
              tags.contains('vegan') ||
              tags.contains('jain');
      return diet == 'veg' ? vegetarian : !vegetarian;
    }).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: BhookSpacing.screenPad, vertical: BhookSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
                top: BhookSpacing.md, bottom: BhookSpacing.sm),
            child: Row(
              children: [
                Text(category['name']?.toString() ?? 'Category',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(letterSpacing: -0.2)),
                const SizedBox(width: 6),
                Text('${items.length}',
                    style: const TextStyle(
                        color: BhookColors.inkFaint,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          for (var index = 0; index < items.length; index++)
            _ItemRow(
              key: items[index]['itemId'] == highlightedItemId
                  ? highlightedItemKey
                  : null,
              vendorId: vendorId,
              item: items[index] as Map<String, dynamic>,
              bestsellerRank: index < 3 ? index + 1 : null,
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends ConsumerStatefulWidget {
  const _ItemRow(
      {super.key,
      required this.vendorId,
      required this.item,
      this.bestsellerRank});
  final String vendorId;
  final Map<String, dynamic> item;
  final int? bestsellerRank;

  @override
  ConsumerState<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends ConsumerState<_ItemRow> {
  bool _busy = false;

  Future<void> _add() async {
    setState(() => _busy = true);
    try {
      await ref.read(orderClientProvider).dio.put('/api/v1/cart/items', data: {
        'vendorId': widget.vendorId,
        'itemId': widget.item['itemId'],
        'modifierIds': const [],
        'quantity': 1,
      });
      ref.invalidate(cartLinesProvider(widget.vendorId));
      ref.invalidate(cartCountProvider(widget.vendorId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractApiError(e) ?? 'Failed to add to cart')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setQty(String lineId, int quantity) async {
    setState(() => _busy = true);
    try {
      await ref.read(orderClientProvider).dio.patch(
        '/api/v1/cart/items/$lineId',
        data: {'vendorId': widget.vendorId, 'quantity': quantity},
      );
      ref.invalidate(cartLinesProvider(widget.vendorId));
      ref.invalidate(cartCountProvider(widget.vendorId));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractApiError(e) ?? 'Failed to update cart')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final available = item['available'] != false && item['status'] == 'ACTIVE';
    final name = item['name']?.toString() ?? '';
    final desc = item['description']?.toString();
    final tags = ((item['dietaryTags'] as List?) ?? const [])
        .map((t) => t.toString().toLowerCase())
        .toSet();
    final isVeg = (item['vegetarian'] as bool?) ??
        tags.contains('veg') || tags.contains('vegan') || tags.contains('jain');
    final imageKey = item['imageObjectKey']?.toString();
    final cart = ref.watch(cartLinesProvider(widget.vendorId)).asData?.value;
    final lines = (cart?['items'] as List?) ?? const [];
    Map<String, dynamic>? line;
    for (final raw in lines.whereType<Map<String, dynamic>>()) {
      if (raw['itemId'] == item['itemId']) {
        line = raw;
        break;
      }
    }
    final quantity = (line?['quantity'] as num?)?.toInt() ?? 0;
    final lineId = line?['lineId']?.toString();

    const paperColors = [
      BhookColors.mustard,
      BhookColors.sky,
      BhookColors.mint,
      Color(0xFFFFC7A8),
    ];
    final paperColor = paperColors[name.hashCode.abs() % paperColors.length];
    final regularPriceMinor = (item['priceMinor'] as num?)?.toInt() ?? 0;
    final offerPriceMinor = (item['offerPriceMinor'] as num?)?.toInt();
    final offerEndsAt =
        DateTime.tryParse(item['offerEndsAt']?.toString() ?? '');
    final offerActive = offerPriceMinor != null &&
        offerEndsAt != null &&
        offerEndsAt.isAfter(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: BhookSpacing.lg),
      padding: const EdgeInsets.all(BhookSpacing.md),
      decoration: BoxDecoration(
        color: paperColor,
        borderRadius: BorderRadius.circular(BhookRadius.xl),
        border: Border.all(color: BhookColors.inkStrong, width: 1),
        boxShadow: const [
          BoxShadow(
            color: BhookColors.inkStrong,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: DishImage(
                objectKey: imageKey, size: 68, radius: BhookRadius.pill),
          ),
          const SizedBox(width: BhookSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _VegDot(isVeg: isVeg),
                    const SizedBox(width: 6),
                    if (widget.bestsellerRank != null)
                      Text('BESTSELLER ${widget.bestsellerRank}',
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: BhookColors.inkStrong,
                          fontWeight: FontWeight.w900,
                        )),
                if (desc != null && desc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(desc,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BhookColors.inkStrong.withValues(alpha: 0.72)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                        Money.format(
                            offerActive ? offerPriceMinor : regularPriceMinor),
                        style: const TextStyle(
                            color: BhookColors.inkStrong,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                    if (offerActive) ...[
                      const SizedBox(width: 7),
                      Text(Money.format(regularPriceMinor),
                          style: const TextStyle(
                              color: BhookColors.inkMuted,
                              decoration: TextDecoration.lineThrough,
                              fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: BhookSpacing.sm),
          SizedBox(
            width: 82,
            height: 38,
            child: !available
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BhookColors.inkMuted,
                      backgroundColor: Colors.white.withValues(alpha: 0.45),
                      side: const BorderSide(color: BhookColors.inkStrong),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(BhookRadius.md)),
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 10),
                    ),
                    onPressed: null,
                    child: const Text('SOLD OUT'),
                  )
                : quantity > 0 && lineId != null
                    ? _ItemQtyStepper(
                        quantity: quantity,
                        busy: _busy,
                        onDecrement: () => _setQty(lineId, quantity - 1),
                        onIncrement: () => _setQty(lineId, quantity + 1),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: BhookColors.action,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(BhookRadius.md)),
                          textStyle: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 0.4),
                        ),
                        onPressed: _busy ? null : _add,
                        child: _busy
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('ADD'),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ItemQtyStepper extends StatelessWidget {
  const _ItemQtyStepper({
    required this.quantity,
    required this.busy,
    required this.onDecrement,
    required this.onIncrement,
  });
  final int quantity;
  final bool busy;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BhookColors.action,
        borderRadius: BorderRadius.circular(BhookRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StepBtn(
              icon: Icons.remove_rounded, onTap: busy ? null : onDecrement),
          Text('$quantity',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  fontSize: 14)),
          _StepBtn(icon: Icons.add_rounded, onTap: busy ? null : onIncrement),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class _VegDot extends StatelessWidget {
  const _VegDot({required this.isVeg});
  final bool isVeg;
  @override
  Widget build(BuildContext context) {
    final color = isVeg ? BhookColors.success : const Color(0xFFC0392B);
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class _CartFab extends StatelessWidget {
  const _CartFab({required this.vendorId, required this.count});
  final String vendorId;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, 0, BhookSpacing.screenPad, BhookSpacing.md),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: BhookColors.primary,
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          boxShadow: [
            BoxShadow(
              color: BhookColors.action.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: InkWell(
          onTap: () => context.push('/vendors/$vendorId/cart'),
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          child: Row(
            children: [
              Text('$count ${count == 1 ? 'item' : 'items'} added',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const Spacer(),
              const Text('View cart',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.3)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
