import 'dart:developer';
import 'package:connecto/my_app.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:vibration/vibration.dart';

class NotificationHandler {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    // Request permissions
    await _firebaseMessaging.requestPermission();
    // ✅ iOS foreground presentation config
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get and print FCM token
    final token = await _firebaseMessaging.getToken();
    log("FCM Token: $token");

    // Init local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initSettings);

    // ✅ Create Android channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'default_channel',
            'General Notifications',
            description: 'Used for all foreground notifications',
            importance: Importance.max,
          ),
        );

    bool _hasHandled = false;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final data = message.data;

      final title = notification?.title ?? data['title'] ?? "New Notification";
      final body = notification?.body ?? data['body'] ?? "";

      print("📩 Foreground Notification: $title - $body");
      print("📦 Data: $data");

      // 🔔 Trigger vibration for ping immediately
      if (data['type'] == 'ping' && data['vibrationPattern'] != null) {
        log('should vibrate');
        _vibrateWithPattern(data['vibrationPattern']);
      }

      _localNotifications.show(
        notification.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'default_channel', // must match the channel created during init
            'General Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: data['type'], // optional if you want to handle taps
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("onMessageOpenedApp: $message");
      _handleMessage(message, rootNavigatorKey);
    });
  }

  static void handleInitialMessage( GlobalKey<NavigatorState> navigatorKey,RemoteMessage msg) async {
    // final msg = await _firebaseMessaging.getInitialMessage();

    log('notification message : $msg');
    if (msg != null) _handleMessage(msg, rootNavigatorKey);
  }

  static void listenToMessageTap(BuildContext context) {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message, rootNavigatorKey);
    });
  }

  static void _handleMessage(
      RemoteMessage message, GlobalKey<NavigatorState> navigatorKey) {
    log('notification message : ${message.data}');
    final route = message.data['type'];
    final gatheringId = message.data['gatheringId'];
    final vibrationRaw =
        message.data['vibrationPattern'] ?? ''; // "100,100,100,300"

    final chatId = message.data['chatId'];
    final friendId = message.data['friendId'];
    final friendName = message.data['friendName'];

    if (route == 'gathering' && gatheringId != null) {
      // context.go('/gathering-details/$gatheringId');
      GoRouter.of(navigatorKey.currentContext!).go(
        '/gathering/gathering-details/$gatheringId',
      );
    } else if (route == 'ping') {
      _vibrateWithPattern(vibrationRaw);
      GoRouter.of(navigatorKey.currentContext!).go(
        '/bond/chat/$chatId',
        extra: {
          'friendId': friendId,
          'friendName': friendName,
        },
      );
      // You can also navigate to chat screen here if needed:
      // GoRouter.of(navigatorKey.currentContext!).go('/bond/chat/$friendId');
      return;
    }

    // Add more route handling logic here as needed
  }

  static void _vibrateWithPattern(String? pattern) async {
    if (pattern == null) return;

    final parts = pattern
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();

    log('vibration parts : $parts');

    if (parts.isEmpty) return;

    final hasVibrator = await Vibration.hasVibrator() ?? false;
    if (!hasVibrator) return;

    Vibration.vibrate(pattern: parts);
  }
}



  // static void listenToForegroundMessages(BuildContext context) {
  //   FirebaseMessaging.onMessage.listen((message) {
  //     final notification = message.notification;
  //     final data = message.data;

  //     final title = notification?.title ?? data['title'];
  //     final body = notification?.body ?? data['body'];

  //     if (title != null && body != null) {
  //       _localNotifications.show(
  //         notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
  //         title,
  //         body,
  //         const NotificationDetails(
  //           android: AndroidNotificationDetails(
  //             'default_channel',
  //             'General Notifications',
  //             importance: Importance.max,
  //             priority: Priority.high,
  //           ),
  //           iOS: DarwinNotificationDetails(),
  //         ),
  //         payload: data['type'],
  //       );
  //     }
  //   });
  // }
