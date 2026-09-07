import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Loads a single vendor's management view (`GET /api/v1/vendors/{id}/manage`).
/// Returns the raw JSON map so screens can read displayName, lifecycleStatus, etc.
final vendorDetailProvider =
    FutureProvider.family.autoDispose<Map<String, dynamic>, String>((ref, vendorId) async {
  final res = await ref.read(catalogClientProvider).dio.get('/api/v1/vendors/$vendorId/manage');
  return (res.data as Map<String, dynamic>);
});
