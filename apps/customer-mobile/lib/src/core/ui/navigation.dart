import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/social/social_screen.dart';
import '../theme.dart';
import 'responsive.dart';

class BhookAppShell extends ConsumerWidget {
  const BhookAppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingRequests = ref.watch(relationshipsProvider).maybeWhen(
          data: (items) => items
              .where((item) =>
                  item['status'] == 'PENDING' &&
                  item['direction'] == 'INCOMING')
              .length,
          orElse: () => 0,
        );
    final navigation = BhookNavigationBar(
      location: location,
      incomingRequests: incomingRequests,
    );
    if (context.isCustomerWide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              CustomerNavigationRail(
                location: location,
                incomingRequests: incomingRequests,
              ),
              const VerticalDivider(width: 1, thickness: 0.8),
              Expanded(
                child: ColoredBox(
                  color: BhookColors.surface,
                  child: CustomerContentBound(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.isCustomerDesktop ? 20 : 8),
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(body: child, bottomNavigationBar: navigation);
  }
}

class CustomerNavigationRail extends StatelessWidget {
  const CustomerNavigationRail({
    required this.location,
    required this.incomingRequests,
    super.key,
  });

  final String location;
  final int incomingRequests;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex(location);
    final extended = context.isCustomerDesktop;
    final destinations = [
      (Icons.home_outlined, Icons.home, 'Home', '/'),
      (Icons.receipt_long_outlined, Icons.receipt_long, 'Orders', '/orders'),
      (Icons.people_outline, Icons.people, 'Friends', '/social'),
      (Icons.person_outline, Icons.person, 'Profile', '/profile'),
    ];
    return Container(
      width: extended ? 220 : 104,
      margin: const EdgeInsets.all(BhookSpacing.md),
      padding: const EdgeInsets.symmetric(
          horizontal: BhookSpacing.sm, vertical: BhookSpacing.md),
      decoration: BoxDecoration(
        color: BhookColors.mustard,
        borderRadius: BorderRadius.circular(BhookRadius.xl),
        border: Border.all(color: BhookColors.inkStrong),
        boxShadow: const [
          BoxShadow(
              color: BhookColors.inkStrong,
              offset: Offset(4, 4),
              blurRadius: 0),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => context.go('/'),
            borderRadius: BorderRadius.circular(BhookRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(BhookSpacing.sm),
              child: Row(
                mainAxisAlignment: extended
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restaurant_rounded,
                      color: BhookColors.primary, size: 28),
                  if (extended) ...[
                    const SizedBox(width: BhookSpacing.sm),
                    Text('Bhook',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: BhookColors.inkStrong)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: BhookSpacing.lg),
          for (var index = 0; index < destinations.length; index++) ...[
            _RailDestination(
              icon: destinations[index].$1,
              selectedIcon: destinations[index].$2,
              label: destinations[index].$3,
              selected: index == selected,
              extended: extended,
              badge: index == 2 ? incomingRequests : 0,
              onTap: () => _go(context, index),
            ),
            const SizedBox(height: BhookSpacing.sm),
          ],
          const Spacer(),
          Icon(Icons.local_fire_department_outlined,
              color: BhookColors.inkStrong, size: extended ? 22 : 18),
        ],
      ),
    );
  }

  static int _selectedIndex(String location) => location.startsWith('/orders')
      ? 1
      : location.startsWith('/social')
          ? 2
          : location.startsWith('/profile')
              ? 3
              : 0;

  static void _go(BuildContext context, int index) {
    context.go(switch (index) {
      1 => '/orders',
      2 => '/social',
      3 => '/profile',
      _ => '/',
    });
  }
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.extended,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BhookRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: BhookSpacing.sm, vertical: BhookSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? BhookColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          border: selected ? Border.all(color: BhookColors.inkStrong) : null,
        ),
        child: Row(
          mainAxisAlignment:
              extended ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(selected ? selectedIcon : icon,
                  color: selected ? BhookColors.action : BhookColors.inkMuted,
                  size: 22),
            ),
            if (extended) ...[
              const SizedBox(width: BhookSpacing.sm),
              Text(label,
                  style: TextStyle(
                      color:
                          selected ? BhookColors.action : BhookColors.inkMuted,
                      fontWeight:
                          selected ? FontWeight.w900 : FontWeight.w700)),
            ],
          ],
        ),
      ),
    );
  }
}

class BhookNavigationBar extends StatelessWidget {
  const BhookNavigationBar({
    required this.location,
    required this.incomingRequests,
    super.key,
  });

  final String location;
  final int incomingRequests;

  @override
  Widget build(BuildContext context) {
    final selected = location.startsWith('/orders')
        ? 1
        : location.startsWith('/social')
            ? 2
            : location.startsWith('/profile')
                ? 3
                : 0;
    final destinations = [
      _NavDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        selected: selected == 0,
        onTap: () => context.go('/'),
      ),
      _NavDestination(
        label: 'Orders',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        selected: selected == 1,
        onTap: () => context.go('/orders'),
      ),
      _NavDestination(
        label: 'Friends',
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        selected: selected == 2,
        badge: incomingRequests,
        onTap: () => context.go('/social'),
      ),
      _NavDestination(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        selected: selected == 3,
        onTap: () => context.go('/profile'),
      ),
    ];

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, 0, BhookSpacing.screenPad, BhookSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: BhookSpacing.sm, vertical: BhookSpacing.sm),
        decoration: BoxDecoration(
          color: BhookColors.mustard,
          borderRadius: BorderRadius.circular(BhookRadius.xl),
          border: Border.all(color: BhookColors.inkStrong),
          boxShadow: const [
            BoxShadow(
                color: BhookColors.inkStrong,
                offset: Offset(4, 4),
                blurRadius: 0),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: destinations,
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BhookColors.action : BhookColors.inkMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(BhookRadius.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? BhookColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(BhookRadius.lg),
          border: selected
              ? Border.all(color: BhookColors.inkStrong, width: 0.8)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? BhookColors.action : BhookColors.card,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? selectedIcon : icon,
                  color: selected ? Colors.white : BhookColors.inkMuted,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
