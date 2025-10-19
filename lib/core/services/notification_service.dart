import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rumblr/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _initialized = false;
  static bool _timeZonesInitialized = false;

  static const String _localChannelId = 'rumblr_general';
  static const String _localChannelName = 'Rumblr Alerts';
  static const String _localChannelDescription =
      'Fight updates and tournament reminders';

  static Future<void> initialize() async {
    if (_initialized) return;

    await _ensureTimeZonesInitialized();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(initSettings);

    await _messaging.requestPermission();

    FirebaseMessaging.onMessage.listen((message) async {
      await showRemoteMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      await showRemoteMessage(message);
    });

    _initialized = true;
  }

  static Future<void> registerDeviceToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('fighters').doc(userId).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _messaging.onTokenRefresh.listen((newToken) async {
        await _firestore.collection('fighters').doc(userId).set({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint('Failed to register device token: $e');
    }
  }

  static Future<void> scheduleTournamentReminder({
    required String tournamentId,
    required String title,
    required DateTime startDate,
  }) async {
    final scheduled = startDate.subtract(const Duration(hours: 24));
    if (scheduled.isBefore(DateTime.now())) {
      return;
    }

    await _ensureTimeZonesInitialized();

    const androidDetails = AndroidNotificationDetails(
      _localChannelId,
      _localChannelName,
      channelDescription: _localChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final tzDateTime = tz.TZDateTime.from(scheduled.toUtc(), tz.UTC);

    await _localNotifications.zonedSchedule(
      _notificationIdForTournament(tournamentId),
      'Tournament Reminder',
      '$title starts in 24 hours',
      tzDateTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'tournament_reminder_$tournamentId', scheduled.toIso8601String());
  }

  static Future<void> cancelTournamentReminder(String tournamentId) async {
    await _localNotifications
        .cancel(_notificationIdForTournament(tournamentId));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tournament_reminder_$tournamentId');
  }

  static Future<void> showRemoteMessage(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      _localChannelId,
      _localChannelName,
      channelDescription: _localChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final notification = message.notification;
    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        details,
        payload: message.data['payload'] as String?,
      );
    }
  }

  static int _notificationIdForTournament(String tournamentId) =>
      tournamentId.hashCode & 0x7FFFFFFF;

  static Future<void> _ensureTimeZonesInitialized() async {
    if (_timeZonesInitialized) {
      return;
    }
    tz.initializeTimeZones();
    _timeZonesInitialized = true;
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await NotificationService.initialize();
  await NotificationService.showRemoteMessage(message);
}
