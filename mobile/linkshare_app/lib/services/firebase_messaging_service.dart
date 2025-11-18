import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:io';

/// Background message handler
/// Must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('FCM: Handling background message: ${message.messageId}');
  print('FCM: Title: ${message.notification?.title}');
  print('FCM: Body: ${message.notification?.body}');
  print('FCM: Data: ${message.data}');
}

class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Event streams for different notification types
  final _friendRequestController = StreamController<Map<String, dynamic>>.broadcast();
  final _friendAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _collectionSharedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onFriendRequest => _friendRequestController.stream;
  Stream<Map<String, dynamic>> get onFriendAccepted => _friendAcceptedController.stream;
  Stream<Map<String, dynamic>> get onCollectionShared => _collectionSharedController.stream;

  String? _fcmToken;

  String? get fcmToken => _fcmToken;

  /// Initialize Firebase Messaging
  Future<void> initialize() async {
    print('FCM: Initializing Firebase Messaging');

    // Request permission
    final settings = await _requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('FCM: Permission denied');
      return;
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Get FCM token
    await _getToken();

    // Handle messages
    _setupMessageHandlers();

    print('FCM: Initialization complete');
  }

  /// Request notification permissions
  Future<NotificationSettings> _requestPermission() async {
    print('FCM: Requesting permission');

    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('FCM: Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    print('FCM: Initializing local notifications');

    // Android settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'linkshare_notifications',
        'LinkShare Notifications',
        description: 'Notifications for LinkShare app',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    print('FCM: Local notifications initialized');
  }

  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      // For iOS, get APNs token first
      if (Platform.isIOS) {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          print('FCM: APNs token not available, retrying...');
          await Future.delayed(const Duration(seconds: 2));
          return await _getToken();
        }
      }

      _fcmToken = await _firebaseMessaging.getToken();
      print('FCM: Token obtained: $_fcmToken');

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        print('FCM: Token refreshed: $newToken');
        _fcmToken = newToken;
        // TODO: Send new token to backend
      });

      return _fcmToken;
    } catch (e) {
      print('FCM: Error getting token: $e');
      return null;
    }
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when user taps notification (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    _firebaseMessaging.getInitialMessage().then((message) {
      if (message != null) {
        print('FCM: App opened from terminated state via notification');
        _handleNotificationTap(message);
      }
    });
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    print('FCM: Foreground message received');
    print('FCM: Title: ${message.notification?.title}');
    print('FCM: Body: ${message.notification?.body}');
    print('FCM: Data: ${message.data}');

    // Show local notification
    _showLocalNotification(message);

    // Emit event based on type
    _emitEvent(message);
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'linkshare_notifications',
      'LinkShare Notifications',
      channelDescription: 'Notifications for LinkShare app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    print('FCM: Notification tapped');
    print('FCM: Data: ${message.data}');

    _emitEvent(message);
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('FCM: Local notification tapped');
    print('FCM: Payload: ${response.payload}');
  }

  /// Emit event based on notification type
  void _emitEvent(RemoteMessage message) {
    final data = message.data;
    final type = data['type'];

    switch (type) {
      case 'friend_request':
        _friendRequestController.add(data);
        break;
      case 'friend_request_accepted':
        _friendAcceptedController.add(data);
        break;
      case 'collection_shared':
        _collectionSharedController.add(data);
        break;
      default:
        print('FCM: Unknown notification type: $type');
    }
  }

  /// Delete FCM token
  Future<void> deleteToken() async {
    try {
      await _firebaseMessaging.deleteToken();
      _fcmToken = null;
      print('FCM: Token deleted');
    } catch (e) {
      print('FCM: Error deleting token: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _friendRequestController.close();
    _friendAcceptedController.close();
    _collectionSharedController.close();
  }
}
