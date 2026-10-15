import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/ui/responsive.dart';
import '../dashboard/vendor_dashboard_screen.dart';
import '../menu/vendor_menu_screen.dart';
import '../orders/vendor_orders_screen.dart';
import 'vendor_providers.dart';
import 'vendor_settings_screen.dart';

class _Section {
  const _Section(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _sections = <_Section>[
  _Section('Dashboard', Icons.insights_outlined, Icons.insights),
  _Section('Orders', Icons.receipt_long_outlined, Icons.receipt_long),
  _Section('Menu', Icons.restaurant_menu_outlined, Icons.restaurant_menu),
  _Section('Settings', Icons.settings_outlined, Icons.settings),
];

/// Responsive vendor workspace. Uses a [NavigationRail] on wide screens
/// (tablet/desktop) and a bottom [NavigationBar] on compact phones, hosting the
/// same four section bodies in both layouts.
class VendorWorkspaceScreen extends ConsumerStatefulWidget {
  const VendorWorkspaceScreen(
      {super.key, required this.vendorId, this.initialIndex = 0});
  final String vendorId;
  final int initialIndex;

  @override
  ConsumerState<VendorWorkspaceScreen> createState() =>
      _VendorWorkspaceScreenState();
}

class _VendorWorkspaceScreenState extends ConsumerState<VendorWorkspaceScreen> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final vendor = ref.watch(vendorDetailProvider(widget.vendorId));
    final vendorName =
        vendor.asData?.value['displayName']?.toString() ?? 'Kitchen';
    final expanded = context.formFactor != FormFactor.compact;

    final body = _sectionBody(widget.vendorId, vendorName, _index);

    if (expanded) {
      return Scaffold(
        appBar: _appBar(context, vendorName, showLeading: false),
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                extended: context.isExpanded,
                minWidth: 92,
                minExtendedWidth: 220,
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType:
                    context.isExpanded ? null : NavigationRailLabelType.all,
                backgroundColor: BhookColors.card,
                indicatorColor: BhookColors.primarySoft,
                selectedIconTheme:
                    const IconThemeData(color: BhookColors.primary),
                selectedLabelTextStyle: const TextStyle(
                    color: BhookColors.primary, fontWeight: FontWeight.w700),
                unselectedIconTheme:
                    const IconThemeData(color: BhookColors.inkMuted),
                leading: Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 18),
                  child: IconButton.filledTonal(
                    tooltip: 'Switch kitchen',
                    icon: const Icon(Icons.grid_view_rounded, size: 20),
                    onPressed: () => context.go('/'),
                  ),
                ),
                destinations: [
                  for (final s in _sections)
                    NavigationRailDestination(
                      icon: Icon(s.icon),
                      selectedIcon: Icon(s.selectedIcon),
                      label: Text(s.label),
                    ),
                ],
              ),
              const VerticalDivider(
                  width: 1, thickness: 0.8, color: BhookColors.divider),
              Expanded(
                child: ColoredBox(
                  color: BhookColors.surface,
                  child: ContentBound(
                    maxWidth: 1440,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.isExpanded ? 20 : 8),
                      child: body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _appBar(context, vendorName, showLeading: true),
      body: SafeArea(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: BhookColors.card,
        indicatorColor: BhookColors.primarySoft,
        destinations: [
          for (final s in _sections)
            NavigationDestination(
              icon: Icon(s.icon),
              selectedIcon: Icon(s.selectedIcon, color: BhookColors.primary),
              label: s.label,
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, String vendorName,
      {required bool showLeading}) {
    return AppBar(
      leading: showLeading
          ? IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: 'Switch kitchen',
              onPressed: () => context.go('/'),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_sections[_index].label,
              style: Theme.of(context).textTheme.titleLarge),
          Text(vendorName,
              style: const TextStyle(
                  color: BhookColors.inkMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _sectionBody(String vendorId, String vendorName, int index) {
    switch (index) {
      case 0:
        return VendorDashboardScreen(
            vendorId: vendorId, vendorName: vendorName);
      case 1:
        return VendorOrdersBody(vendorId: vendorId);
      case 2:
        return VendorMenuBody(vendorId: vendorId);
      case 3:
      default:
        return VendorSettingsBody(vendorId: vendorId);
    }
  }
}
