class AppConfig {
  const AppConfig({
    required this.identityBaseUrl,
    required this.deliveryBaseUrl,
    required this.trackingBaseUrl,
    required this.campusBaseUrl,
  });

  final String identityBaseUrl;
  final String deliveryBaseUrl;
  final String trackingBaseUrl;
  final String campusBaseUrl;

  static const AppConfig local = AppConfig(
    identityBaseUrl: '${kIsWeb ? 'http://localhost:8081' : 'http://10.0.2.2:8081'}',
    deliveryBaseUrl: '${kIsWeb ? 'http://localhost:8087' : 'http://10.0.2.2:8087'}',
    trackingBaseUrl: '${kIsWeb ? 'http://localhost:8091' : 'http://10.0.2.2:8091'}',
    campusBaseUrl: '${kIsWeb ? 'http://localhost:8083' : 'http://10.0.2.2:8083'}',
  );
}
