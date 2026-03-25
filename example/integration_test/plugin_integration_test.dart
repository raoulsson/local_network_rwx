import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:local_network_rwx/local_network_rwx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('requestPermission returns a LocalNetworkStatus',
      (WidgetTester tester) async {
    final status = await LocalNetworkPermission.requestPermission(
      serviceType: '_myapp._tcp',
    );
    expect(LocalNetworkStatus.values.contains(status), true);
  });
}
