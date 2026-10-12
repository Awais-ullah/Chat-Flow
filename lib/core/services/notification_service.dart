import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../features/chats/repository/chat_repository.dart';

/// Handles everything related to push notifications:
/// permission requests, token retrieval, and displaying notifications
/// while the app is open in the foreground.
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chatflow_messages', // must match the AndroidManifest meta-data value
    'Messages',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // 1. Ask the user for notification permission (required on Android 13+ and iOS).
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2. Initialize the local notifications plugin.
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit);
    await _localNotifications.initialize(settings: initSettings);

    // 3. Create the Android notification channel (Android 8+ requires this
    // to exist before any notification using it can be shown).
    // Explicit type annotation here avoids any ambiguity in how the
    // generic method call is parsed.
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
    }

    // 4. Listen for messages that arrive WHILE the app is open (foreground).
    // FCM does NOT auto-display these — we must show them ourselves.
    FirebaseMessaging.onMessage.listen((message) {
      _showForegroundNotification(message);
      _markDeliveredFromMessage(message);
    });
  }

  /// Gets this device's unique FCM token — needed so OTHER users' devices
  /// know where to send a push notification targeting this device.
  Future<String?> getToken() => _messaging.getToken();

  /// Fires whenever the token changes (can happen occasionally) —
  /// callers should re-save it to Firestore when this fires.
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        channelDescription: _channel.description,
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }
  /// The receiving device confirms its OWN delivery — this only ever
  /// runs on a device that genuinely just received the push, which only
  /// happens if that device currently has real internet connectivity.
  Future<void> _markDeliveredFromMessage(RemoteMessage message) async {
    final conversationId = message.data['conversationId'];
    final messageId = message.data['messageId'];
    if (conversationId == null || messageId == null) return;
    try {
      await ChatRepository().markMessageDelivered(
        conversationId: conversationId,
        messageId: messageId,
      );
    } catch (e) {
      // ignore: avoid_print
      print('markMessageDelivered (foreground) failed: $e');
    }
  }
}