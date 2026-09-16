import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'app_config.dart';
import 'token_storage.dart';

final appConfigProvider = Provider<AppConfig>((_) => AppConfig.local);
final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage(const FlutterSecureStorage()));

ApiClient _c(Ref ref, String base) => ApiClient(
      base,
      ref.watch(tokenStorageProvider),
      identityBaseUrl: ref.watch(appConfigProvider).identityBaseUrl,
    );

final identityClientProvider = Provider<ApiClient>((ref) => _c(ref, ref.watch(appConfigProvider).identityBaseUrl));
final deliveryClientProvider = Provider<ApiClient>((ref) => _c(ref, ref.watch(appConfigProvider).deliveryBaseUrl));
final trackingClientProvider = Provider<ApiClient>((ref) => _c(ref, ref.watch(appConfigProvider).trackingBaseUrl));
final campusClientProvider = Provider<ApiClient>((ref) => _c(ref, ref.watch(appConfigProvider).campusBaseUrl));

final authSessionProvider = FutureProvider<AuthSession>((ref) async {
  final s = ref.watch(tokenStorageProvider);
  final t = await s.readAccess();
  final u = await s.readUserId();
  if (t == null || u == null) return const AuthSession.anonymous();
  return AuthSession(userId: u, accessToken: t);
});

class AuthSession {
  const AuthSession({required this.userId, required this.accessToken});
  const AuthSession.anonymous() : userId = null, accessToken = null;
  final String? userId;
  final String? accessToken;
  bool get isAuthenticated => userId != null && accessToken != null;
}
