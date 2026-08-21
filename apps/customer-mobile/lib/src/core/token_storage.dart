import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _accessKey = 'bhook.access_token';
  static const _refreshKey = 'bhook.refresh_token';
  static const _userIdKey = 'bhook.user_id';
  static const _rolesKey = 'bhook.roles';

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required List<String> roles,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _rolesKey, value: roles.join(','));
  }

  Future<String?> readAccess() => _storage.read(key: _accessKey);
  Future<String?> readRefresh() => _storage.read(key: _refreshKey);
  Future<String?> readUserId() => _storage.read(key: _userIdKey);
  Future<List<String>> readRoles() async {
    final value = await _storage.read(key: _rolesKey);
    if (value == null || value.isEmpty) return const [];
    return value.split(',').where((role) => role.isNotEmpty).toList();
  }
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _rolesKey);
  }
}
