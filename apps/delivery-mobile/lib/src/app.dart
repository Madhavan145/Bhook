import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/jobs/jobs_list_screen.dart';
import 'features/partner/partner_home_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = ref.read(authSessionProvider).asData?.value;
      final loggedIn = session?.isAuthenticated ?? false;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PartnerHomeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/jobs', builder: (_, __) => const JobsListScreen()),
    ],
  );
});

class BhookDeliveryApp extends ConsumerWidget {
  const BhookDeliveryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Bhook Delivery',
      debugShowCheckedModeBanner: false,
      theme: buildBhookTheme(),
      routerConfig: ref.watch(_routerProvider),
    );
  }
}
