import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bhook_delivery/src/app.dart';
import 'package:bhook_delivery/src/core/providers.dart';
import 'package:bhook_delivery/src/core/token_storage.dart';

class _EmptyTokenStorage extends TokenStorage {
  _EmptyTokenStorage() : super(const FlutterSecureStorage());

  @override
  Future<String?> readAccess() async => null;

  @override
  Future<String?> readUserId() async => null;
}

void main() {
  testWidgets('delivery app opens the partner sign-in screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(_EmptyTokenStorage()),
        ],
        child: const BhookDeliveryApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delivery partner sign in'), findsOneWidget);
  });
}
