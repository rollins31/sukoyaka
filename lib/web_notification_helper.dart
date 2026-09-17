import 'web_notification_helper_stub.dart'
    if (dart.library.js_util) 'web_notification_helper_web.dart'
    if (dart.library.html) 'web_notification_helper_web.dart';

class WebNotificationHelper {
  static void requestPermission() => requestWebNotificationPermission();
  static void showNotification(String title, String body) => showWebNotification(title, body);
}
