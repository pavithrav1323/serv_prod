import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

const _kChannelId = 'serv_tracking';
const _kChannelName = 'SERV Tracking';
const _kChannelDesc = 'Foreground location tracking';
const _kNotifId = 1212;

bool get _isAndroid => !kIsWeb && Platform.isAndroid;

// Workmanager names & keys
const _wmUniqueTask = 'serv_location_periodic';
const _wmSimpleTask = 'serv_location_oneoff';
const _kEmpKey = 'empid';
const _kTokKey = 'token';

// Persist keys
const _spEmp = 'bg_empid';
const _spTok = 'bg_token';

// In-memory identity
String? _empid, _token;

// Single notifications plugin
final _flnp = FlutterLocalNotificationsPlugin();

/// Create the Android notification channel & ask notification permission (13+)
Future<void> _ensureNotifChannel() async {
  if (!_isAndroid) return;

  // Init plugin once
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _flnp.initialize(const InitializationSettings(android: androidInit));

  final android =
      _flnp.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  // Android 13+ runtime permission
  final enabled = await android?.areNotificationsEnabled();
  if (enabled == false) {
    await android?.requestNotificationsPermission(); 
  }

  // Create (idempotent) low-importance channel for foreground notification
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    _kChannelId,
    _kChannelName,
    description: _kChannelDesc,
    importance: Importance.low,
  ));
}

// ────────────────────────────────────────────────────────────────────────────
// Public API
// ────────────────────────────────────────────────────────────────────────────

Future<void> initializeBackgroundSystems() async {
  if (!_isAndroid) return;

  await _ensureNotifChannel();

  // Configure foreground service (does NOT auto-start)
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _kChannelId,
      initialNotificationTitle: 'SERV App',
      initialNotificationContent: 'Preparing location tracking…',
      foregroundServiceNotificationId: _kNotifId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    // not const on some versions; harmless on Android
    iosConfiguration: IosConfiguration(),
  );
}

Future<void> setTrackingIdentity({
  required String empid,
  required String token,
}) async {
  _empid = empid;
  _token = token;
  final sp = await SharedPreferences.getInstance();
  await sp.setString(_spEmp, empid);
  await sp.setString(_spTok, token);
}

/// SAFE start: only starts if Android 13+ notification permission is granted.
Future<void> startForegroundTracking() async {
  if (!_isAndroid) return;

  // Make sure channel + (13+) permission exist before we show a foreground notif
  await _ensureNotifChannel();

  final androidImpl = _flnp
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  // 1) Are notifications enabled?
  bool? granted = await (androidImpl?.areNotificationsEnabled() ?? Future.value(true));

  // 2) If not, try requesting once.
  if (!granted!) {
    granted = await (androidImpl?.requestNotificationsPermission() ?? Future.value(false));
  }

  // 3) If still not granted, DO NOT start the service (it would crash).
  if (!granted!) {
    debugPrint('[FG] Notifications permission not granted – skip startForeground to avoid crash.');
    return;
  }

  // OK to start
  final service = FlutterBackgroundService();
  if (!await service.isRunning()) {
    await service.startService();
  } else {
    service.invoke('setAsForeground');
  }
}

Future<void> stopForegroundTracking() async {
  if (!_isAndroid) return;
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke('stopService');
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Workmanager (fallback / legacy periodic scheduling)
// ────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    // ✅ Ensure plugins (e.g., shared_preferences, geolocator) are registered
    DartPluginRegistrant.ensureInitialized();

    final emp = inputData?[_kEmpKey]?.toString();
    final tok = inputData?[_kTokKey]?.toString();
    debugPrint('[Workmanager] Task=$task empid=$emp');

    try {
      if ((emp ?? '').isNotEmpty && (tok ?? '').isNotEmpty) {
        await _pingServer(emp!, tok!);
      }
    } catch (_) {}
    return Future.value(true);
  });
}

Future<void> scheduleBackgroundTracking({
  required String empid,
  required String token,
}) async {
  if (!_isAndroid) return;

  try {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  } catch (_) {}

  await Workmanager().cancelByUniqueName(_wmUniqueTask);

  await Workmanager().registerPeriodicTask(
    _wmUniqueTask,
    _wmSimpleTask,
    frequency: const Duration(minutes: 15),
    initialDelay: const Duration(minutes: 1),
    inputData: {_kEmpKey: empid, _kTokKey: token},
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresCharging: false,
      requiresBatteryNotLow: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
  debugPrint('[Workmanager] scheduled for $empid');
}

Future<void> cancelBackgroundTracking({required String empid}) async {
  if (!_isAndroid) return;
  await Workmanager().cancelByUniqueName(_wmUniqueTask);
  debugPrint('[Workmanager] cancelled for $empid');
}

// ────────────────────────────────────────────────────────────────────────────
// Foreground-service entrypoint isolate
// ────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  // ✅ Ensure plugins are available in this background isolate
  WidgetsFlutterBinding.ensureInitialized();

  // Rehydrate identity from prefs
  final sp = await SharedPreferences.getInstance();
  _empid ??= sp.getString(_spEmp);
  _token ??= sp.getString(_spTok);

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    await service.setForegroundNotificationInfo(
      title: 'SERV App',
      content: 'Location tracking active',
    );
  }

  service.on('setAsForeground').listen((_) async {
    if (service is AndroidServiceInstance) {
      await service.setAsForegroundService();
      await service.setForegroundNotificationInfo(
        title: 'SERV App',
        content: 'Location tracking active',
      );
    }
  });

  service.on('stopService').listen((_) async => service.stopSelf());

  // Tick once immediately, then every ~20 minutes
  Future<void> tick() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (_empid != null && _token != null) {
        await _pingServer(_empid!, _token!, lat: p.latitude, lng: p.longitude);
      }

      if (service is AndroidServiceInstance) {
        await service.setForegroundNotificationInfo(
          title: 'SERV',
          content:
              "Location Service Activated ",
        );
      }
    } catch (e) {
      debugPrint('[BG] tick error: $e');
    }
  }

  await tick();
  Timer.periodic(const Duration(minutes: 20), (_) => tick());
}

// ────────────────────────────────────────────────────────────────────────────
// API ping – uses your existing /api/tracking/pos endpoint
// ────────────────────────────────────────────────────────────────────────────
Future<void> _pingServer(
  String empid,
  String token, {
  double? lat,
  double? lng,
}) async {
  // If lat/lng not provided (e.g., WorkManager call), try to get a quick fix
  double? lat0 = lat, lng0 = lng;
  try {
    if (lat0 == null || lng0 == null) {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      lat0 = p.latitude;
      lng0 = p.longitude;
    }
  } catch (_) {
    // still send a heartbeat without coords if needed
  }

  final uri = Uri.parse('https://api-zmj7dqloiq-el.a.run.app/api/tracking/pos');

  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    'x-empid': empid,
  };

  final body = <String, dynamic>{
    if (lat0 != null && lng0 != null) 'lat': lat0,
    if (lat0 != null && lng0 != null) 'lng': lng0,
    'ts': DateTime.now().toIso8601String(),
    'source': 'fg/worker',
  };

  await http
      .post(uri, headers: headers, body: jsonEncode(body))
      .timeout(const Duration(seconds: 10));
}
