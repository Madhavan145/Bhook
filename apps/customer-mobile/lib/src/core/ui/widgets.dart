import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../app_config.dart';
import '../theme.dart';

/// Renders a stored dish/vendor image, falling back to a branded
/// "NO IMAGE" placeholder when the object key is missing or fails to load.
class DishImage extends StatelessWidget {
  const DishImage({
    super.key,
    required this.objectKey,
    this.size = 76,
    this.radius = BhookRadius.md,
    this.icon = Icons.restaurant_rounded,
  });

  final String? objectKey;
  final double size;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.imageUrl(objectKey);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
        ),
        clipBehavior: Clip.antiAlias,
        child: url == null
            ? _placeholder()
            : Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (c, child, progress) =>
                    progress == null ? child : _placeholder(loading: true),
                errorBuilder: (c, e, s) => _placeholder(),
              ),
      ),
    );
  }

  Widget _placeholder({bool loading = false}) {
    return Container(
      color: BhookColors.primarySoft,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: BhookColors.primary),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: size * 0.30,
                    color: BhookColors.primary.withValues(alpha: 0.55)),
                if (size >= 64) ...[
                  const SizedBox(height: 4),
                  Text('NO IMAGE',
                      style: TextStyle(
                        fontSize: 8.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w800,
                        color: BhookColors.primary.withValues(alpha: 0.55),
                      )),
                ],
              ],
            ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
      {super.key, required this.title, this.action, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
          BhookSpacing.xl, BhookSpacing.screenPad, BhookSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: BhookColors.mustard,
                    borderRadius: BorderRadius.circular(BhookRadius.pill),
                  ),
                ),
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

class PlayfulBanner extends StatelessWidget {
  const PlayfulBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color = BhookColors.mustard,
    this.margin = const EdgeInsets.fromLTRB(
        BhookSpacing.screenPad, BhookSpacing.md, BhookSpacing.screenPad, 0),
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(BhookSpacing.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(BhookRadius.xl),
        border: Border.all(color: BhookColors.inkStrong, width: 1.1),
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
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: BhookColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: BhookSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1)),
                const SizedBox(height: 5),
                Text(subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: BhookColors.inkStrong,
                          fontWeight: FontWeight.w700,
                        )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
      {super.key, required this.label, this.color, this.dot = true});
  final String label;
  final Color? color;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final c = color ?? BhookColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(BhookRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: c, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static Color colorFor(String status) {
    switch (status) {
      case 'PAYMENT_PENDING':
      case 'PENDING':
      case 'PROCESSING':
        return BhookColors.accent;
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
        return BhookColors.success;
      case 'CANCELLED':
      case 'VENDOR_REJECTED':
      case 'REFUNDED':
      case 'PAYMENT_FAILED':
      case 'DELIVERY_FAILED':
        return BhookColors.danger;
      default:
        return BhookColors.inkMuted;
    }
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.title, this.message, this.icon, this.action});
  final String title;
  final String? message;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(BhookSpacing.screenPad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            decoration: BoxDecoration(
              color: BhookColors.card,
              borderRadius: BorderRadius.circular(BhookRadius.xl),
              border: Border.all(color: BhookColors.inkStrong, width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: BhookColors.inkStrong,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('BHOOK BOARD',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: BhookColors.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            )),
                    Transform.rotate(
                      angle: 0.12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        color: BhookColors.mustard,
                        child: const Text('FRESH',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: BhookColors.mint,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: BhookColors.inkStrong, width: 1.2),
                  ),
                  child: Icon(icon ?? Icons.inbox_outlined,
                      size: 40, color: BhookColors.inkStrong),
                ),
                const SizedBox(height: 18),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: BhookColors.inkMuted)),
                ],
                if (action != null) ...[
                  const SizedBox(height: 20),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock(
      {super.key, this.width, this.height = 16, this.radius = BhookRadius.sm});
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
        decoration: BoxDecoration(
          color: BhookColors.divider,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 4, this.scrollable = true});
  final int count;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(BhookSpacing.screenPad),
      shrinkWrap: !scrollable,
      physics: scrollable ? null : const NeverScrollableScrollPhysics(),
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
                children: [
                  const SkeletonBlock(width: 160, height: 14),
                  const SizedBox(height: 8),
                  const SkeletonBlock(width: 100, height: 12),
                  const SizedBox(height: 6),
                  const SkeletonBlock(width: 80, height: 12),
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
