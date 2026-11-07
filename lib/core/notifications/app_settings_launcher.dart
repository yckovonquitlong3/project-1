import 'package:flutter/services.dart';

/// Opens Android screens that the app cannot change itself.
class AppSettingsLauncher {
  const AppSettingsLauncher();

  static const MethodChannel _channel =
      MethodChannel('com.yckovon.multi_wallet_tracker/app_settings');

  /// Opens this app's notification settings in the system settings app.
  ///
  /// Returns false when the platform channel is unavailable (for example in
  /// widget tests) or the settings screen cannot be opened.
  Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
