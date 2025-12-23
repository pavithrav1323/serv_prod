// Put this in a new file (e.g., permissions_onboarding.dart) and import where needed.

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:geolocator/geolocator.dart';

class PermissionOnboardingDialog extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const PermissionOnboardingDialog({required this.onAccept, required this.onDecline, super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Why SERV needs these permissions'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('• Biometrics — Make check-in secure and fast.'),
            SizedBox(height: 6),
            Text('• Location (While in use) — Capture location at check-in/check-out.'),
            SizedBox(height: 6),
            Text('• Background location — Optional: allows real-time tracking during your shift only.'),
            SizedBox(height: 8),
            Text('You can change these anytime in Settings.'),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: onDecline, child: const Text('Not now')),
        ElevatedButton(onPressed: onAccept, child: const Text('Turn on')),
      ],
    );
  }
}

// Call this from your main screen after login (for example, in initState or after user logs in).
Future<void> requestPermissionsSequence(BuildContext context) async {
  final localAuth = LocalAuthentication();

  // 1) Biometrics (check availability) - optional to prompt setup
  try {
    final canBio = await localAuth.canCheckBiometrics;
    final isSupported = await localAuth.isDeviceSupported();
    if (canBio && isSupported) {
      // Optionally run a quick authenticate to enroll/confirm biometric
      // You may skip forcing authenticate here — just check availability
      // final ok = await localAuth.authenticate(localizedReason: 'Unlock to enable biometric check-in');
    }
  } catch (_) {}

  // 2) Foreground Location
  var status = await Permission.locationWhenInUse.status;
  if (!status.isGranted) {
    final r = await Permission.locationWhenInUse.request();
    status = r;
  }

  // 3) If foreground granted, consider requesting background location (separate step)
  if (status.isGranted) {
    // Background location must be requested separately on Android; on iOS you request Always from settings sometimes
    if (await Permission.locationAlways.isDenied) {
      // Show another dialog to explain background tracking and then request
      final granted = await Permission.locationAlways.request();
      if (!granted.isGranted) {
        // On many devices the user must enable always from settings after initial denial
      }
    }
  }

  // 4) Notifications (Android 13+)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // 5) Suggest user whitelist battery optimizations (Android)
  // Can't force; open the settings page
  try {
    const intent = AndroidIntent(action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS');
    await intent.launch();
  } catch (_) {}

  // 6) Final validation: confirm location service enabled
  final gpsOn = await Geolocator.isLocationServiceEnabled();
  if (!gpsOn) {
    // show instructions to enable device location
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable Device Location (GPS) for accurate check-in.')),
      );
    }
  }

  // Optionally store a flag in SharedPreferences that onboarding was completed
}
