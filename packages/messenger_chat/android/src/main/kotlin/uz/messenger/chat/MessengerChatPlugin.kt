package uz.messenger.chat

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** MessengerChatPlugin */
class MessengerChatPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "getPlatformVersion" -> {
        result.success("Android ${android.os.Build.VERSION.RELEASE}")
      }
      "getUniqueDeviceId" -> {
        val deviceId = getUniqueDeviceId()
        result.success(deviceId)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun getUniqueDeviceId(): String {
    val androidId = android.provider.Settings.Secure.getString(
      context?.contentResolver,
      android.provider.Settings.Secure.ANDROID_ID
    ) ?: "unknown"

    val combined = "35" + // We make it look like IMEI (optional but common practice in some fingerprinting)
            android.os.Build.BOARD +
            android.os.Build.BRAND +
            android.os.Build.DEVICE +
            android.os.Build.DISPLAY +
            android.os.Build.HOST +
            android.os.Build.ID +
            android.os.Build.MANUFACTURER +
            android.os.Build.MODEL +
            android.os.Build.PRODUCT +
            android.os.Build.TAGS +
            android.os.Build.TYPE +
            android.os.Build.USER +
            androidId

    return hashString(combined)
  }

  private fun hashString(input: String): String {
    val bytes = java.security.MessageDigest
            .getInstance("SHA-256")
            .digest(input.toByteArray())
    return bytes.joinToString("") { "%02x".format(it) }
  }

  private var context: android.content.Context? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "messenger_chat")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    context = null
  }
}
