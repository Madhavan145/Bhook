import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/vendors/my_vendors_screen.dart';
import 'features/vendors/accept_invitation_screen.dart';
import 'features/vendors/apply_vendor_screen.dart';
import 'features/vendors/vendor_workspace.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authSessionProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = auth.asData?.value;
      final loggedIn = session?.isAuthenticated ?? false;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const MyVendorsScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/apply', builder: (_, __) => const ApplyVendorScreen()),
      GoRoute(
          path: '/accept-invitation',
          builder: (_, __) => const AcceptInvitationScreen()),
      GoRoute(
        path: '/vendors/:vendorId',
        builder: (_, state) =>
            VendorWorkspaceScreen(vendorId: state.pathParameters['vendorId']!),
      ),
      GoRoute(
        path: '/vendors/:vendorId/orders',
        builder: (_, state) =>
            VendorWorkspaceScreen(vendorId: state.pathParameters['vendorId']!, initialIndex: 1),
      ),
      GoRoute(
        path: '/vendors/:vendorId/menu',
        builder: (_, state) =>
            VendorWorkspaceScreen(vendorId: state.pathParameters['vendorId']!, initialIndex: 2),
      ),
    ],
  );
});

class BhookVendorApp extends ConsumerWidget {
  const BhookVendorApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Bhook Vendor',
      debugShowCheckedModeBanner: false,
      theme: buildBhookTheme(),
      routerConfig: ref.watch(_routerProvider),
    );
  }
}
