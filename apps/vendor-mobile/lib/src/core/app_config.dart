import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.identityBaseUrl,
    required this.catalogBaseUrl,
    required this.campusBaseUrl,
    required this.orderBaseUrl,
    required this.uploadBaseUrl,
  });

  final String identityBaseUrl;
  final String catalogBaseUrl;
  final String campusBaseUrl;
  final String orderBaseUrl;
  final String uploadBaseUrl;

  static const AppConfig local = AppConfig(
    identityBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8081',
    catalogBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8084',
    campusBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8083',
    orderBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8085',
    uploadBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8092',
  );

  /// Public object-storage base for publicly readable images (catalog, logos).
  static const String storageImageBaseUrl =
      '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:9000/bhook';

  /// Builds a viewable URL for a stored object key, or null when absent.
  static String? imageUrl(String? objectKey) =>
      (objectKey == null || objectKey.isEmpty) ? null : '$storageImageBaseUrl/$objectKey';
}
