// lib/services/location_service.dart
import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AppLocationService {
  static final AppLocationService _i = AppLocationService._();
  AppLocationService._();
  factory AppLocationService() => _i;

  StreamSubscription<Position>? _sub;

  Future<void> start() async {
    // Ensure location services are ON
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    }

    // Android 13+ needs runtime notifications permission if you show your own
    if (Platform.isAndroid && await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // Location runtime permissions
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }

    // Avoid duplicate streams
    await _sub?.cancel();

    // Use generic LocationSettings (no Android-specific foreground config)
    const settings = LocationSettings(
      accuracy: LocationAccuracy.best,            // highest precision
      distanceFilter: 0,                          // every movement
      timeLimit: null,                            // continuous
    );

    // If you want a periodic cadence, use AndroidSettings/AppleSettings intervals,
    // but DO NOT add any ForegroundNotificationConfig here.
    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen((pos) {
      // TODO: send to your server or store locally
      // print('pos: ${pos.latitude}, ${pos.longitude}');
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
