import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('Notification')
extension type Notification._(JSObject _) implements JSObject {
  @JS('requestPermission')
  external static void requestPermission();

  @JS('permission')
  external static String get permission;

  external factory Notification(String title, [NotificationOptions options]);
}

@JS()
@anonymous
extension type NotificationOptions._(JSObject _) implements JSObject {
  external factory NotificationOptions({String body});
}

void requestWebNotificationPermission() {
  try {
    Notification.requestPermission();
  } catch (e) {
    debugPrint('Error requesting web notification permission: $e');
  }
}

void showWebNotification(String title, String body) {
  try {
    final String currentPermission = Notification.permission;
    if (currentPermission == 'granted') {
      Notification(title, NotificationOptions(body: body));
    } else {
      debugPrint('Web Notification permission is not granted (current: $currentPermission)');
    }
  } catch (e) {
    debugPrint('Error showing web notification: $e');
  }
}
