import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _access = 'bhook.delivery.access_token';
  static const _refresh = 'bhook.delivery.refresh_token';
  static const _userId = 'bhook.delivery.user_id';

  Future<void> save({required String accessToken, required String refreshToken, required String userId}) async {
    await _storage.write(key: _access, value: accessToken);
    await _storage.write(key: _refresh, value: refreshToken);
    await _storage.write(key: _userId, value: userId);
  }

  Future<String?> readAccess() => _storage.read(key: _access);
  Future<String?> readRefresh() => _storage.read(key: _refresh);
  Future<String?> readUserId() => _storage.read(key: _userId);

  Future<void> clear() async {
    await _storage.delete(key: _access);
    await _storage.delete(key: _refresh);
    await _storage.delete(key: _userId);
  }
}
