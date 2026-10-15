import 'package:flutter/widgets.dart';

/// Simple, dependency-free responsive breakpoints shared across the vendor app.
class Breakpoints {
  const Breakpoints._();
  static const double tablet = 720;
  static const double desktop = 1100;
}

enum FormFactor { compact, medium, expanded }

FormFactor formFactorOf(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= Breakpoints.desktop) return FormFactor.expanded;
  if (w >= Breakpoints.tablet) return FormFactor.medium;
  return FormFactor.compact;
}

extension FormFactorX on BuildContext {
  FormFactor get formFactor => formFactorOf(this);
  bool get isCompact => formFactorOf(this) == FormFactor.compact;
  bool get isExpanded => formFactorOf(this) == FormFactor.expanded;
}

/// Centers content and caps its width on large screens so the vendor app does
/// not stretch edge-to-edge on desktop.
class ContentBound extends StatelessWidget {
  const ContentBound({super.key, required this.child, this.maxWidth = 1160});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A responsive grid that lays children out in [columnsFor] columns based on
/// the current width, wrapping automatically.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.minTileWidth = 220,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        int columns = (maxWidth / minTileWidth).floor().clamp(1, 4);
        final totalSpacing = spacing * (columns - 1);
        final tileWidth = (maxWidth - totalSpacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children) SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
