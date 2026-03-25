## 1.0.6

* README: green play buttons, video descriptions, section heading update.

## 1.0.5

* README: play button thumbnails for demo videos, spacing fixes.

## 1.0.4

* Add "In action" section with demo videos (green/red permission paths).
* Add iOS version notes about app restart after Settings toggle.
* Link to Gemma App on App Store.

## 1.0.3

* Rename source files to *_rwx.dart for consistency.
* README formatting fix.

## 1.0.2

* Add entitlement disclaimer to example app UI.

## 1.0.1

* Fix screenshot rendering on pub.dev (use raw GitHub URL).

## 1.0.0

* Initial release.
* `requestPermission()` — trigger and detect the iOS Local Network permission dialog via NWBrowser.
* `sendUdpPrimer()` — optional UDP broadcast to improve dialog reliability on older iOS versions.
* `getBroadcastAddress()` — utility to discover the local subnet broadcast address.
* `openSettings()` — open the iOS Settings page for the current app.
