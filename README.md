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

> [!CAUTION]
> **Multicast Networking Entitlement Required**
>
> Your app **must** have the
> [`com.apple.developer.networking.multicast`](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.multicast)
> entitlement before any of this will work. Apple does not grant it
> automatically — you must request it at:
>
> **https://developer.apple.com/contact/request/networking-multicast**
>
> Without this entitlement, NWBrowser and Bonjour discovery will silently
> fail and the Local Network permission dialog will never appear.

> [!WARNING]
> **Testing — Use TestFlight, Not Xcode**
>
> When an app is launched from Xcode or the IDE, iOS **automatically grants**
> Local Network permission without showing the system dialog. You will not
> see the permission prompt and `requestPermission()` will always return
> `granted`.
>
> To test the actual permission flow (dialog appearance, deny handling,
> Settings toggle), you **must** install the app via TestFlight or
> ad-hoc distribution.

> [!TIP]
> **How to verify the entitlement is active**
>
> Go to **Settings → [Your App]** on the device. If the Multicast Networking
> entitlement is correctly provisioned, you will see a **"Local Network"**
> toggle row. If that row is missing, your app does not have the entitlement
> yet — request it from Apple before proceeding.
>
>
>
> <br>
>
> <img src="https://raw.githubusercontent.com/raoulsson/local_network_rwx/master/resources/ios-app-settings.png" alt="iOS Settings showing the Local Network toggle" width="60%">

## Setup

### 1. Add the dependency

```yaml
dependencies:
  local_network_rwx: ^1.0.0
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

Both entries are **required**:
- `NSLocalNetworkUsageDescription` — the user-facing explanation shown in the
  system permission dialog. Without it, iOS will not prompt the user at all.
- `NSBonjourServices` — the Bonjour service type you pass to
  `requestPermission()` **must** appear here, otherwise NWBrowser silently fails.

## Usage

```dart
import 'package:local_network_rwx/local_network_rwx.dart';

// Optional: send a UDP broadcast primer for older iOS versions (14.x, 15.x).
final broadcast = await LocalNetworkPermissionRWX.getBroadcastAddress();
await LocalNetworkPermissionRWX.sendUdpPrimer(broadcastAddress: broadcast);

// Check / request permission. Shows the system dialog on first call.
final status = await LocalNetworkPermissionRWX.requestPermission(
  serviceType: '_yourservice._tcp',
);

switch (status) {
  case LocalNetworkStatusRWX.granted:
    // Proceed with device discovery.
    break;
  case LocalNetworkStatusRWX.denied:
    // Show a dialog explaining how to enable in Settings.
    await LocalNetworkPermissionRWX.openSettings();
    break;
  case LocalNetworkStatusRWX.unknown:
    // Could not determine — try networking anyway (fail-open).
    break;
}
```

## API

### `LocalNetworkPermissionRWX.requestPermission()`

Triggers the iOS Local Network permission dialog (if not yet shown) and returns
the user's decision as a `LocalNetworkStatusRWX`.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `serviceType` | `String` | *required* | Bonjour service type (e.g. `_myapp._tcp`) |
| `timeoutSeconds` | `int` | `30` | Max seconds to wait for user response |

### `LocalNetworkPermissionRWX.sendUdpPrimer()`

Sends a single UDP broadcast packet to prime the iOS network stack. Optional
but improves reliability on some iOS versions.

### `LocalNetworkPermissionRWX.getBroadcastAddress()`

Returns the directed broadcast address (e.g. `192.168.1.255`) for the first
usable local IPv4 interface, or `null`.

### `LocalNetworkPermissionRWX.openSettings()`

Opens the iOS Settings app at the current app's settings page.

### `LocalNetworkStatusRWX`

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

> [!NOTE]
> **App restart after toggling Local Network in Settings**
>
> When the user changes the Local Network toggle in **Settings → [Your App]**,
> iOS automatically kills and restarts your app. This means you do not need to
> handle the permission change at runtime — the app will relaunch with the
> updated permission state.
>
> If you use `openSettings()` to send the user to Settings, avoid calling
> `exit()` beforehand. Keeping the app alive lets iOS show the **"Back to
> [Your App]"** breadcrumb in the top-left of the status bar, giving the user
> a clear way to navigate back. Once they toggle the permission, iOS will
> kill and restart the app automatically.

## "In Action" on an App that relies on this library

<a href="https://gemma-design.ch"><img src="https://raw.githubusercontent.com/raoulsson/local_network_rwx/master/resources/gemma-connect-device-pre-screen.jpeg" alt="Gemma App" width="30%" align="right"></a>

This library is used in the [Gemma App](https://apps.apple.com/app/gemma-app/id6739215260) by [Gemma Design](https://gemma-design.ch) — a lighting control app that discovers and communicates with smart furniture via the local network.

<div style="clear: both;"></div>

**User grants permission (green path):** The user selects "Allow", then device search proceeds normally.

<a href="https://raw.githubusercontent.com/raoulsson/local_network_rwx/master/resources/user-says-yes-first.mp4" target="_blank">
  <img src="https://raw.githubusercontent.com/raoulsson/local_network_rwx/master/resources/play-btn-green.svg" alt="Download and watch — user grants permission" width="24%">
</a>

<br>

**User denies permission, then re-enables in Settings (red path):** The user doesn't grant permission, then is redirected to the app's Settings page. Permission takes effect on restart of the app.

<a href="https://raw.githubusercontent.com/raoulsson/local_network_rwx/master/resources/user-first-says-no.mp4" target="_blank">
  <img src="https://raw.githubusercontent.com/raoulsson/local_network_rwx/master/resources/play-btn-green.svg" alt="Download and watch — user denies then re-enables" width="24%">
</a>

## 📮 Support

- 📧 Email: hello@raoulsson.com
- 🐛 Issues: [GitHub Issues](https://github.com/raoulsson/local_network_rwx/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/raoulsson/local_network_rwx/discussions)

## 💚 Funding

- 🏅 https://github.com/sponsors/raoulsson
- 🪙 https://www.buymeacoffee.com/raoulsson

## License

BSD 3-Clause. See [LICENSE](LICENSE).

---

**Happy Networking! 🎉**
