import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/widgets.dart';

final _myVendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res =
      await ref.read(catalogClientProvider).dio.get('/api/v1/vendors/me');
  return ((res.data as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
});

class MyVendorsScreen extends ConsumerWidget {
  const MyVendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(_myVendorsProvider);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(_myVendorsProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
                      BhookSpacing.md, BhookSpacing.screenPad, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Good day, chef',
                                style: TextStyle(
                                    color: BhookColors.inkMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Your kitchens',
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
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
                        onPressed: () async {
                          await ref.read(tokenStorageProvider).clear();
                          ref.invalidate(authSessionProvider);
                          if (context.mounted) context.go('/login');
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: BhookColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add_business_outlined),
                        tooltip: 'Apply as a vendor',
                        onPressed: () => context.push('/apply'),
                      ),
                    ],
                  ),
                ),
              ),
              vendors.when(
                loading: () => const SliverFillRemaining(
                    hasScrollBody: false, child: ListSkeleton()),
                error: (e, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorRetry(
                    message: 'Could not load your vendor accounts.',
                    onRetry: () => ref.invalidate(_myVendorsProvider),
                  ),
                ),
                data: (list) => list.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.store_outlined,
                          title: 'No kitchens yet',
                          message:
                              'Apply to open your kitchen on Bhook. Your menu tools will appear after you submit the application.',
                          action: FilledButton.icon(
                            onPressed: () => context.push('/apply'),
                            icon: const Icon(Icons.add_business_outlined),
                            label: const Text('Apply as a vendor'),
                          ),
                        ),
                      )
                    : SliverToBoxAdapter(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final cards = [
                              for (final vendor in list)
                                _VendorCard(vendor: vendor),
                            ];
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  BhookSpacing.screenPad,
                                  BhookSpacing.lg,
                                  BhookSpacing.screenPad,
                                  BhookSpacing.xxl),
                              child: constraints.maxWidth < Breakpoints.tablet
                                  ? Column(
                                      children: [
                                        for (var i = 0;
                                            i < cards.length;
                                            i++) ...[
                                          cards[i],
                                          if (i < cards.length - 1)
                                            const SizedBox(
                                                height: BhookSpacing.md),
                                        ],
                                      ],
                                    )
                                  : ResponsiveGrid(
                                      minTileWidth: 360,
                                      spacing: BhookSpacing.lg,
                                      runSpacing: BhookSpacing.lg,
                                      children: cards,
                                    ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({required this.vendor});
  final Map<String, dynamic> vendor;

  @override
  Widget build(BuildContext context) {
    final name = vendor['displayName']?.toString() ?? '';
    final legal = vendor['legalName']?.toString() ?? '';
    final status = vendor['lifecycleStatus']?.toString() ?? '';
    final vendorId = vendor['id']?.toString() ?? '';
    return Material(
      color: BhookColors.card,
      elevation: 1,
      shadowColor: const Color(0x12000000),
      borderRadius: BorderRadius.circular(BhookRadius.lg),
      child: InkWell(
        onTap: () => context.push('/vendors/$vendorId'),
        borderRadius: BorderRadius.circular(BhookRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(BhookSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BhookRadius.lg),
            border: Border.all(color: BhookColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(BhookRadius.md),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          BhookColors.primary.withValues(alpha: 0.15),
                          BhookColors.accent.withValues(alpha: 0.2)
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'V',
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              color: BhookColors.primary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(legal,
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        StatusPill(
                            label: status, color: StatusPill.colorFor(status)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: BhookColors.inkFaint),
                ],
              ),
              const SizedBox(height: BhookSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/vendors/$vendorId/menu'),
                      icon: const Icon(Icons.restaurant_menu, size: 18),
                      label: const Text('Menu'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push('/vendors/$vendorId'),
                      icon: const Icon(Icons.insights, size: 18),
                      label: const Text('Manage'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
