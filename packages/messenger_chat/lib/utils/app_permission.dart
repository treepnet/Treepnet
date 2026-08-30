import 'package:permission_handler/permission_handler.dart';

typedef PermissionCallback = void Function();

mixin AppPermissionManager {
  static Future<void> requestPermission({
    required Permission permission,
    required PermissionCallback onGranted,
    required PermissionCallback onDenied,
    PermissionCallback? onPermanentlyDenied,
  }) async {
    var status = await permission.status;

    if (status.isGranted) {
      onGranted();
      return;
    }

    final newStatus = await permission.request();

    // Foydalanuvchi dialogda ruxsat bergan holat - aks holda birinchi urinish
    // hech qanday natijasiz qolardi va qayta bosish kerak bo'lardi.
    if (newStatus.isGranted || newStatus.isLimited) {
      onGranted();
      return;
    }

    if (newStatus.isPermanentlyDenied) {
      final opened = await openAppSettings();
      if (opened) {
        onPermanentlyDenied?.call();
      } else {
        onDenied();
      }
    } else if (newStatus.isDenied) {
      onDenied();
    }

  }
}