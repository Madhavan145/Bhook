import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/widgets.dart';
import '../../core/app_config.dart';
import 'upload_service.dart';

final vendorCatalogProvider = FutureProvider.family
    .autoDispose<Map<String, dynamic>, String>((ref, vendorId) async {
  final res = await ref
      .read(catalogClientProvider)
      .dio
      .get('/api/v1/vendors/$vendorId/menu');
  return res.data as Map<String, dynamic>;
});

/// Legacy standalone route wrapper. The primary entry point is [VendorMenuBody]
/// hosted inside the vendor workspace shell.
class VendorMenuScreen extends StatelessWidget {
  const VendorMenuScreen({super.key, required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: SafeArea(child: VendorMenuBody(vendorId: vendorId)),
    );
  }
}

class VendorMenuBody extends ConsumerWidget {
  const VendorMenuBody({super.key, required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(vendorCatalogProvider(vendorId));
    return catalog.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => ErrorRetry(
        message: 'Could not load your menu.',
        onRetry: () => ref.invalidate(vendorCatalogProvider(vendorId)),
      ),
      data: (data) {
        final menus = (data['menus'] as List?) ?? const [];
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(vendorCatalogProvider(vendorId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
                BhookSpacing.md, BhookSpacing.screenPad, BhookSpacing.xxl),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Menu',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(
                            '${menus.length} menu${menus.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _newMenu(context, ref),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('New menu'),
                  ),
                ],
              ),
              const SizedBox(height: BhookSpacing.lg),
              if (menus.isEmpty)
                const EmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'Build your menu',
                  message:
                      'Create a menu (e.g. Lunch), add categories like Rolls or Beverages, then add dishes with photos and prices.',
                )
              else
                Column(
                  children: [
                    for (final menu in menus)
                      _MenuSection(
                        vendorId: vendorId,
                        menu: menu as Map<String, dynamic>,
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _newMenu(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptText(context,
        title: 'New menu', hint: 'Menu name (e.g. Lunch)');
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(catalogClientProvider).dio.post(
        '/api/v1/vendors/$vendorId/menu',
        data: {'name': name},
      );
      ref.invalidate(vendorCatalogProvider(vendorId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Could not create menu: ${friendlyError(e)}')));
    }
  }
}

class _MenuSection extends ConsumerWidget {
  const _MenuSection({required this.vendorId, required this.menu});
  final String vendorId;
  final Map<String, dynamic> menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = (menu['categories'] as List?) ?? const [];
    return Container(
      margin: const EdgeInsets.only(bottom: BhookSpacing.lg),
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
              const Icon(Icons.menu_book_outlined,
                  size: 18, color: BhookColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(menu['name']?.toString() ?? '',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Edit menu',
                icon: const Icon(Icons.edit_outlined, size: 19),
                onPressed: () =>
                    _editMenu(context, ref, menu['menuId'] as String),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Category'),
                onPressed: () =>
                    _newCategory(context, ref, menu['menuId'] as String),
              ),
            ],
          ),
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No categories yet. Add one to start listing dishes.',
                  style: TextStyle(color: BhookColors.inkMuted)),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final categoryWidgets = [
                  for (final cat in categories)
                    _CategorySection(
                      vendorId: vendorId,
                      menuId: menu['menuId'] as String,
                      category: cat as Map<String, dynamic>,
                    ),
                ];
                if (constraints.maxWidth < Breakpoints.tablet) {
                  return Column(children: categoryWidgets);
                }
                return ResponsiveGrid(
                  minTileWidth: 360,
                  spacing: BhookSpacing.lg,
                  runSpacing: BhookSpacing.lg,
                  children: categoryWidgets,
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _editMenu(
      BuildContext context, WidgetRef ref, String menuId) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptText(context,
        title: 'Edit menu',
        hint: 'Menu name',
        initialValue: menu['name']?.toString() ?? '',
        confirmLabel: 'Save');
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(catalogClientProvider).dio.patch(
        '/api/v1/vendors/$vendorId/menu/$menuId',
        data: {'name': name},
      );
      ref.invalidate(vendorCatalogProvider(vendorId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Could not update menu: ${friendlyError(e)}')));
    }
  }

  Future<void> _newCategory(
      BuildContext context, WidgetRef ref, String menuId) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptText(context,
        title: 'New category', hint: 'Category name (e.g. Rolls)');
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(catalogClientProvider).dio.post(
        '/api/v1/vendors/$vendorId/menu/$menuId/categories',
        data: {'name': name, 'displayOrder': 0},
      );
      ref.invalidate(vendorCatalogProvider(vendorId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Could not create category: ${friendlyError(e)}')));
    }
  }
}

class _CategorySection extends ConsumerWidget {
  const _CategorySection(
      {required this.vendorId, required this.menuId, required this.category});
  final String vendorId;
  final String menuId;
  final Map<String, dynamic> category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = (category['items'] as List?) ?? const [];
    return Padding(
      padding: const EdgeInsets.only(top: BhookSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(category['name']?.toString() ?? '',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: BhookColors.inkStrong)),
              ),
              IconButton(
                tooltip: 'Edit category',
                icon: const Icon(Icons.edit_outlined, size: 17),
                onPressed: () => _editCategory(context, ref, category),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Dish'),
                onPressed: () => _editItem(context, ref,
                    categoryId: category['categoryId'] as String),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('No dishes in this category yet.',
                  style: TextStyle(color: BhookColors.inkFaint, fontSize: 13)),
            )
          else
            for (final item in items)
              _ItemTile(
                vendorId: vendorId,
                item: item as Map<String, dynamic>,
                onEdit: () => _editItem(context, ref,
                    categoryId: category['categoryId'] as String, item: item),
              ),
        ],
      ),
    );
  }

  Future<void> _editCategory(BuildContext context, WidgetRef ref,
      Map<String, dynamic> category) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await _promptText(context,
        title: 'Edit category',
        hint: 'Category name',
        initialValue: category['name']?.toString() ?? '',
        confirmLabel: 'Save');
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(catalogClientProvider).dio.patch(
        '/api/v1/vendors/$vendorId/menu/$menuId/categories/${category['categoryId']}',
        data: {'name': name},
      );
      ref.invalidate(vendorCatalogProvider(vendorId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Could not update category: ${friendlyError(e)}')));
    }
  }

  Future<void> _editItem(BuildContext context, WidgetRef ref,
      {required String categoryId, Map<String, dynamic>? item}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BhookColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BhookRadius.xl)),
      ),
      builder: (_) =>
          _ItemSheet(vendorId: vendorId, categoryId: categoryId, item: item),
    );
    if (changed == true) ref.invalidate(vendorCatalogProvider(vendorId));
  }
}

class _ItemTile extends ConsumerStatefulWidget {
  const _ItemTile(
      {required this.vendorId, required this.item, required this.onEdit});
  final String vendorId;
  final Map<String, dynamic> item;
  final VoidCallback onEdit;

  @override
  ConsumerState<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends ConsumerState<_ItemTile> {
  bool _busy = false;

  Future<void> _toggleAvailability() async {
    final available = (widget.item['available'] as bool?) ?? true;
    await _run(() => ref.read(catalogClientProvider).dio.put(
          '/api/v1/vendors/${widget.vendorId}/menu/items/${widget.item['itemId']}/availability',
          data: {'available': !available},
        ));
  }

  Future<void> _archive() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove dish?'),
        content: Text(
            '“${widget.item['name']}” will be removed from your menu. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BhookColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => ref.read(catalogClientProvider).dio.delete(
        '/api/v1/vendors/${widget.vendorId}/menu/items/${widget.item['itemId']}'));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(vendorCatalogProvider(widget.vendorId));
    } catch (e) {
      if (mounted) _snack(context, 'Failed: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final name = item['name']?.toString() ?? '';
    final desc = item['description']?.toString() ?? '';
    final price = (item['priceMinor'] as num?)?.toInt() ?? 0;
    final available = (item['available'] as bool?) ?? true;
    final status = item['status']?.toString() ?? 'ACTIVE';
    final hasImage = (item['imageObjectKey']?.toString().isNotEmpty ?? false);
    final tags = ((item['dietaryTags'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final variants = (item['variants'] as List?) ?? const [];
    final modifiers = (item['modifiers'] as List?) ?? const [];

    return Opacity(
      opacity: _busy ? 0.5 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(BhookSpacing.sm),
        decoration: BoxDecoration(
          color: BhookColors.surface,
          borderRadius: BorderRadius.circular(BhookRadius.md),
          border: Border.all(color: BhookColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: BhookColors.primarySoft,
                    borderRadius: BorderRadius.circular(BhookRadius.sm),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasImage
                      ? Image.network(
                          AppConfig.imageUrl(
                              item['imageObjectKey']?.toString())!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.restaurant,
                              size: 20,
                              color: BhookColors.primary),
                        )
                      : const Icon(Icons.restaurant,
                          size: 20, color: BhookColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: BhookColors.inkStrong),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(desc,
                            style: const TextStyle(
                                color: BhookColors.inkMuted, fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 4),
                      Text(Money.format(price),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: BhookColors.inkStrong)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !_busy,
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        widget.onEdit();
                        break;
                      case 'availability':
                        _toggleAvailability();
                        break;
                      case 'extras':
                        _openExtras();
                        break;
                      case 'archive':
                        _archive();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit dish')),
                    PopupMenuItem(
                        value: 'availability',
                        child: Text(
                            available ? 'Mark unavailable' : 'Mark available')),
                    const PopupMenuItem(
                        value: 'extras', child: Text('Variants & add-ons')),
                    const PopupMenuItem(
                        value: 'archive', child: Text('Remove dish')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusPill(
                  label: available ? 'Available' : 'Unavailable',
                  color: available ? BhookColors.success : BhookColors.danger,
                ),
                if (status != 'ACTIVE')
                  StatusPill(
                      label: _pretty(status), color: BhookColors.inkMuted),
                for (final t in tags) _MiniTag(label: t),
                if (variants.isNotEmpty)
                  _MiniTag(
                      label:
                          '${variants.length} variant${variants.length == 1 ? '' : 's'}',
                      icon: Icons.tune),
                if (modifiers.isNotEmpty)
                  _MiniTag(
                      label:
                          '${modifiers.length} add-on${modifiers.length == 1 ? '' : 's'}',
                      icon: Icons.add_circle_outline),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openExtras() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BhookColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(BhookRadius.xl)),
      ),
      builder: (_) =>
          _ExtrasSheet(vendorId: widget.vendorId, item: widget.item),
    );
    if (changed == true) ref.invalidate(vendorCatalogProvider(widget.vendorId));
  }

  String _pretty(String s) => s
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, this.icon});
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.pill),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: BhookColors.inkMuted),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: BhookColors.inkMuted,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Create / edit dish sheet covering all fields the backend accepts.
class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet(
      {required this.vendorId, required this.categoryId, this.item});
  final String vendorId;
  final String categoryId;
  final Map<String, dynamic>? item;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  static const _tagOptions = <String>[
    // Diet
    'veg', 'non-veg', 'egg', 'vegan', 'jain',
    // Course
    'breakfast', 'starter', 'main-course', 'meal', 'thali', 'combo', 'side',
    'dessert',
    // Dish type
    'roll', 'wrap', 'bread', 'rice', 'biryani', 'noodles', 'gravy', 'curry',
    'dry', 'soup', 'salad',
    // Snacks & sweets
    'snack', 'fast-food', 'sweet', 'bakery',
    // Drinks
    'drink', 'beverage', 'shake', 'juice', 'tea', 'coffee',
    // Cuisine
    'south-indian', 'north-indian', 'chinese', 'continental', 'tandoori',
    // Attributes
    'spicy', 'healthy', 'popular',
  ];
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _price = TextEditingController();
  final _offerPrice = TextEditingController();
  final _tax = TextEditingController();
  final _prep = TextEditingController();
  final Set<String> _selectedTags = {};
  bool _active = true;
  bool _offerEnabled = false;
  DateTime? _offerEndsAt;
  Uint8List? _pickedBytes;
  XFile? _pickedFile;
  String? _existingImageKey;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _name.text = item['name']?.toString() ?? '';
      _desc.text = item['description']?.toString() ?? '';
      final priceMinor = (item['priceMinor'] as num?)?.toInt() ?? 0;
      _price.text = (priceMinor / 100).toStringAsFixed(2);
      final offerPriceMinor = (item['offerPriceMinor'] as num?)?.toInt();
      _offerPrice.text = offerPriceMinor == null
          ? ''
          : (offerPriceMinor / 100).toStringAsFixed(2);
      final offerEndsAt = item['offerEndsAt']?.toString();
      _offerEndsAt =
          offerEndsAt == null ? null : DateTime.tryParse(offerEndsAt);
      _offerEnabled = offerPriceMinor != null && _offerEndsAt != null;
      final taxMinor = (item['taxMinor'] as num?)?.toInt() ?? 0;
      if (taxMinor > 0) _tax.text = (taxMinor / 100).toStringAsFixed(2);
      final prep = (item['prepTimeMinutes'] as num?)?.toInt();
      if (prep != null && prep > 0) _prep.text = '$prep';
      _selectedTags.addAll(((item['dietaryTags'] as List?) ?? const [])
          .map((e) => e.toString().toLowerCase())
          .where(_tagOptions.contains));
      _active = (item['status']?.toString() ?? 'ACTIVE') == 'ACTIVE';
      _existingImageKey = item['imageObjectKey']?.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _offerPrice.dispose();
    _tax.dispose();
    _prep.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _pickedFile = picked;
      _pickedBytes = bytes;
    });
  }

  int? _toMinor(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null) return null;
    return (v * 100).round();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    final priceMinor = _toMinor(_price.text);
    if (!_isEdit && (priceMinor == null || priceMinor < 0)) {
      setState(() => _error = 'Enter a valid price.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? imageKey = _existingImageKey;
      if (_pickedFile != null) {
        final res = await ref
            .read(uploadServiceProvider)
            .uploadPickedImage(_pickedFile!);
        imageKey = res.objectKey;
      }
      final tags = _selectedTags.toList();
      final dio = ref.read(catalogClientProvider).dio;
      final taxMinor = _toMinor(_tax.text);
      final prep = int.tryParse(_prep.text.trim());
      final offerPriceMinor = _offerEnabled ? _toMinor(_offerPrice.text) : null;
      if (_offerEnabled && (offerPriceMinor == null || _offerEndsAt == null)) {
        setState(() => _error = 'Enter an offer price and end time.');
        return;
      }

      if (_isEdit) {
        await dio.patch(
          '/api/v1/vendors/${widget.vendorId}/menu/items/${widget.item!['itemId']}',
          data: {
            'name': name,
            'description': _desc.text.trim(),
            if (priceMinor != null) 'priceMinor': priceMinor,
            'offerEnabled': _offerEnabled,
            if (_offerEnabled) ...{
              'offerPriceMinor': offerPriceMinor,
              'offerEndsAt': _offerEndsAt!.toUtc().toIso8601String(),
            },
            if (taxMinor != null) 'taxMinor': taxMinor,
            if (prep != null) 'prepTimeMinutes': prep,
            if (imageKey != null && imageKey.isNotEmpty)
              'imageObjectKey': imageKey,
            'dietaryTags': tags,
            'status': _active ? 'ACTIVE' : 'INACTIVE',
          },
        );
      } else {
        await dio.post(
          '/api/v1/vendors/${widget.vendorId}/menu/items',
          data: {
            'categoryId': widget.categoryId,
            'name': name,
            'description': _desc.text.trim(),
            'priceMinor': priceMinor,
            'offerEnabled': _offerEnabled,
            if (_offerEnabled) ...{
              'offerPriceMinor': offerPriceMinor,
              'offerEndsAt': _offerEndsAt!.toUtc().toIso8601String(),
            },
            'taxMinor': taxMinor ?? 0,
            if (prep != null) 'prepTimeMinutes': prep,
            if (imageKey != null && imageKey.isNotEmpty)
              'imageObjectKey': imageKey,
            'dietaryTags': tags,
          },
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: BhookSpacing.lg,
        right: BhookSpacing.lg,
        top: BhookSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + BhookSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: ContentBound(
          maxWidth: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: BhookColors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(_isEdit ? 'Edit dish' : 'New dish',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _ImagePickerBox(
                bytes: _pickedBytes,
                hasExisting: _existingImageKey?.isNotEmpty ?? false,
                onPick: _pickImage,
                onClear: (_pickedBytes != null ||
                        (_existingImageKey?.isNotEmpty ?? false))
                    ? () => setState(() {
                          _pickedBytes = null;
                          _pickedFile = null;
                          _existingImageKey = null;
                        })
                    : null,
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Dish name *')),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _offerEnabled,
                onChanged: (value) => setState(() => _offerEnabled = value),
                title: const Text('Enable offer'),
                subtitle:
                    const Text('Show this dish in campus offers while active.'),
                secondary: const Icon(Icons.local_offer_outlined),
              ),
              if (_offerEnabled) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _offerPrice,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Offer price *', prefixText: '₹ '),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickOfferEnd,
                        borderRadius: BorderRadius.circular(BhookRadius.md),
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Ends *'),
                          child: Text(_offerEndsAt == null
                              ? 'Choose date/time'
                              : _formatOfferEnd(_offerEndsAt!)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Price (₹) *', prefixText: '₹ '),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tax,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Tax (₹)', prefixText: '₹ '),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prep,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Prep time (minutes)', suffixText: 'min'),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Dish groups'),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _tagOptions
                      .map((tag) => FilterChip(
                            label: Text(tag),
                            selected: _selectedTags.contains(tag),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            }),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
                title: const Text('Listed on menu'),
                subtitle: Text(
                    _active
                        ? 'Customers can see this dish'
                        : 'Hidden from customers',
                    style: const TextStyle(
                        color: BhookColors.inkMuted, fontSize: 12)),
                activeThumbColor: BhookColors.primary,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(color: BhookColors.danger)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(_isEdit ? 'Save changes' : 'Add dish'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickOfferEnd() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      initialDate: _offerEndsAt ?? now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _offerEndsAt == null
          ? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)))
          : TimeOfDay.fromDateTime(_offerEndsAt!),
    );
    if (time == null) return;
    setState(() => _offerEndsAt =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  String _formatOfferEnd(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _ImagePickerBox extends StatelessWidget {
  const _ImagePickerBox(
      {required this.bytes,
      required this.hasExisting,
      required this.onPick,
      this.onClear});
  final Uint8List? bytes;
  final bool hasExisting;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: BhookColors.card,
          borderRadius: BorderRadius.circular(BhookRadius.md),
          border: Border.all(color: BhookColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: bytes != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes!, fit: BoxFit.cover),
                  if (onClear != null)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _clearButton(),
                    ),
                ],
              )
            : hasExisting
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: BhookColors.primarySoft,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle,
                                  color: BhookColors.success),
                              SizedBox(height: 6),
                              Text('Photo attached · tap to replace',
                                  style: TextStyle(
                                      color: BhookColors.inkMuted,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      if (onClear != null)
                        Positioned(top: 6, right: 6, child: _clearButton()),
                    ],
                  )
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('NO IMAGE',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: BhookColors.inkMuted,
                                letterSpacing: 1.2)),
                        SizedBox(height: 6),
                        Text('Tap to add an optional photo',
                            style: TextStyle(
                                color: BhookColors.inkMuted, fontSize: 12)),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _clearButton() {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onClear,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

/// Variants (size/portion options) and modifiers (add-ons) management.
class _ExtrasSheet extends ConsumerStatefulWidget {
  const _ExtrasSheet({required this.vendorId, required this.item});
  final String vendorId;
  final Map<String, dynamic> item;

  @override
  ConsumerState<_ExtrasSheet> createState() => _ExtrasSheetState();
}

class _ExtrasSheetState extends ConsumerState<_ExtrasSheet> {
  Future<void> _addVariant() async {
    final result = await _promptNamePrice(context,
        title: 'New variant', nameHint: 'e.g. Large');
    if (result == null) return;
    await _post('variants', result);
  }

  Future<void> _addModifier() async {
    final result = await _promptNamePrice(context,
        title: 'New add-on', nameHint: 'e.g. Extra cheese');
    if (result == null) return;
    await _post('modifiers', result);
  }

  Future<void> _post(
      String path, ({String name, int priceDeltaMinor}) v) async {
    try {
      await ref.read(catalogClientProvider).dio.post(
        '/api/v1/vendors/${widget.vendorId}/menu/items/${widget.item['itemId']}/$path',
        data: {'name': v.name, 'priceDeltaMinor': v.priceDeltaMinor},
      );
      if (mounted) {
        _snack(context, 'Added');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _snack(context, 'Failed: ${friendlyError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final variants = (widget.item['variants'] as List?) ?? const [];
    final modifiers = (widget.item['modifiers'] as List?) ?? const [];
    return Padding(
      padding: EdgeInsets.only(
        left: BhookSpacing.lg,
        right: BhookSpacing.lg,
        top: BhookSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + BhookSpacing.lg,
      ),
      child: ContentBound(
        maxWidth: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: BhookColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('${widget.item['name']} · options',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _extrasGroup(
              context,
              title: 'Variants',
              subtitle: 'Size or portion options with a price difference',
              items: variants,
              onAdd: _addVariant,
            ),
            const SizedBox(height: 16),
            _extrasGroup(
              context,
              title: 'Add-ons',
              subtitle: 'Optional extras customers can add',
              items: modifiers,
              onAdd: _addModifier,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _extrasGroup(BuildContext context,
      {required String title,
      required String subtitle,
      required List<dynamic> items,
      required VoidCallback onAdd}) {
    return Container(
      padding: const EdgeInsets.all(BhookSpacing.md),
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.md),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: BhookColors.inkStrong)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: BhookColors.inkMuted, fontSize: 12)),
                  ],
                ),
              ),
              TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add')),
            ],
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('None yet.',
                  style: TextStyle(color: BhookColors.inkFaint, fontSize: 13)),
            )
          else
            for (final e in items.whereType<Map<String, dynamic>>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(e['name']?.toString() ?? '')),
                    Text(
                      _deltaLabel((e['priceDeltaMinor'] as num?)?.toInt() ?? 0),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: BhookColors.inkStrong),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  String _deltaLabel(int minor) {
    if (minor == 0) return 'Free';
    final sign = minor > 0 ? '+' : '-';
    return '$sign${Money.format(minor.abs())}';
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

Future<String?> _promptText(BuildContext context,
    {required String title,
    required String hint,
    String initialValue = '',
    String confirmLabel = 'Create'}) async {
  final ctrl = TextEditingController(text: initialValue);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel)),
      ],
    ),
  );
  if (ok != true) return null;
  return ctrl.text.trim();
}

Future<({String name, int priceDeltaMinor})?> _promptNamePrice(
    BuildContext context,
    {required String title,
    required String nameHint}) async {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration:
                  InputDecoration(labelText: 'Name', hintText: nameHint)),
          const SizedBox(height: 12),
          TextField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            decoration: const InputDecoration(
                labelText: 'Price change (₹)',
                hintText: '0 for free',
                prefixText: '₹ '),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add')),
      ],
    ),
  );
  if (ok != true) return null;
  final name = nameCtrl.text.trim();
  if (name.isEmpty) return null;
  final rupees = double.tryParse(priceCtrl.text.trim()) ?? 0;
  return (name: name, priceDeltaMinor: (rupees * 100).round());
}

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String friendlyError(Object e) {
  final s = e.toString();
  if (s.length > 160) return '${s.substring(0, 160)}…';
  return s;
}
