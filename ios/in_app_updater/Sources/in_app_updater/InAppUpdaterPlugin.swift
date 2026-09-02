import Flutter
import UIKit

private let methodChannelName = "in_app_updater/methods"

/// Apple has no in-app self-update API; this compares the running app's
/// version against the live App Store listing via the public lookup endpoint.
public class InAppUpdaterPlugin: NSObject, FlutterPlugin {
  private var appStoreUrl: URL?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: registrar.messenger())
    let instance = InAppUpdaterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkForUpdate":
      checkForUpdate(result: result)
    case "openStore":
      openStore(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func checkForUpdate(result: @escaping FlutterResult) {
    guard let bundleId = Bundle.main.bundleIdentifier,
      let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
      let lookupUrl = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)")
    else {
      result(FlutterError(code: "BAD_CONFIG", message: "Missing bundle id or app version", details: nil))
      return
    }

    URLSession.shared.dataTask(with: lookupUrl) { [weak self] data, _, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "CHECK_FAILED", message: error.localizedDescription, details: nil))
        }
        return
      }

      guard let data = data,
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let entries = json["results"] as? [[String: Any]],
        let entry = entries.first,
        let latestVersion = entry["version"] as? String,
        let trackViewUrlString = entry["trackViewUrl"] as? String,
        let trackViewUrl = URL(string: trackViewUrlString)
      else {
        DispatchQueue.main.async {
          result(FlutterError(code: "PARSE_FAILED", message: "Unexpected App Store lookup response", details: nil))
        }
        return
      }

      self?.appStoreUrl = trackViewUrl
      let updateAvailable = latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending

      DispatchQueue.main.async {
        result([
          "updateAvailable": updateAvailable,
          "currentVersion": currentVersion,
          "latestVersion": latestVersion,
          "storeUrl": trackViewUrlString,
        ])
      }
    }.resume()
  }

  private func openStore(result: @escaping FlutterResult) {
    guard let url = appStoreUrl else {
      result(FlutterError(code: "NO_URL", message: "Call checkForUpdate before openStore", details: nil))
      return
    }
    DispatchQueue.main.async {
      UIApplication.shared.open(url, options: [:]) { success in
        result(success)
      }
    }
  }
}
