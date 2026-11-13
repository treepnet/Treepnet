package com.treepnet.application

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // The notifications list's "turn on notifications" row: straight to
        // this app's notification settings (its app page if that won't open).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "treepnet/settings")
            .setMethodCallHandler { call, result ->
                if (call.method != "openNotificationSettings") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val notifications = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                val appPage = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", packageName, null),
                )
                try {
                    // Android 7 has no screen of an app's notifications.
                    startActivity(
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) notifications else appPage,
                    )
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        startActivity(appPage)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
            }
    }
}
