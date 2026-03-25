/// Result of a local network permission check.
enum LocalNetworkStatus {
  /// Permission was granted (or the platform has no such restriction).
  granted,

  /// Permission was denied by the user (iOS kDNSServiceErr_PolicyDenied).
  denied,

  /// The check could not determine the status (e.g. no Wi-Fi, timeout).
  /// Callers should treat this as "possibly granted" and try networking anyway.
  unknown,
}
