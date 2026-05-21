import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationSettings {
  // static const IOSNotificationDetails iOSPlatformChannelSpecifics =
  //     IOSNotificationDetails(sound: 'money'); //TODO doesn't work

  static const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'ppc',
    'DigiByte',
    channelDescription: 'Notification channel for DigiByte app',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    sound: RawResourceAndroidNotificationSound('money'),
  );

  static NotificationDetails get platformChannelSpecifics {
    return const NotificationDetails(
      android: androidPlatformChannelSpecifics,
      // iOS: iOSPlatformChannelSpecifics,
    );
  }
}
