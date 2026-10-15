import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

final authSessionProvider = FutureProvider<AuthSession>((ref) async {
  ref.watch(sessionMessageProvider); // re-evaluate session when a refresh failure clears tokens
  final storage = ref.watch(tokenStorageProvider);
  final token = await storage.readAccess();
  final userId = await storage.readUserId();
  final roles = await storage.readRoles();
  if (token == null || userId == null || !roles.contains('CUSTOMER')) {
    return const AuthSession.anonymous();
  }
  return AuthSession(userId: userId, accessToken: token, roles: roles);
});

class AuthSession {
  const AuthSession({required this.userId, required this.accessToken, required this.roles});
  const AuthSession.anonymous()
      : userId = null,
        accessToken = null,
        roles = const [];

  final String? userId;
  final String? accessToken;
  final List<String> roles;

  bool get isAuthenticated => userId != null && accessToken != null;
}
