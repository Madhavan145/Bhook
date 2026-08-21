import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'app_config.dart';
import 'token_storage.dart';

final appConfigProvider = Provider<AppConfig>((_) => AppConfig.local);

final tokenStorageProvider =
    Provider<TokenStorage>((_) => TokenStorage(const FlutterSecureStorage()));

/// Set with a user-facing message when a background token refresh fails,
/// so the login screen can explain why the user was signed out.
final sessionMessageProvider = StateProvider<String?>((ref) => null);

ApiClient _client(Ref ref, String base) => ApiClient(
      base,
      ref.watch(tokenStorageProvider),
      identityBaseUrl: ref.watch(appConfigProvider).identityBaseUrl,
      onSessionExpired: () => ref.read(sessionMessageProvider.notifier).state =
          'Your session has expired. Please sign in again.',
    );

final identityClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).identityBaseUrl));
final customerClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).customerBaseUrl));
final campusClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).campusBaseUrl));
final catalogClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).catalogBaseUrl));
final orderClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).orderBaseUrl));
final paymentClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).paymentBaseUrl));
final trackingClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).trackingBaseUrl));
final socialClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).socialBaseUrl));
final uploadClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).uploadBaseUrl));
final operationsClientProvider = Provider<ApiClient>(
    (ref) => _client(ref, ref.watch(appConfigProvider).operationsBaseUrl));
