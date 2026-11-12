import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:fibus/core/constants/app_constants.dart';
import 'package:fibus/services/firestore_service.dart';

/// Top-level background message handler required by Firebase Cloud Messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM Background message received: ${message.messageId}');
}

/// Comprehensive notification service wrapping Firebase Cloud Messaging (FCM)
/// and [FlutterLocalNotificationsPlugin] for departure alerts and bus tracking reminders.
class NotificationService {
  final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final FirestoreService _firestoreService;

  String? _fcmToken;
  bool _isInitialized = false;

  final StreamController<RemoteMessage> _messageOpenedController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<NotificationResponse> _notificationResponseController =
      StreamController<NotificationResponse>.broadcast();

  /// Singleton instance.
  static final NotificationService _instance = NotificationService._internal();

  /// Shared singleton accessor.
  static NotificationService get instance => _instance;

  /// Factory constructor returning the singleton or injected instance.
  factory NotificationService({
    FirebaseMessaging? fcm,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirestoreService? firestoreService,
  }) {
    if (fcm != null || localNotifications != null || firestoreService != null) {
      return NotificationService._internal(
        fcm: fcm,
        localNotifications: localNotifications,
        firestoreService: firestoreService,
      );
    }
    return _instance;
  }

  NotificationService._internal({
    FirebaseMessaging? fcm,
    FlutterLocalNotificationsPlugin? localNotifications,
    FirestoreService? firestoreService,
  }) : _fcm = fcm ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin(),
       _firestoreService = firestoreService ?? FirestoreService();

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// The active FCM registration token for this device, or `null` if uninitialized.
  String? get fcmToken => _fcmToken;

  /// Whether the notification system has successfully completed initialization.
  bool get isInitialized => _isInitialized;

  /// Stream emitting FCM messages that caused the app to be opened from background.
  Stream<RemoteMessage> get onMessageOpenedApp =>
      _messageOpenedController.stream;

  /// Stream emitting taps on local notification banners.
  Stream<NotificationResponse> get onNotificationTapped =>
      _notificationResponseController.stream;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes FCM permissions, local notification channels, listeners,
  /// and retrieves the registration token.
  ///
  /// If [userId] is provided, writes the FCM token to the user's Firestore document.
  Future<void> initialize({String? userId}) async {
    if (_isInitialized) {
      if (userId != null && _fcmToken != null) {
        await saveTokenToFirestore(userId);
      }
      return;
    }

    try {
      // 1. Request notification permissions from OS (Android 13+ & iOS)
      final NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('FCM authorization status: ${settings.authorizationStatus}');

      // 2. Configure Flutter Local Notifications Plugin
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _notificationResponseController.add(response);
        },
      );

      // 3. Create High-Priority Notification Channels on Android
      await _createAndroidNotificationChannels();

      // 4. Retrieve FCM Token
      _fcmToken = await _fcm.getToken();
      debugPrint('Device FCM Token: $_fcmToken');

      if (userId != null && _fcmToken != null) {
        await saveTokenToFirestore(userId);
      }

      // 5. Token refresh listener
      _fcm.onTokenRefresh.listen((String newToken) async {
        _fcmToken = newToken;
        debugPrint('FCM Token refreshed: $newToken');
        if (userId != null) {
          await saveTokenToFirestore(userId);
        }
      });

      // 6. Register FCM background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 7. Foreground message listener -> triggers local banner
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _onForegroundMessageReceived(message);
      });

      // 8. Message clicked / opened listener
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _messageOpenedController.add(message);
      });

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService.initialize error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Local Notifications & Foreground Messages
  // ---------------------------------------------------------------------------

  void _onForegroundMessageReceived(RemoteMessage message) {
    debugPrint('Foreground FCM message: ${message.messageId}');
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'Fibus Alert';
    final body = notification?.body ?? message.data['body'] ?? '';

    showLocalNotification(
      title: title,
      body: body,
      payload: message.data['route'] ?? message.data['payload'],
      channelId:
          message.data['channelId'] ?? AppConstants.departureAlertChannelId,
    );
  }

  /// Displays an immediate high-priority local notification on the device.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int? id,
    String? channelId,
  }) async {
    final int notifId =
        id ?? (DateTime.now().millisecondsSinceEpoch.remainder(100000));
    final String targetChannel =
        channelId ?? AppConstants.departureAlertChannelId;

    final NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        targetChannel,
        AppConstants.departureAlertChannelName,
        channelDescription: AppConstants.departureAlertChannelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _localNotifications.show(
        notifId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Failed to show local notification: $e');
    }
  }

  /// Fixed IDs so each departure alert type replaces, rather than stacks on,
  /// an earlier copy of itself.
  static const int _advanceWarningNotificationId = 1001;
  static const int _leaveNowNotificationId = 1002;

  /// Requests the OS notification permission (runtime prompt on Android 13+).
  ///
  /// Returns whether notifications are allowed after the request.
  Future<bool> requestPermission() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('NotificationService.requestPermission error: $e');
      return false;
    }
  }

  /// Whether the app is currently allowed to post notifications.
  Future<bool> areNotificationsEnabled() async {
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        return await androidPlugin.areNotificationsEnabled() ?? false;
      }
      final settings = await _fcm.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('NotificationService.areNotificationsEnabled error: $e');
      return false;
    }
  }

  /// Shows the advance warning ahead of the recommended leave-by time.
  Future<void> showAdvanceWarningNotification({
    required String busName,
    required int minutesRemaining,
    required String leaveTimeFormatted,
  }) {
    return showLocalNotification(
      id: _advanceWarningNotificationId,
      title: 'Leave in about $minutesRemaining minutes',
      body: 'Head out by $leaveTimeFormatted to catch $busName.',
    );
  }

  /// Shows the Leave now alert once the recommended leave-by time is reached.
  Future<void> showLeaveNowNotification({
    required String busName,
    required String stopName,
    required String etaFormatted,
  }) {
    return showLocalNotification(
      id: _leaveNowNotificationId,
      title: 'Leave now',
      body: '$busName is expected at $stopName around $etaFormatted.',
    );
  }

  /// Shows a one-off update when a significant delay moves the plan after
  /// Leave now was already sent (PRD §9.7).
  Future<void> showPlanChangedNotification({
    required String busName,
    required int delayMinutes,
    required String leaveTimeFormatted,
  }) {
    return showLocalNotification(
      id: planChangedNotificationId,
      title: '$busName is running $delayMinutes min late',
      body: 'New plan: leave by $leaveTimeFormatted.',
    );
  }

  static const int advanceWarningNotificationId = _advanceWarningNotificationId;
  static const int leaveNowNotificationId = _leaveNowNotificationId;
  static const int planChangedNotificationId = 1003;

  /// Schedules a departure alert with the OS so it fires even if the app is
  /// backgrounded or closed. Uses an exact alarm when the user allows it,
  /// otherwise an inexact one (may be a few minutes late). Replaces any
  /// pending alert with the same [id].
  Future<void> scheduleDepartureAlert({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final exact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when.toUtc(), tz.UTC),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.departureAlertChannelId,
            AppConstants.departureAlertChannelName,
            channelDescription: AppConstants.departureAlertChannelDesc,
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('NotificationService.scheduleDepartureAlert error: $e');
    }
  }

  /// Cancels one shown or pending notification.
  Future<void> cancel(int id) async {
    try {
      await _localNotifications.cancel(id);
    } catch (e) {
      debugPrint('NotificationService.cancel error: $e');
    }
  }

  /// Cancels every shown or pending local notification.
  Future<void> cancelAll() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      debugPrint('NotificationService.cancelAll error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Topic Subscriptions
  // ---------------------------------------------------------------------------

  /// Subscribes to FCM broadcast topic for a specific bus (e.g. `bus_campus_4`).
  Future<void> subscribeToBusTopic(String busId) async {
    try {
      final topic = 'bus_$busId';
      await _fcm.subscribeToTopic(topic);
      debugPrint('Subscribed to FCM topic: $topic');
    } catch (e) {
      debugPrint('Failed to subscribe to bus topic ($busId): $e');
    }
  }

  /// Unsubscribes from FCM broadcast topic for a specific bus.
  Future<void> unsubscribeFromBusTopic(String busId) async {
    try {
      final topic = 'bus_$busId';
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from FCM topic: $topic');
    } catch (e) {
      debugPrint('Failed to unsubscribe from bus topic ($busId): $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Token Persistence
  // ---------------------------------------------------------------------------

  /// Saves the current device FCM token to the user document in Firestore.
  Future<void> saveTokenToFirestore(String uid) async {
    if (_fcmToken == null) return;
    try {
      await _firestoreService.updateFcmToken(uid, _fcmToken!);
      debugPrint('FCM Token successfully synced to user $uid profile.');
    } catch (e) {
      debugPrint('Failed to save FCM token to Firestore: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Android Channel Configuration
  // ---------------------------------------------------------------------------

  Future<void> _createAndroidNotificationChannels() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidPlugin == null) return;

    // Channel 1: Departure Alerts
    const departureChannel = AndroidNotificationChannel(
      AppConstants.departureAlertChannelId,
      AppConstants.departureAlertChannelName,
      description: AppConstants.departureAlertChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Channel 2: Tracker Foreground Service
    const trackerChannel = AndroidNotificationChannel(
      AppConstants.trackerServiceChannelId,
      AppConstants.trackerServiceChannelName,
      description: AppConstants.trackerServiceChannelDesc,
      importance: Importance.high,
      playSound: false,
      enableVibration: false,
    );

    await Future.wait([
      androidPlugin.createNotificationChannel(departureChannel),
      androidPlugin.createNotificationChannel(trackerChannel),
    ]);
  }
}
