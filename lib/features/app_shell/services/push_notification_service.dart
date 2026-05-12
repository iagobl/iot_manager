import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
  AndroidNotificationChannel(
    'iot_manager_alerts',
    'Alertas IoT',
    description: 'Incidencias e invitaciones del sistema IoT',
    importance: Importance.max,
  );

  bool _initialized = false;

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openAppSubscription;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(
      firebaseMessagingBackgroundHandler,
    );

    await _initializeLocalNotifications();
    await _requestPermissions();
    await _createAndroidChannel();
    await _configureForegroundHandlers();

    await _saveTokenSafely();

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((token) async {
      await _saveTokenSafely(token);
    });
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(settings);
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _createAndroidChannel() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  Future<void> _configureForegroundHandlers() async {
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen((message) async {
          await _showNotification(message);
        });

    _openAppSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen((message) async {
          debugPrint('Push abierta desde sistema: ${message.data}');
        });
  }

  Future<void> _showNotification(RemoteMessage message) async {
    final notification = message.notification;

    final title =
        notification?.title ?? message.data['title']?.toString() ?? 'Notificación';
    final body =
        notification?.body ?? message.data['body']?.toString() ?? '';

    const androidDetails = AndroidNotificationDetails(
      'iot_manager_alerts',
      'Alertas IoT',
      channelDescription: 'Incidencias e invitaciones del sistema IoT',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      details,
    );
  }

  Future<void> _saveTokenSafely([String? newToken]) async {
    try {
      await _saveToken(newToken);
    } catch (error, stackTrace) {
      debugPrint('Error guardando token FCM: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _saveToken([String? newToken]) async {
    final token = newToken ?? await _messaging.getToken();
    debugPrint('FCM token obtenido: $token');

    if (token == null || token.trim().isEmpty) {
      debugPrint('No se obtuvo token FCM');
      return;
    }


    final userId = Supabase.instance.client.auth.currentUser?.id;
    debugPrint('Usuario actual para guardar token: $userId');

    if (userId == null || userId.trim().isEmpty) {
      debugPrint('No hay usuario autenticado, no se guarda el token');
      return;
    }

    await Supabase.instance.client.from('user_push_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': 'android',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );

    debugPrint('Token guardado correctamente en Supabase');
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openAppSubscription?.cancel();
  }
}
