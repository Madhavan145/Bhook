import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig({
    required this.identityBaseUrl,
    required this.customerBaseUrl,
    required this.campusBaseUrl,
    required this.catalogBaseUrl,
    required this.orderBaseUrl,
    required this.paymentBaseUrl,
    required this.trackingBaseUrl,
    required this.socialBaseUrl,
    required this.uploadBaseUrl,
    required this.operationsBaseUrl,
    required this.friendLinkBaseUrl,
  });

  final String identityBaseUrl;
  final String customerBaseUrl;
  final String campusBaseUrl;
  final String catalogBaseUrl;
  final String orderBaseUrl;
  final String paymentBaseUrl;
  final String trackingBaseUrl;
  final String socialBaseUrl;
  final String uploadBaseUrl;
  final String operationsBaseUrl;
  final String friendLinkBaseUrl;

  static const AppConfig local = AppConfig(
    identityBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8081',
    customerBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8082',
    campusBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8083',
    catalogBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8084',
    orderBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8085',
    paymentBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8086',
    trackingBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8091',
    socialBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8093',
    uploadBaseUrl: '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8092',
    operationsBaseUrl:
        '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:8089',
    friendLinkBaseUrl: kIsWeb ? 'http://localhost:5300' : 'https://bhook.app',
  );

  /// Public object-storage base for publicly readable images (catalog, logos).
  static const String storageImageBaseUrl =
      '${kIsWeb ? 'http://localhost' : 'http://10.0.2.2'}:9000/bhook';

  /// Builds a viewable URL for a stored object key, or null when absent.
  static String? imageUrl(String? objectKey) =>
      (objectKey == null || objectKey.isEmpty)
          ? null
          : '$storageImageBaseUrl/$objectKey';
}
