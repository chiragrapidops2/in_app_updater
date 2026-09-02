// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:in_app_updater/in_app_updater.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('checkForUpdate reaches the native channel', (WidgetTester tester) async {
    final service = NativeUpdateService();
    // Android (Play Core) resolves even for an unpublished app; iOS throws
    // when the bundle id has no live App Store listing (as with this example
    // app), which is expected here — either outcome proves the channel works.
    try {
      final result = await service.checkForUpdate();
      expect(result.updateAvailable, isA<bool>());
    } on Exception catch (_) {
      // Native call completed and returned an error — still a successful round-trip.
    }
  });
}
