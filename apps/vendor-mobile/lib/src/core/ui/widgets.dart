import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, BhookSpacing.xl, BhookSpacing.screenPad, BhookSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.color, this.dot = true});
  final String label;
  final Color? color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = color ?? BhookColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(BhookRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
        ],
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  static Color colorFor(String status) {
    switch (status) {
      case 'PAYMENT_PENDING':
      case 'PENDING':
      case 'PROCESSING':
      case 'OFFERED':
        return BhookColors.primary;
      case 'PAID':
      case 'VENDOR_ACCEPTED':
      case 'PREPARING':
      case 'READY_FOR_PICKUP':
      case 'DELIVERY_ASSIGNED':
      case 'PICKED_UP':
      case 'OUT_FOR_DELIVERY':
        return BhookColors.info;
      case 'COMPLETED':
      case 'COLLECTED':
      case 'SUCCESS':
      case 'ACTIVE':
      case 'ONLINE':
        return BhookColors.success;
      case 'CANCELLED':
      case 'VENDOR_REJECTED':
      case 'REFUNDED':
      case 'PAYMENT_FAILED':
      case 'DELIVERY_FAILED':
      case 'REJECTED':
      case 'OFFLINE':
        return BhookColors.danger;
      default:
        return BhookColors.inkMuted;
    }
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon, this.action});
  final String title;
  final String? message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(BhookSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: BhookColors.primarySoft, borderRadius: BorderRadius.circular(BhookRadius.pill)),
            child: Icon(icon ?? Icons.inbox_outlined, size: 34, color: BhookColors.primary),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: BhookColors.inkMuted)),
          ],
          if (action != null) ...[
            const SizedBox(height: 24),
            action!,
          ],
        ],
      ),
    );
  }
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({super.key, this.width, this.height = 16, this.radius = BhookRadius.sm});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: BhookColors.divider,
      highlightColor: Colors.white,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: BhookColors.divider, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(BhookSpacing.screenPad),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: BhookSpacing.md),
      itemBuilder: (context, _) => Container(
        padding: const EdgeInsets.all(BhookSpacing.lg),
        decoration: BoxDecoration(
          color: BhookColors.card,
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          border: Border.all(color: BhookColors.divider),
        ),
        child: Row(
          children: [
            const SkeletonBlock(width: 56, height: 56, radius: BhookRadius.md),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBlock(width: 160, height: 14),
                  SizedBox(height: 8),
                  SkeletonBlock(width: 100, height: 12),
                  SizedBox(height: 6),
                  SkeletonBlock(width: 80, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off_outlined,
      title: 'Something went wrong',
      message: message,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Try again'),
      ),
    );
  }
}
