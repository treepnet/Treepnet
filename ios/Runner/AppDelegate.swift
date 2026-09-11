import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Referral deferred attribution: read the invite URL the web landing copied
    // to the clipboard on the App Store tap. `detectValues(for: [.probableWebURL])`
    // (iOS 16+) returns a clipboard URL WITHOUT the "Allow Paste?" prompt — unlike
    // reading UIPasteboard.string directly. Nothing is exposed unless a web URL is
    // present, so nothing else on the clipboard leaks.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "treepnet/referral",
        binaryMessenger: controller.binaryMessenger
      )
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

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
