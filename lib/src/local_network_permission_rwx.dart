import 'dart:io';

import 'package:flutter/services.dart';

import 'local_network_status_rwx.dart';

/// Check and request the iOS Local Network permission.
///
/// On iOS 14+, apps must be granted Local Network access before they can
/// discover or communicate with devices on the local network via UDP
/// broadcast, mDNS/Bonjour, or multicast.
///
/// Apple provides no direct API to query the permission state. This plugin
/// uses an [NWBrowser](https://developer.apple.com/documentation/network/nwbrowser)
/// for a Bonjour service type to trigger the system dialog and detect the
/// result via debounced state transitions.
///
/// ## Setup
///
/// Add these entries to your `ios/Runner/Info.plist`:
///
/// ```xml
/// <key>NSLocalNetworkUsageDescription</key>
/// <string>This app needs access to your local network to discover devices.</string>
/// <key>NSBonjourServices</key>
/// <array>
///   <string>_your_service._tcp</string>
/// </array>
/// ```
///
/// The Bonjour service type passed to [requestPermission] **must** appear in
/// the `NSBonjourServices` array, otherwise the NWBrowser will silently fail.
///
/// ## Non-iOS platforms
///
/// All methods return [LocalNetworkStatusRWX.granted] on Android, macOS, Windows,
/// Linux, and web — the concept does not exist there.
class LocalNetworkPermissionRWX {
  static const MethodChannel _channel =
      MethodChannel('local_network_rwx');

  LocalNetworkPermissionRWX._();

  /// Triggers the iOS Local Network permission dialog (if not yet shown) and
  /// returns the user's decision.
  ///
  /// [serviceType] is the Bonjour service type to browse for (e.g.
  /// `_myapp._tcp`). It must be declared in `NSBonjourServices` in Info.plist.
  ///
  /// [timeoutSeconds] is the maximum time (in seconds) to wait for the user
  /// to respond to the system dialog. Defaults to 30. After this timeout the
  /// method returns [LocalNetworkStatusRWX.granted] (fail-open) to avoid
  /// blocking the app indefinitely.
  ///
  /// If permission was already granted or denied in a prior session, iOS will
  /// not show the dialog again — the method simply detects the current state.
  ///
  /// On non-iOS platforms this always returns [LocalNetworkStatusRWX.granted].
  static Future<LocalNetworkStatusRWX> requestPermission({
    required String serviceType,
    int timeoutSeconds = 30,
  }) async {
    if (!Platform.isIOS) return LocalNetworkStatusRWX.granted;

    try {
      final result = await _channel.invokeMethod<String>(
        'requestPermission',
        <String, dynamic>{
          'serviceType': serviceType,
          'timeoutSeconds': timeoutSeconds,
        },
      );
      switch (result) {
        case 'granted':
          return LocalNetworkStatusRWX.granted;
        case 'denied':
          return LocalNetworkStatusRWX.denied;
        default:
          return LocalNetworkStatusRWX.unknown;
      }
    } on PlatformException {
      return LocalNetworkStatusRWX.unknown;
    } on MissingPluginException {
      return LocalNetworkStatusRWX.unknown;
    }
  }

  /// Sends a single UDP broadcast packet to the subnet broadcast address.
  ///
  /// On iOS this can "prime" the network stack so that the system dialog
  /// appears more reliably when [requestPermission] is called immediately
  /// after. This is optional — [requestPermission] works on its own in most
  /// cases, but some iOS versions (14.x, 15.x) are more reliable with a
  /// UDP primer first.
  ///
  /// [broadcastAddress] should be the directed broadcast address for the
  /// current subnet (e.g. `192.168.1.255`). If null, this method is a no-op.
  ///
  /// On non-iOS platforms this is a no-op.
  static Future<void> sendUdpPrimer({String? broadcastAddress}) async {
    if (!Platform.isIOS || broadcastAddress == null) return;

    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      final port = 49152 + (DateTime.now().millisecondsSinceEpoch % 16383);
      socket.send([0], InternetAddress(broadcastAddress), port);
      socket.close();
    } catch (_) {
      // Best-effort — failure here is not critical.
    }
  }

  /// Returns the directed broadcast address (e.g. `192.168.1.255`) for the
  /// first usable local IPv4 interface, or null if none is found.
  ///
  /// Filters out loopback, link-local (169.254.x.x), and carrier-grade NAT
  /// (100.64-127.x.x) addresses.
  static Future<String?> getBroadcastAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final first = int.tryParse(parts[0]) ?? 0;
          final second = int.tryParse(parts[1]) ?? 0;
          // Skip loopback
          if (first == 127) continue;
          // Skip link-local
          if (first == 169 && second == 254) continue;
          // Skip carrier-grade NAT
          if (first == 100 && second >= 64 && second <= 127) continue;
          // Build broadcast: replace last octet with 255
          return '${parts[0]}.${parts[1]}.${parts[2]}.255';
        }
      }
    } catch (_) {}
    return null;
  }

  /// Opens the iOS Settings app at the current app's settings page.
  ///
  /// Users who denied the permission must enable it manually under
  /// Settings > [App Name] > Local Network.
  static Future<void> openSettings() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } catch (_) {}
  }
}
