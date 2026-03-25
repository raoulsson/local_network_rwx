# Local Network RWX — Example

Demonstrates how to use the Local Network RWX plugin.

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
> When launched from Xcode/IDE, iOS automatically grants Local Network
> permission without showing the dialog. To test the real permission flow,
> install via TestFlight or ad-hoc distribution.
