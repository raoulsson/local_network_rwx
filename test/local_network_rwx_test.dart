import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_network_rwx/local_network_rwx.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('local_network_rwx');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'requestPermission') {
        return 'granted';
      }
      if (call.method == 'openSettings') {
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('LocalNetworkStatusRWX enum has expected values', () {
    expect(LocalNetworkStatusRWX.values.length, 3);
    expect(LocalNetworkStatusRWX.granted.name, 'granted');
    expect(LocalNetworkStatusRWX.denied.name, 'denied');
    expect(LocalNetworkStatusRWX.unknown.name, 'unknown');
  });

  test('getBroadcastAddress returns a String or null', () async {
    final address = await LocalNetworkPermissionRWX.getBroadcastAddress();
    // On test host (macOS/Linux) this should find a local interface.
    // On CI it might be null — both are valid.
    if (address != null) {
      expect(address, matches(RegExp(r'^\d+\.\d+\.\d+\.255$')));
    }
  });
}
