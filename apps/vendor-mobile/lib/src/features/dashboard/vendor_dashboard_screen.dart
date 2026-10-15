import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/widgets.dart';
import 'analytics_service.dart';

class VendorDashboardScreen extends ConsumerStatefulWidget {
  const VendorDashboardScreen(
      {super.key, required this.vendorId, required this.vendorName});
  final String vendorId;
  final String vendorName;

  @override
  ConsumerState<VendorDashboardScreen> createState() =>
      _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends ConsumerState<VendorDashboardScreen> {
  AnalyticsRange _range = AnalyticsRange.sevenDays;

  @override
  Widget build(BuildContext context) {
    final args = (vendorId: widget.vendorId, range: _range);
    final analytics = ref.watch(vendorAnalyticsProvider(args));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(vendorAnalyticsProvider(args)),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
            BhookSpacing.lg, BhookSpacing.screenPad, BhookSpacing.xxl),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.vendorName,
                        style: Theme.of(context).textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    const Text('A quick read on your kitchen today',
                        style: TextStyle(
                            color: BhookColors.inkMuted, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: BhookSpacing.md),
          _RangeSelector(
              range: _range, onChanged: (r) => setState(() => _range = r)),
          const SizedBox(height: BhookSpacing.lg),
          analytics.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 24),
              child: ErrorRetry(
                message: 'Could not load analytics.',
                onRetry: () => ref.invalidate(vendorAnalyticsProvider(args)),
              ),
            ),
            data: (a) => _AnalyticsBody(analytics: a),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.range, required this.onChanged});
  final AnalyticsRange range;
  final ValueChanged<AnalyticsRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final r in AnalyticsRange.values) ...[
            ChoiceChip(
              selected: r == range,
              label: Text(r.label),
              onSelected: (_) => onChanged(r),
              selectedColor: BhookColors.primarySoft,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: r == range ? BhookColors.primary : BhookColors.inkMuted,
              ),
              side: BorderSide(
                  color:
                      r == range ? BhookColors.primary : BhookColors.divider),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.analytics});
  final VendorAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final hasData = a.totalOrders > 0 || a.daily.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveGrid(
          minTileWidth: 200,
          children: [
            _KpiCard(
              label: 'Revenue',
              value: Money.format(a.grossRevenueMinor, currency: a.currency),
              icon: Icons.payments_outlined,
              tint: BhookColors.success,
            ),
            _KpiCard(
              label: 'Orders',
              value: '${a.totalOrders}',
              icon: Icons.receipt_long_outlined,
              tint: BhookColors.info,
            ),
            _KpiCard(
              label: 'Avg order',
              value: Money.format(a.avgOrderValueMinor, currency: a.currency),
              icon: Icons.trending_up,
              tint: BhookColors.primary,
            ),
            _KpiCard(
              label: 'Items sold',
              value: '${a.itemsSold}',
              icon: Icons.lunch_dining_outlined,
              tint: BhookColors.accent,
            ),
          ],
        ),
        const SizedBox(height: BhookSpacing.lg),
        if (!hasData)
          const _Panel(
            title: 'No sales yet',
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Revenue, order trends and your best-selling dishes will appear here once paid orders start coming in.',
                style: TextStyle(color: BhookColors.inkMuted),
              ),
            ),
          )
        else ...[
          _Panel(
            title: 'Revenue trend',
            subtitle: 'Gross revenue per day',
            child: _RevenueChart(points: a.daily, currency: a.currency),
          ),
          const SizedBox(height: BhookSpacing.lg),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= Breakpoints.tablet;
              final left = _Panel(
                title: 'Top dishes',
                subtitle: 'By quantity sold',
                child: _TopItems(items: a.topItems, currency: a.currency),
              );
              final right = _Panel(
                title: 'Order status',
                subtitle: 'Distribution in range',
                child: _StatusBreakdown(byStatus: a.ordersByStatus),
              );
              if (!wide) {
                return Column(children: [
                  left,
                  const SizedBox(height: BhookSpacing.lg),
                  right
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: BhookSpacing.lg),
                  Expanded(child: right),
                ],
              );
            },
          ),
          if (a.topItems.length > 1) ...[
            const SizedBox(height: BhookSpacing.lg),
            _Panel(
              title: 'Needs attention',
              subtitle: 'Lowest-selling dishes in range',
              child: _TopItems(
                items: a.topItems.reversed.take(3).toList(),
                currency: a.currency,
                muted: true,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.tint});
  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.md, BhookSpacing.md, BhookSpacing.md, BhookSpacing.lg),
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.lg),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(BhookRadius.md),
            ),
            child: Icon(icon, color: tint, size: 20),
          ),
          const SizedBox(height: 16),
          Text(value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: BhookColors.inkStrong,
                  letterSpacing: -0.4),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: BhookColors.inkMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BhookSpacing.lg),
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.lg),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: BhookSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.points, required this.currency});
  final List<DailyPoint> points;
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(
            child: Text('No data in range',
                style: TextStyle(color: BhookColors.inkMuted))),
      );
    }
    final maxRev =
        points.map((p) => p.revenueMinor).fold<int>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 160,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in points)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _shortMoney(p.revenueMinor),
                            style: const TextStyle(
                                fontSize: 9,
                                color: BhookColors.inkFaint,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          FractionallySizedBox(
                            heightFactor: maxRev == 0
                                ? 0.02
                                : (p.revenueMinor / maxRev).clamp(0.02, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    BhookColors.primary,
                                    BhookColors.accent
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final p in points)
                Expanded(
                  child: Text(
                    _dayLabel(p.date),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 9, color: BhookColors.inkFaint),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortMoney(int minor) {
    final rupees = minor / 100.0;
    if (rupees >= 1000) return '${(rupees / 1000).toStringAsFixed(1)}k';
    return rupees.toStringAsFixed(0);
  }

  String _dayLabel(String iso) {
    // iso is yyyy-MM-dd
    final parts = iso.split('-');
    if (parts.length == 3) return '${parts[2]}/${parts[1]}';
    return iso;
  }
}

class _TopItems extends StatelessWidget {
  const _TopItems(
      {required this.items, required this.currency, this.muted = false});
  final List<ItemStat> items;
  final String currency;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No dishes sold yet.',
            style: TextStyle(color: BhookColors.inkMuted)),
      );
    }
    final maxQty =
        items.map((i) => i.quantity).fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.itemName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: BhookColors.inkStrong),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxQty == 0
                              ? 0
                              : (item.quantity / maxQty).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: BhookColors.divider,
                          color: muted
                              ? BhookColors.inkFaint
                              : BhookColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${item.quantity} sold',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: BhookColors.inkStrong,
                            fontSize: 13)),
                    Text(Money.format(item.revenueMinor, currency: currency),
                        style: const TextStyle(
                            color: BhookColors.inkMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.byStatus});
  final Map<String, int> byStatus;

  @override
  Widget build(BuildContext context) {
    if (byStatus.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No orders in range.',
            style: TextStyle(color: BhookColors.inkMuted)),
      );
    }
    final entries = byStatus.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                StatusPill(
                    label: _pretty(e.key), color: StatusPill.colorFor(e.key)),
                const Spacer(),
                Text('${e.value}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: BhookColors.inkStrong)),
                const SizedBox(width: 6),
                Text(
                    total == 0 ? '' : '(${((e.value / total) * 100).round()}%)',
                    style: const TextStyle(
                        color: BhookColors.inkFaint, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }

  String _pretty(String status) => status
      .split('_')
      .map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase())
      .join(' ');
}
