import Flutter
import UIKit

public class MessengerChatPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "messenger_chat", binaryMessenger: registrar.messenger())
    let instance = MessengerChatPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "getUniqueDeviceId":
      if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
          result(vendorId)
      } else {
          result(FlutterError(code: "UNAVAILABLE", message: "Device ID not available", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
