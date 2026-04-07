import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationCallback = void Function(RemoteMessage message);

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  NotificationCallback? _onMessageCallback;
  bool _isInitialized = false;

  /// Initialize notifications
  Future<void> initialize() async {
    try {
      if (_isInitialized) {
        return;
      }

      // Initialize local notifications
      const androidSettings =
          AndroidInitializationSettings('app_icon');
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
        onDidReceiveNotificationResponse: _handleLocalNotificationTap,
      );

      // Request notification permissions
      await requestPermissions();

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background/terminated state messages
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize notifications: ${e.toString()}');
    }
  }

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      return await _firebaseMessaging.getToken();
    } catch (e) {
      throw Exception('Failed to get FCM token: ${e.toString()}');
    }
  }

  /// Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      throw Exception('Failed to request notification permissions: ${e.toString()}');
    }
  }

  /// Set callback for foreground messages
  void setOnMessageCallback(NotificationCallback callback) {
    _onMessageCallback = callback;
  }

  // ======================= NOTIFICATION ALERTS =======================

  /// Send screen time alert
  Future<void> sendScreenTimeAlert(String childName, int minutesUsed) async {
    try {
      if (childName.isEmpty || minutesUsed < 0) {
        throw Exception('Invalid parameters for screen time alert');
      }

      await _showLocalNotification(
        title: 'Screen Time Alert',
        body: '$childName has used $minutesUsed minutes of screen time today.',
        payload: 'screen_time_$childName',
      );
    } catch (e) {
      throw Exception('Failed to send screen time alert: ${e.toString()}');
    }
  }

  /// Send geofence alert
  Future<void> sendGeofenceAlert(String childName, String zoneName) async {
    try {
      if (childName.isEmpty || zoneName.isEmpty) {
        throw Exception('Child name and zone name cannot be empty');
      }

      await _showLocalNotification(
        title: 'Geofence Alert',
        body: '$childName has left $zoneName.',
        payload: 'geofence_$childName',
      );
    } catch (e) {
      throw Exception('Failed to send geofence alert: ${e.toString()}');
    }
  }

  /// Send blocked app alert
  Future<void> sendBlockedAppAlert(String childName, String appName) async {
    try {
      if (childName.isEmpty || appName.isEmpty) {
        throw Exception('Child name and app name cannot be empty');
      }

      await _showLocalNotification(
        title: 'App Blocked',
        body: '$childName attempted to use $appName.',
        payload: 'blocked_app_$appName',
      );
    } catch (e) {
      throw Exception('Failed to send blocked app alert: ${e.toString()}');
    }
  }

  // ======================= SUBSCRIPTION MANAGEMENT =======================

  /// Subscribe to child device notifications
  Future<void> subscribeToChild(String deviceId) async {
    try {
      if (deviceId.isEmpty) {
        throw Exception('Device ID cannot be empty');
      }

      await _firebaseMessaging.subscribeToTopic('child_$deviceId');
    } catch (e) {
      throw Exception('Failed to subscribe to child: ${e.toString()}');
    }
  }

  /// Unsubscribe from child device notifications
  Future<void> unsubscribeFromChild(String deviceId) async {
    try {
      if (deviceId.isEmpty) {
        throw Exception('Device ID cannot be empty');
      }

      await _firebaseMessaging.unsubscribeFromTopic('child_$deviceId');
    } catch (e) {
      throw Exception('Failed to unsubscribe from child: ${e.toString()}');
    }
  }

  // ======================= PRIVATE HELPER METHODS =======================

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String payload = '',
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'com.parentshield.channel_high',
        'ParentShield Alerts',
        channelDescription: 'High priority parental control alerts',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
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
        DateTime.now().millisecond,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      throw Exception('Failed to show local notification: ${e.toString()}');
    }
  }

  /// Handle foreground message
  void _handleForegroundMessage(RemoteMessage message) {
    try {
      if (_onMessageCallback != null) {
        _onMessageCallback!(message);
      }

      final notification = message.notification;
      if (notification != null) {
        _showLocalNotification(
          title: notification.title ?? 'ParentShield',
          body: notification.body ?? '',
          payload: message.data['payload'] ?? '',
        ).catchError((e) => print('Error showing notification: $e'));
      }
    } catch (e) {
      print('Error handling foreground message: $e');
    }
  }

  /// Handle background message (top-level function)
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    try {
      print('Handling background message: ${message.messageId}');
    } catch (e) {
      print('Error handling background message: $e');
    }
  }

  /// Handle local notification tap
  void _handleLocalNotificationTap(
    NotificationResponse response,
  ) {
    try {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        print('Notification tapped: $payload');
        // Handle notification tap - navigate to relevant screen
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  /// Enable notification foreground presentation on iOS 14+
  Future<void> enableForegroundNotifications() async {
    try {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      throw Exception('Failed to enable foreground notifications: ${e.toString()}');
    }
  }

  /// Get notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    try {
      return await _firebaseMessaging.getNotificationSettings();
    } catch (e) {
      throw Exception('Failed to get notification settings: ${e.toString()}');
    }
  }
}
