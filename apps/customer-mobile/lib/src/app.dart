import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/ui/navigation.dart';
import 'features/auth/auth_service.dart';
import 'features/auth/auth_state.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/signup_email_screen.dart';
import 'features/auth/screens/signup_otp_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/cart/cart_screen.dart';
import 'features/checkout/checkout_screen.dart';
import 'features/home/home_screen.dart';
import 'features/orders/order_detail_screen.dart';
import 'features/orders/orders_list_screen.dart';
import 'features/tracking/order_tracking_screen.dart';
import 'features/social/social_screen.dart';
import 'features/social/befriend_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/support/support_screen.dart';
import 'features/vendors/vendor_detail_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authSessionProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = auth.asData?.value;
      final loggedIn = session?.isAuthenticated ?? false;
      final loggingIn = state.matchedLocation == '/login' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/signup/otp';
      if (!loggedIn && !loggingIn) {
        final returnTo = Uri.encodeComponent(state.uri.toString());
        return '/login?returnTo=$returnTo';
      }
      if (loggedIn && loggingIn)
        return state.uri.queryParameters['returnTo'] ?? '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, state) =>
            LoginScreen(returnTo: state.uri.queryParameters['returnTo']),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(path: '/signup', builder: (_, __) => const SignupEmailScreen()),
      GoRoute(
        path: '/signup/otp',
        builder: (_, state) =>
            SignupOtpScreen(challenge: state.extra as EmailChallenge),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            BhookAppShell(child: child, location: state.uri.path),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/vendors/:vendorId',
            builder: (_, state) => VendorDetailScreen(
              vendorId: state.pathParameters['vendorId']!,
              initialCategory: state.uri.queryParameters['category'],
              initialItem: state.uri.queryParameters['itemId'],
            ),
          ),
          GoRoute(
            path: '/vendors/:vendorId/cart',
            builder: (_, state) =>
                CartScreen(vendorId: state.pathParameters['vendorId']!),
          ),
          GoRoute(
            path: '/vendors/:vendorId/checkout',
            builder: (_, state) =>
                CheckoutScreen(vendorId: state.pathParameters['vendorId']!),
          ),
          GoRoute(
              path: '/orders', builder: (_, __) => const OrdersListScreen()),
          GoRoute(path: '/social', builder: (_, __) => const SocialScreen()),
          GoRoute(
            path: '/befriend/:friendCode',
            builder: (_, state) =>
                BefriendScreen(friendCode: state.pathParameters['friendCode']!),
          ),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
          GoRoute(
            path: '/orders/:orderId',
            builder: (_, state) =>
                OrderDetailScreen(orderId: state.pathParameters['orderId']!),
          ),
          GoRoute(
            path: '/orders/:orderId/track',
            builder: (_, state) =>
                OrderTrackingScreen(orderId: state.pathParameters['orderId']!),
          ),
        ],
      ),
    ],
  );
});

class BhookCustomerApp extends ConsumerWidget {
  const BhookCustomerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      title: 'Bhook',
      debugShowCheckedModeBanner: false,
      theme: buildBhookTheme(),
      routerConfig: router,
    );
  }
}
