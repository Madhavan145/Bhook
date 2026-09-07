import 'package:dio/dio.dart';

import 'token_storage.dart';

class ApiClient {
  ApiClient(this.baseUrl, this._storage, {required String identityBaseUrl, this.onSessionExpired})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Content-Type': 'application/json'},
        )),
        _identityBaseUrl = identityBaseUrl {
    _refresher ??= Dio(BaseOptions(baseUrl: _identityBaseUrl, headers: {'Content-Type': 'application/json'}));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.readAccess();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        final req = err.requestOptions;
        final isAuthPath = req.path.startsWith('/api/v1/auth/');
        if (err.response?.statusCode == 401 && !isAuthPath && req.extra['retriedAfterRefresh'] != true) {
          final ok = await _tryRefresh();
          if (ok) {
            final newToken = await _storage.readAccess();
            req.headers['Authorization'] = 'Bearer $newToken';
            req.extra['retriedAfterRefresh'] = true;
            try {
              final retried = await dio.fetch(req);
              return handler.resolve(retried);
            } catch (_) {
              return handler.next(err);
            }
          } else {
            await _storage.clear();
            onSessionExpired?.call();
          }
        }
        handler.next(err);
      },
    ));
  }

  final String baseUrl;
  final TokenStorage _storage;
  final String _identityBaseUrl;
  final Dio dio;
  final void Function()? onSessionExpired;

  static Dio? _refresher;
  static Future<bool>? _inflight;

  Future<bool> _tryRefresh() async {
    _inflight ??= _doRefresh();
    try { return await _inflight!; } finally { _inflight = null; }
  }

  Future<bool> _doRefresh() async {
    final refresh = await _storage.readRefresh();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _refresher!.post('/api/v1/auth/refresh', data: {'refreshToken': refresh});
      final data = res.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      await _storage.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: user['userId'] as String,
      );
      return true;
    } catch (_) { return false; }
  }
}
