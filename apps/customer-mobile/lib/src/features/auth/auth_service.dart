import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class AuthService {
  AuthService(this._ref);

  final Ref _ref;

  Future<EmailChallenge> startSignup(String email) async {
    final client = _ref.read(identityClientProvider);
    final res = await client.dio.post(
      '/api/v1/auth/signup/email-challenge',
      data: {'email': email},
    );
    final data = res.data as Map<String, dynamic>;
    return EmailChallenge(
      challengeId: data['challengeId'] as String,
      email: data['email'] as String,
      expiresInSeconds: (data['expiresInSeconds'] as num).toInt(),
      matches: ((data['campusMatches'] ?? []) as List)
          .map((m) => CampusMatch.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<TokenBundle> completeSignup({
    required String challengeId,
    required String otp,
    required String password,
    required String displayName,
    required String phoneE164,
    String? campusId,
  }) async {
    final client = _ref.read(identityClientProvider);
    final body = <String, dynamic>{
      'challengeId': challengeId,
      'otp': otp,
      'password': password,
      'displayName': displayName,
      'phoneE164': phoneE164.replaceAll(RegExp(r'\s+'), ''),
    };
    if (campusId != null) body['campusId'] = campusId;
    final res =
        await client.dio.post('/api/v1/auth/signup/complete', data: body);
    return _persistTokens(res.data as Map<String, dynamic>);
  }

  Future<TokenBundle> login(String email, String password) async {
    final client = _ref.read(identityClientProvider);
    final res = await client.dio.post(
      '/api/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    return _persistTokens(res.data as Map<String, dynamic>);
  }

  Future<PasswordResetChallenge> requestPasswordReset(String email) async {
    final res = await _ref.read(identityClientProvider).dio.post(
      '/api/v1/auth/password/reset/otp-request',
      data: {'email': email},
    );
    final data = res.data as Map<String, dynamic>;
    return PasswordResetChallenge(
      challengeId: data['challengeId'] as String,
      expiresInSeconds: (data['expiresInSeconds'] as num?)?.toInt() ?? 300,
    );
  }

  Future<void> confirmPasswordReset({
    required String challengeId,
    required String otp,
    required String newPassword,
  }) async {
    await _ref.read(identityClientProvider).dio.post(
      '/api/v1/auth/password/reset/otp-confirm',
      data: {
        'challengeId': challengeId,
        'otp': otp,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> logout() async {
    final client = _ref.read(identityClientProvider);
    try {
      await client.dio.post('/api/v1/auth/logout');
    } catch (_) {}
    await _ref.read(tokenStorageProvider).clear();
  }

  Future<TokenBundle> _persistTokens(Map<String, dynamic> data) async {
    final storage = _ref.read(tokenStorageProvider);
    final user = data['user'] as Map<String, dynamic>;
    final roles = ((user['roles'] as List?) ?? const [])
        .map((role) => role.toString())
        .toSet();
    if (!roles.contains('CUSTOMER')) {
      await storage.clear();
      throw UnsupportedError('This account is not a customer account.');
    }
    await storage.save(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: user['userId'] as String,
      roles: roles.toList(),
    );
    return TokenBundle(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      userId: user['userId'] as String,
      email: user['email'] as String,
      displayName: user['displayName'] as String? ?? '',
    );
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref));

class EmailChallenge {
  const EmailChallenge({
    required this.challengeId,
    required this.email,
    required this.expiresInSeconds,
    required this.matches,
  });
  final String challengeId;
  final String email;
  final int expiresInSeconds;
  final List<CampusMatch> matches;
}

class CampusMatch {
  const CampusMatch({
    required this.campusId,
    required this.campusName,
    required this.membershipType,
    required this.autoVerify,
  });
  final String campusId;
  final String campusName;
  final String membershipType;
  final bool autoVerify;

  factory CampusMatch.fromJson(Map<String, dynamic> json) => CampusMatch(
        campusId: json['campusId'] as String,
        campusName: json['campusName'] as String? ?? '',
        membershipType: json['membershipType'] as String? ?? '',
        autoVerify: json['autoVerify'] as bool? ?? false,
      );
}

class TokenBundle {
  const TokenBundle({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.email,
    required this.displayName,
  });
  final String accessToken;
  final String refreshToken;
  final String userId;
  final String email;
  final String displayName;
}

class PasswordResetChallenge {
  const PasswordResetChallenge({
    required this.challengeId,
    required this.expiresInSeconds,
  });

  final String challengeId;
  final int expiresInSeconds;
}
