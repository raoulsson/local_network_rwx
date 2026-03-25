# Local Network RWX

Check and request the **iOS Local Network permission** from Flutter.

On iOS 14+, apps must be granted Local Network access before they can discover
or communicate with devices via UDP broadcast, mDNS/Bonjour, or multicast.
Apple provides no direct API to query the permission state. The standard
[`permission_handler`](https://pub.dev/packages/permission_handler) package
does not support this permission.

This plugin uses
[NWBrowser](https://developer.apple.com/documentation/network/nwbrowser) with
debounced state handling to trigger the system dialog and reliably detect
whether the user granted or denied access.

On non-iOS platforms all methods return `granted` / no-op.

## Setup

### 1. Add the dependency

```yaml
dependencies:
  local_network_rwx: ^0.1.0
```

### 2. Configure Info.plist

Add these entries to `ios/Runner/Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs local network access to discover devices on your Wi-Fi network.</string>
<key>NSBonjourServices</key>
<array>
    <string>_yourservice._tcp</string>
</array>
```

The Bonjour service type you pass to `requestPermission()` **must** appear in
the `NSBonjourServices` array, otherwise the NWBrowser will silently fail.

## Usage

```dart
import 'package:local_network_rwx/local_network_rwx.dart';

// Optional: send a UDP broadcast primer for older iOS versions (14.x, 15.x).
final broadcast = await LocalNetworkPermission.getBroadcastAddress();
await LocalNetworkPermission.sendUdpPrimer(broadcastAddress: broadcast);

// Check / request permission. Shows the system dialog on first call.
final status = await LocalNetworkPermission.requestPermission(
  serviceType: '_yourservice._tcp',
);

switch (status) {
  case LocalNetworkStatus.granted:
    // Proceed with device discovery.
    break;
  case LocalNetworkStatus.denied:
    // Show a dialog explaining how to enable in Settings.
    await LocalNetworkPermission.openSettings();
    break;
  case LocalNetworkStatus.unknown:
    // Could not determine — try networking anyway (fail-open).
    break;
}
```

## API

### `LocalNetworkPermission.requestPermission()`

Triggers the iOS Local Network permission dialog (if not yet shown) and returns
the user's decision as a `LocalNetworkStatus`.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `serviceType` | `String` | *required* | Bonjour service type (e.g. `_myapp._tcp`) |
| `timeoutSeconds` | `int` | `30` | Max seconds to wait for user response |

### `LocalNetworkPermission.sendUdpPrimer()`

Sends a single UDP broadcast packet to prime the iOS network stack. Optional
but improves reliability on some iOS versions.

### `LocalNetworkPermission.getBroadcastAddress()`

Returns the directed broadcast address (e.g. `192.168.1.255`) for the first
usable local IPv4 interface, or `null`.

### `LocalNetworkPermission.openSettings()`

Opens the iOS Settings app at the current app's settings page.

### `LocalNetworkStatus`

| Value | Meaning |
|---|---|
| `granted` | Permission granted (or non-iOS platform) |
| `denied` | Permission denied (`kDNSServiceErr_PolicyDenied`) |
| `unknown` | Could not determine (no Wi-Fi, timeout, error) |

## How it works

1. An `NWBrowser` is started for the given Bonjour service type
2. iOS presents the "Allow [App] to find devices on your local network?" dialog
   (only on first invocation — subsequent calls detect the stored decision)
3. The browser's `stateUpdateHandler` fires state transitions:
   - `.ready` → permission granted (1.2s debounce)
   - `.failed`/`.waiting` with `kDNSServiceErr_PolicyDenied` → denied (1.0s debounce)
   - Other errors → unknown (fail-open, immediate)
4. Asymmetric debounce timing handles iOS firing states in either order

The debounce is critical because iOS always fires `.ready` first — even before
the user has tapped Allow or Don't Allow. The 1.2s window gives time for a
subsequent `.failed(PolicyDenied)` to cancel the premature `.ready`.

## iOS version notes

- **iOS 14-15**: UDP primer recommended for reliable dialog triggering
- **iOS 17.x**: Re-enabling permission in Settings may require device restart
- **iOS 18**: Known Apple bug where in-memory and persistent state can desync
  ([FB14321888](https://developer.apple.com/bug-reporting/))

## License

BSD 3-Clause. See [LICENSE](LICENSE).
