import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  final SupabaseClient _client;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  PushNotificationService(this._client);

  Future<void> init() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _registerToken();
      _messaging.onTokenRefresh.listen(_saveToken);
    }

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM tap: ${message.data}');
    });
  }

  Future<void> _registerToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('sync_device_id') ?? 'unknown';

    await _client.from('device_tokens').upsert({
      'user_id': userId,
      'fcm_token': token,
      'device_id': deviceId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,device_id');
  }

  Future<void> removeToken() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('sync_device_id') ?? 'unknown';
    await _client
        .from('device_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('device_id', deviceId);
  }
}
