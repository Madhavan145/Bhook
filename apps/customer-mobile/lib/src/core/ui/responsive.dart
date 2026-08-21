import 'package:flutter/widgets.dart';

class CustomerBreakpoints {
  const CustomerBreakpoints._();
  static const double tablet = 720;
  static const double desktop = 1100;
}

extension CustomerResponsiveX on BuildContext {
  bool get isCustomerWide =>
      MediaQuery.sizeOf(this).width >= CustomerBreakpoints.tablet;
  bool get isCustomerDesktop =>
      MediaQuery.sizeOf(this).width >= CustomerBreakpoints.desktop;
}

class CustomerContentBound extends StatelessWidget {
  const CustomerContentBound(
      {super.key, required this.child, this.maxWidth = 1440});

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

class CustomerResponsiveGrid extends StatelessWidget {
  const CustomerResponsiveGrid({
    super.key,
    required this.children,
    this.minTileWidth = 360,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            (constraints.maxWidth / minTileWidth).floor().clamp(1, 4);
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
