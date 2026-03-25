import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:local_network_rwx/local_network_rwx.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('requestPermission returns a LocalNetworkStatusRWX',
      (WidgetTester tester) async {
    final status = await LocalNetworkPermissionRWX.requestPermission(
      serviceType: '_myapp._tcp',
    );
    expect(LocalNetworkStatusRWX.values.contains(status), true);
  });
}
