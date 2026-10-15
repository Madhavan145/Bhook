import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../core/app_config.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';
import '../../core/ui/responsive.dart';
import '../auth/auth_service.dart';
import '../auth/auth_state.dart';

final _profileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.read(customerClientProvider).dio;
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      final res = await client.get('/api/v1/customers/me');
      return (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    } on DioException catch (error) {
      final isMissingProfile = error.response?.statusCode == 404 &&
          error.response?.data is Map &&
          (error.response?.data['code']?.toString() == 'RESOURCE_NOT_FOUND');
      if (!isMissingProfile || attempt == 4) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }
  throw StateError('Customer profile could not be loaded');
});

final _vendorsProvider =
    FutureProvider.autoDispose<List<VendorSummary>>((ref) async {
  final profile = await ref.watch(_profileProvider.future);
  final activeCampus = profile['activeCampusId'] as String?;
  if (activeCampus == null) return const [];
  final res = await ref.read(catalogClientProvider).dio.get(
    '/api/v1/vendors',
    queryParameters: {'campusId': activeCampus},
  );
  return ((res.data as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(VendorSummary.fromJson)
      .toList();
});

final _offersProvider =
    FutureProvider.autoDispose<List<OfferSummary>>((ref) async {
  final profile = await ref.watch(_profileProvider.future);
  final activeCampus = profile['activeCampusId'] as String?;
  if (activeCampus == null) return const [];
  final res = await ref.read(catalogClientProvider).dio.get(
    '/api/v1/vendors/offers',
    queryParameters: {'campusId': activeCampus},
  );
  return ((res.data as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(OfferSummary.fromJson)
      .toList();
});

/// Matches vendors by name/description directly, and by dish name via each
/// vendor's published catalog so searching a dish (e.g. "Biryani") finds the
/// vendors that actually serve it rather than only matching vendor names.
final _searchResultsProvider = FutureProvider.autoDispose
    .family<List<VendorSummary>, String>((ref, query) async {
  final vendors = await ref.watch(_vendorsProvider.future);
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return vendors;

  final direct = <VendorSummary>[];
  final candidates = <VendorSummary>[];
  for (final v in vendors) {
    final matchesDirect = v.displayName.toLowerCase().contains(q) ||
        (v.description ?? '').toLowerCase().contains(q);
    (matchesDirect ? direct : candidates).add(v);
  }

  final catalogClient = ref.read(catalogClientProvider).dio;
  final dishMatches = await Future.wait(candidates.map((v) async {
    try {
      final res = await catalogClient.get('/api/v1/vendors/${v.id}/catalog');
      final menus =
          (res.data as Map<String, dynamic>)['menus'] as List? ?? const [];
      final hasMatch = menus.any((menu) =>
          ((menu as Map<String, dynamic>)['categories'] as List? ?? const [])
              .any((cat) =>
                  ((cat as Map<String, dynamic>)['items'] as List? ?? const [])
                      .any((item) =>
                          (item as Map<String, dynamic>)['name']
                              ?.toString()
                              .toLowerCase()
                              .contains(q) ??
                          false)));
      return hasMatch ? v : null;
    } catch (_) {
      return null;
    }
  }));

  return [...direct, ...dishMatches.whereType<VendorSummary>()];
});

final _campusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final profile = await ref.watch(_profileProvider.future);
  final activeCampus = profile['activeCampusId'] as String?;
  if (activeCampus == null) return null;
  final res = await ref
      .read(campusClientProvider)
      .dio
      .get('/api/v1/campuses/$activeCampus');
  return res.data as Map<String, dynamic>;
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedChip = 'All';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _onChipSelected(String label) {
    setState(() => _selectedChip = label);
    _debounce?.cancel();
    if (label == 'All') {
      _searchCtrl.clear();
      setState(() => _query = '');
    } else {
      _searchCtrl.text = label;
      setState(() => _query = label);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendors = ref.watch(_searchResultsProvider(_query));
    final campus = ref.watch(_campusProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(_profileProvider);
            ref.invalidate(_vendorsProvider);
            ref.invalidate(_offersProvider);
            ref.invalidate(_campusProvider);
            ref.invalidate(_searchResultsProvider);
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _TopBar(campus: campus)),
              const SliverToBoxAdapter(
                child: PlayfulBanner(
                  title: 'CAMPUS CRAVINGS',
                  subtitle: 'Good food, found close to you.',
                  icon: Icons.restaurant_rounded,
                ),
              ),
              SliverToBoxAdapter(
                child: _SearchBar(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() {
                    _selectedChip = v.isEmpty ? 'All' : '';
                    _setQuery(v);
                  }),
                ),
              ),
              SliverToBoxAdapter(
                child: _QuickChips(
                    selected: _selectedChip, onSelected: _onChipSelected),
              ),
              ref.watch(_offersProvider).when(
                    loading: () =>
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    error: (_, __) =>
                        const SliverToBoxAdapter(child: SizedBox.shrink()),
                    data: (offers) => offers.isEmpty
                        ? const SliverToBoxAdapter(child: SizedBox.shrink())
                        : SliverToBoxAdapter(
                            child: _OffersRail(offers: offers)),
                  ),
              const SliverToBoxAdapter(
                child: SectionHeader(
                    title: 'On your campus',
                    subtitle: 'Vendors open for orders'),
              ),
              vendors.when(
                loading: () => const SliverToBoxAdapter(
                    child: ListSkeleton(scrollable: false)),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorRetry(
                    message: e is DioException && e.response?.statusCode == 404
                        ? 'Your customer profile is still being set up. Try again in a moment.'
                        : 'Could not load vendors right now.',
                    onRetry: () {
                      ref.invalidate(_profileProvider);
                      ref.invalidate(_vendorsProvider);
                      ref.invalidate(_offersProvider);
                      ref.invalidate(_campusProvider);
                      ref.invalidate(_searchResultsProvider);
                    },
                  ),
                ),
                data: (filtered) {
                  if (filtered.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.storefront_outlined,
                        title: _query.isEmpty
                            ? 'No vendors are live yet'
                            : 'No matches',
                        message: _query.isEmpty
                            ? 'Your campus doesn\'t have active vendors right now. Check back soon.'
                            : 'Try a different search.',
                      ),
                    );
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
                          0, BhookSpacing.screenPad, 112),
                      child: context.isCustomerWide
                          ? CustomerResponsiveGrid(
                              children: [
                                for (final vendor in filtered)
                                  _VendorCard(vendor: vendor),
                              ],
                            )
                          : Column(
                              children: [
                                for (var i = 0; i < filtered.length; i++) ...[
                                  _VendorCard(vendor: filtered[i]),
                                  if (i < filtered.length - 1)
                                    const SizedBox(height: BhookSpacing.md),
                                ],
                              ],
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.campus});
  final AsyncValue<Map<String, dynamic>?> campus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = campus.asData?.value?['displayName']?.toString() ?? '…';
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, BhookSpacing.lg, BhookSpacing.screenPad, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.location_on, size: 18, color: BhookColors.primary),
                  SizedBox(width: 4),
                  Text('Delivering to',
                      style:
                          TextStyle(color: BhookColors.inkMuted, fontSize: 12)),
                ]),
                const SizedBox(height: 2),
                Text(name,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(letterSpacing: -0.3),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) async {
              if (value != 'logout') return;
              await ref.read(authServiceProvider).logout();
              ref.invalidate(authSessionProvider);
              if (context.mounted) context.go('/login');
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'logout',
                child: Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, BhookSpacing.xl, BhookSpacing.screenPad, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Find your next bite',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: BhookSpacing.sm),
          TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search vendors or dishes',
              prefixIcon: const Icon(Icons.search, color: BhookColors.inkMuted),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: BhookSpacing.lg),
          Text('Browse by craving',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: BhookColors.inkMuted,
                    fontWeight: FontWeight.w800,
                  )),
        ],
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  const _QuickChips({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;

  static const _items = [
    'All',
    'Rolls',
    'Meals',
    'Thali',
    'Biryani',
    'Snacks',
    'Chinese',
    'South Indian',
    'Fast Food',
    'Drinks',
    'Shakes',
    'Sweets',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            BhookSpacing.screenPad, BhookSpacing.sm, BhookSpacing.screenPad, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = _items[i];
          final active = label == selected;
          return InkWell(
            onTap: () => onSelected(label),
            borderRadius: BorderRadius.circular(BhookRadius.pill),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: active ? BhookColors.action : BhookColors.card,
                borderRadius: BorderRadius.circular(BhookRadius.pill),
                border: Border.all(
                    color: active ? BhookColors.action : BhookColors.divider),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : BhookColors.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OffersRail extends StatelessWidget {
  const _OffersRail({required this.offers});
  final List<OfferSummary> offers;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: BhookSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Fresh offers',
            subtitle: 'Good dishes, gentler prices, limited time.',
          ),
          SizedBox(
            height: 198,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                  BhookSpacing.screenPad, 0, BhookSpacing.screenPad, 6),
              scrollDirection: Axis.horizontal,
              itemCount: offers.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: BhookSpacing.md),
              itemBuilder: (context, index) =>
                  _OfferCard(offer: offers[index], index: index),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatefulWidget {
  const _OfferCard({required this.offer, required this.index});
  final OfferSummary offer;
  final int index;

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _badgeController;
  late final Animation<double> _badgeMotion;

  @override
  void initState() {
    super.initState();
    _badgeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _badgeMotion = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 0.07), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.07, end: -0.07), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.07, end: 0.04), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: 0), weight: 35),
    ]).animate(CurvedAnimation(
        parent: _badgeController, curve: Curves.easeInOutCubic));
    Future<void>.delayed(Duration(milliseconds: 650 + widget.index * 140), () {
      if (mounted) _badgeController.repeat();
    });
  }

  @override
  void dispose() {
    _badgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final saved = offer.priceMinor <= 0
        ? 0
        : (((offer.priceMinor - offer.offerPriceMinor) * 100) /
                offer.priceMinor)
            .round();

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 360 + (widget.index * 70)),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: child,
        ),
      ),
      child: SizedBox(
        width: 232,
        height: 174,
        child: Material(
          color: BhookColors.card,
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          child: InkWell(
            onTap: () => context
                .push('/vendors/${offer.vendorId}?itemId=${offer.itemId}'),
            borderRadius: BorderRadius.circular(BhookRadius.lg),
            child: Container(
              decoration: BoxDecoration(
                color: BhookColors.card,
                borderRadius: BorderRadius.circular(BhookRadius.lg),
                border: Border.all(color: BhookColors.inkStrong),
                boxShadow: const [
                  BoxShadow(
                    color: BhookColors.inkStrong,
                    offset: Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(BhookRadius.lg),
                child: Column(
                  children: [
                    SizedBox(
                      height: 92,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DishImage(
                              objectKey: offer.imageObjectKey,
                              size: double.infinity,
                              radius: 0),
                          Positioned(
                            left: 10,
                            top: 10,
                            child: AnimatedBuilder(
                              animation: _badgeMotion,
                              builder: (context, badge) => Transform.rotate(
                                angle: _badgeMotion.value,
                                child: Transform.scale(
                                  scale: 1 + _badgeMotion.value.abs() * 0.7,
                                  child: badge,
                                ),
                              ),
                              child: ClipPath(
                                clipper: _OfferBurstClipper(),
                                child: Container(
                                  width: 62,
                                  height: 62,
                                  color: BhookColors.action,
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('SAVE',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              height: 1,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.7)),
                                      Text('$saved%',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              height: 1,
                                              fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: ColoredBox(
                              color: Color(0xB320242D),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: Text('TODAY\'S PICK',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8)),
                              ),
                            ),
                          ),
                          const Positioned(
                            right: 10,
                            bottom: 10,
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.arrow_outward_rounded,
                                  size: 17, color: BhookColors.inkStrong),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(BhookSpacing.md,
                            BhookSpacing.sm, BhookSpacing.md, BhookSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(offer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 15)),
                            const SizedBox(height: 2),
                            Text(offer.vendorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: BhookColors.inkMuted, fontSize: 11)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 12, color: BhookColors.inkMuted),
                                const SizedBox(width: 3),
                                Expanded(
                                  child: Text(
                                    _offerExpiryLabel(offer.offerEndsAt),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: BhookColors.inkMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Text(Money.format(offer.offerPriceMinor),
                                    style: const TextStyle(
                                        color: BhookColors.action,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16)),
                                const SizedBox(width: 6),
                                Text(Money.format(offer.priceMinor),
                                    style: const TextStyle(
                                        color: BhookColors.inkFaint,
                                        decoration: TextDecoration.lineThrough,
                                        fontSize: 10)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OfferBurstClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2;
    final innerRadius = outerRadius * 0.82;
    const points = 16;
    for (var i = 0; i < points; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = -math.pi / 2 + (math.pi * 2 * i / points);
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

String _offerExpiryLabel(DateTime? offerEndsAt) {
  if (offerEndsAt == null) return 'Limited time';
  final localEnd = offerEndsAt.toLocal();
  final remaining = localEnd.difference(DateTime.now());
  if (remaining.isNegative) return 'Offer ended';

  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = '${months[localEnd.month - 1]} ${localEnd.day}';
  if (remaining.inDays > 0) {
    return 'Ends $date · ${remaining.inDays}d left';
  }
  if (remaining.inHours > 0) {
    return 'Ends $date · ${remaining.inHours}h ${remaining.inMinutes % 60}m left';
  }
  return 'Ends $date · ${remaining.inMinutes.clamp(1, 59)}m left';
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor});
  final VendorSummary vendor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.lg),
        border: Border.all(color: BhookColors.divider),
        boxShadow: const [
          BoxShadow(
            color: BhookColors.inkStrong,
            offset: Offset(3, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/vendors/${vendor.id}'),
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(BhookSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VendorLogo(vendor: vendor),
                const SizedBox(width: BhookSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vendor.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if ((vendor.description ?? '').isNotEmpty)
                        Text(vendor.description!,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: BhookSpacing.sm),
                const Icon(Icons.chevron_right, color: BhookColors.inkFaint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VendorLogo extends StatelessWidget {
  const _VendorLogo({required this.vendor});
  final VendorSummary vendor;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.imageUrl(vendor.logoObjectKey);
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BhookRadius.md),
        gradient: url == null
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  BhookColors.sky,
                  BhookColors.primarySoft,
                ],
              )
            : null,
        image: url == null
            ? null
            : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
      child: url != null
          ? null
          : Center(
              child: Text(
                vendor.displayName.isNotEmpty
                    ? vendor.displayName[0].toUpperCase()
                    : 'B',
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: BhookColors.primary),
              ),
            ),
    );
  }
}

class VendorSummary {
  const VendorSummary(
      {required this.id,
      required this.displayName,
      this.description,
      this.logoObjectKey});
  final String id;
  final String displayName;
  final String? description;
  final String? logoObjectKey;

  factory VendorSummary.fromJson(Map<String, dynamic> json) => VendorSummary(
        id: json['id']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? 'Vendor',
        description: json['description']?.toString(),
        logoObjectKey: json['logoObjectKey']?.toString(),
      );
}

class OfferSummary {
  const OfferSummary({
    required this.itemId,
    required this.vendorId,
    required this.vendorName,
    required this.name,
    required this.priceMinor,
    required this.offerPriceMinor,
    required this.offerEndsAt,
    this.imageObjectKey,
  });

  final String itemId;
  final String vendorId;
  final String vendorName;
  final String name;
  final int priceMinor;
  final int offerPriceMinor;
  final DateTime? offerEndsAt;
  final String? imageObjectKey;

  factory OfferSummary.fromJson(Map<String, dynamic> json) => OfferSummary(
        itemId: json['itemId']?.toString() ?? '',
        vendorId: json['vendorId']?.toString() ?? '',
        vendorName: json['vendorName']?.toString() ?? 'Vendor',
        name: json['name']?.toString() ?? 'Dish',
        priceMinor: (json['priceMinor'] as num?)?.toInt() ?? 0,
        offerPriceMinor: (json['offerPriceMinor'] as num?)?.toInt() ?? 0,
        offerEndsAt: DateTime.tryParse(json['offerEndsAt']?.toString() ?? ''),
        imageObjectKey: json['imageObjectKey']?.toString(),
      );
}
