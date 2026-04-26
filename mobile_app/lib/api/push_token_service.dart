import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'auth_storage.dart';

class PushTokenService {
  static const String _registeredTokenKey = 'fcmRegisteredToken';
  static const String _registeredPlatformKey = 'fcmRegisteredPlatform';
  static bool _refreshListenerAttached = false;
  static bool _firebaseAttempted = false;
  static bool _firebaseReady = false;

  static Future<void> syncCurrentDevice() async {
    final jwt = await getJwt();
    if (jwt == null || jwt.isEmpty) return;

    final token = await _getDeviceToken();
    if (token == null || token.isEmpty) return;

    final platform = _platformName();
    if (!await _shouldRegisterAgain(token, platform)) return;

    try {
      await ApiService.post('notifications/me/device-tokens', {
        'token': token,
        'platform': platform,
      });
      await _cacheRegisteredToken(token, platform);
      _attachRefreshListener();
    } catch (_) {
      // Best-effort: notifications still work as in-app inbox even if push registration fails.
    }
  }

  static Future<void> _cacheRegisteredToken(
    String token,
    String platform,
  ) async {
    final prefs = await _prefs();
    await prefs.setString(_registeredTokenKey, token);
    await prefs.setString(_registeredPlatformKey, platform);
  }

  static Future<bool> _shouldRegisterAgain(
    String token,
    String platform,
  ) async {
    final prefs = await _prefs();
    final storedToken = prefs.getString(_registeredTokenKey);
    final storedPlatform = prefs.getString(_registeredPlatformKey);
    return storedToken != token || storedPlatform != platform;
  }

  static Future<SharedPreferences> _prefs() async {
    return SharedPreferences.getInstance();
  }

  static Future<String?> _getDeviceToken() async {
    final ready = await _ensureFirebase();
    if (!ready) return null;

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _ensureFirebase() async {
    if (_firebaseReady) return true;
    if (_firebaseAttempted) return false;

    _firebaseAttempted = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;
      return true;
    } catch (_) {
      _firebaseReady = false;
      return false;
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'WEB';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'IOS';
      case TargetPlatform.android:
        return 'ANDROID';
      default:
        return 'WEB';
    }
  }

  static void _attachRefreshListener() {
    if (_refreshListenerAttached) return;
    _refreshListenerAttached = true;

    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final jwt = await getJwt();
        if (jwt == null || jwt.isEmpty) return;

        try {
          await ApiService.post('notifications/me/device-tokens', {
            'token': newToken,
            'platform': _platformName(),
          });
          final prefs = await _prefs();
          await prefs.setString(_registeredTokenKey, newToken);
          await prefs.setString(_registeredPlatformKey, _platformName());
        } catch (_) {
          // Ignore refresh failures; the next app launch will retry.
        }
      });

      // Listen for foreground messages (when app is open)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Foreground message received. In a production app, you'd show:
        // - SnackBar via ScaffoldMessenger (if available)
        // - Local notification (if using flutter_local_notifications)
        // - In-app overlay banner
        // For now, we log it for debugging; app state management can handle UI display
        if (kDebugMode) {
          print('Foreground message: ${message.notification?.title}');
        }
      });
    } catch (_) {
      _refreshListenerAttached = false;
    }
  }
}
