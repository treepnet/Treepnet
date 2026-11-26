import UIKit
import Flutter

// UIScene lifecycle (required for apps built with the iOS 27 SDK, which close
// at launch without it). The window now belongs to FlutterSceneDelegate (see
// UIApplicationSceneManifest in Info.plist), so nothing here may use `window`:
// plugins and our own channels are set up once the engine exists, in
// didInitializeImplicitFlutterEngine.
// https://docs.flutter.dev/release/breaking-changes/uiscenedelegate
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    registerSettingsChannel(messenger)
    registerReferralChannel(messenger)
  }

  // The notifications list's "turn on notifications" row: straight to this
  // app's notification settings.
  private func registerSettingsChannel(_ messenger: FlutterBinaryMessenger) {
    let settings = FlutterMethodChannel(name: "treepnet/settings", binaryMessenger: messenger)
    settings.setMethodCallHandler { call, result in
      guard call.method == "openNotificationSettings" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else {
        result(false)
        return
      }
      UIApplication.shared.open(url) { opened in result(opened) }
    }
  }

  // Referral deferred attribution: read the invite URL the web landing copied
  // to the clipboard on the App Store tap. `detectValues(for: [.probableWebURL])`
  // (iOS 16+) returns a clipboard URL WITHOUT the "Allow Paste?" prompt — unlike
  // reading UIPasteboard.string directly. Nothing is exposed unless a web URL is
  // present, so nothing else on the clipboard leaks.
  // (It used to be set up from `window?.rootViewController`, which is nil at
  // launch under scenes; the engine's own messenger is the same channel.)
  private func registerReferralChannel(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "treepnet/referral", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "readInviteUrl" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard #available(iOS 16.0, *) else {
        // Pre-iOS 16 has no prompt-free read; skip rather than nag the user.
        result(nil)
        return
      }
      // 1) detectPatterns is prompt-free: if there's no web URL on the
      //    clipboard (organic users), stop here — no "Allow Paste?" prompt.
      UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { patterns in
        guard case .success(let found) = patterns,
              found.contains(.probableWebURL) else {
          result(nil)
          return
        }
        // 2) A URL is present (likely an invited user) — read it. This is the
        //    only step that shows the paste prompt, and only to invitees.
        UIPasteboard.general.detectValues(for: [.probableWebURL]) { values in
          switch values {
          case .success(let v):
            if let url = v[.probableWebURL] as? URL {
              result(url.absoluteString)
            } else if let str = v[.probableWebURL] as? String {
              result(str)
            } else {
              result(nil)
            }
          case .failure:
            result(nil)
          }
        }
      }
    }
  }
}
