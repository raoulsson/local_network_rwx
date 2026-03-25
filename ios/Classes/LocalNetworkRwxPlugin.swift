import Flutter
import UIKit
import Network

public class LocalNetworkRwxPlugin: NSObject, FlutterPlugin {
  /// Kept alive so iOS maintains the app's "local network active" state.
  /// Cancelling an NWBrowser can cause iOS to throttle subsequent UDP traffic
  /// even when permission is granted.  The browser is only replaced (old one
  /// cancelled) when a new permission check is requested.
  private var activeBrowser: NWBrowser?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "local_network_rwx",
      binaryMessenger: registrar.messenger()
    )
    let instance = LocalNetworkRwxPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermission":
      guard let args = call.arguments as? [String: Any],
            let serviceType = args["serviceType"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "serviceType is required", details: nil))
        return
      }
      let timeout = args["timeoutSeconds"] as? Int ?? 30
      checkLocalNetworkPermission(serviceType: serviceType, timeoutSeconds: timeout, result: result)
    case "openSettings":
      openSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - NWBrowser permission check

  /// Checks (and triggers) the iOS local network permission dialog.
  ///
  /// Starts an NWBrowser for the given Bonjour service type.
  /// This is the reliable way to force iOS to present the system permission
  /// dialog — a plain UDP broadcast alone does not reliably trigger it.
  ///
  /// State handling uses a last-state-wins debounce because iOS can fire
  /// transitions in either order (.ready → .failed or .failed → .ready)
  /// depending on whether the user just granted or revoked permission.
  ///
  /// Returns "granted", "denied", or "unknown" as a String via FlutterResult.
  private func checkLocalNetworkPermission(
    serviceType: String,
    timeoutSeconds: Int,
    result: @escaping FlutterResult
  ) {
    // Cancel any previous browser before starting a new one.
    activeBrowser?.cancel()
    activeBrowser = nil

    var resultCalled = false
    let safeResult: (String) -> Void = { [weak self] status in
      guard !resultCalled else { return }
      resultCalled = true
      // Cancel the browser once we have the answer — iOS has already
      // recorded the user's decision.  Keeping it alive was blocking
      // subsequent UDP broadcasts from Flutter's RawDatagramSocket.
      self?.activeBrowser?.cancel()
      self?.activeBrowser = nil
      result(status)
    }

    let browser = NWBrowser(for: .bonjour(type: serviceType, domain: "local."), using: .tcp)
    activeBrowser = browser

    // Last-state-wins debounce with asymmetric timing:
    //
    // .ready gets a 1.5 s debounce — on first install, .ready fires
    // immediately when the browser starts (BEFORE the user taps
    // Allow/Don't Allow).  The 1.5 s window gives the user time to tap
    // "Don't Allow", which fires .failed(PolicyDenied) and cancels the
    // scheduled .ready result.
    //
    // .failed(PolicyDenied) gets a 1 s debounce — shorter, but still
    // allows .ready to override it in the re-enable case (Settings toggle
    // off → on, where iOS fires .failed → .ready).
    //
    // Already-granted (no dialog): .ready fires, resolves after 1.5 s.
    // User taps Allow: .ready fires, stays ready, resolves after 1.5 s.
    // User taps Don't Allow: .ready fires, then .failed cancels it,
    //   resolves "denied" after 1 s.
    // Re-enable in Settings: .failed fires, then .ready cancels it,
    //   resolves "granted" after 1.5 s.
    var scheduledWork: DispatchWorkItem?

    browser.stateUpdateHandler = { state in
      switch state {
      case .ready:
        scheduledWork?.cancel()
        let work = DispatchWorkItem { safeResult("granted") }
        scheduledWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)

      case .failed(let error), .waiting(let error):
        if case .dns(let code) = error, code == Int32(-65570) {
          // kDNSServiceErr_PolicyDenied — user denied local network access.
          scheduledWork?.cancel()
          let work = DispatchWorkItem { safeResult("denied") }
          scheduledWork = work
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
        } else {
          // Any other error (e.g. no WiFi) — don't block the app.
          scheduledWork?.cancel()
          safeResult("unknown")
        }

      default:
        break
      }
    }

    browser.start(queue: .main)

    // Safety timeout: give the user up to N seconds to respond to the dialog.
    DispatchQueue.main.asyncAfter(deadline: .now() + Double(timeoutSeconds)) {
      safeResult("granted")
    }
  }

  // MARK: - Open Settings

  private func openSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(FlutterError(code: "UNAVAILABLE", message: "Cannot open settings", details: nil))
      return
    }
    UIApplication.shared.open(url, options: [:]) { success in
      result(success)
    }
  }
}
