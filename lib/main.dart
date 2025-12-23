import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'firebase_options.dart'; // ⬅️ uses FlutterFire-generated options

// ✅ Start app at AuthGuard (routes to login/admin/employee based on token/role)
import 'auth/auth_guard.dart';

// Core messenger for global SnackBars/Toasts
import 'core/app_messenger.dart';

// Pages (still available via named routes if you use them elsewhere)
import 'package:serv_app/Pagesusers/login_page.dart';
import 'package:serv_app/Pagesadmin/leave_page.dart';
import 'package:serv_app/Pagesadmin/leave_form_page.dart';
import 'package:serv_app/Pagesusers/landing_screen.dart';

// Background
import 'package:workmanager/workmanager.dart';
import 'package:serv_app/background/background_tasks.dart';

// Connectivity gate
import 'package:serv_app/services/connectivity_service.dart';
import 'package:serv_app/widgets/network_gate.dart';

// ────────────────────────────────────────────────────────────────────────────
// Tiny helper to avoid repeating the platform check
bool get _isAndroid => !kIsWeb && Platform.isAndroid;
// ────────────────────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Workmanager (Android only)
  try {
    if (_isAndroid) {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
    }
  } catch (_) {}

  // Firebase init (+ anonymous auth in case your rules require an auth user)
  try {
    // ✅ Initialize the default Firebase app with FlutterFire options
    final app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized for project: ${app.options.projectId}');
    print('🔑 Using API key: ${app.options.apiKey}');

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
        // ignore: avoid_print
        print('[FirebaseAuth] Anonymous sign-in OK');
        debugPrint('[AUTH] user=${FirebaseAuth.instance.currentUser?.uid}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Anonymous sign-in failed: $e');
    }
  } catch (e) {
    // ignore: avoid_print
    print('Firebase initialization error: $e');
  }

  // Initialize background systems on Android after first frame
  if (_isAndroid) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await initializeBackgroundSystems();
      } catch (e) {
        debugPrint('initializeBackgroundSystems failed: $e');
      }
    });
  }

  // Start connectivity watcher for the whole app
  ConnectivityService.I.start();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData myTheme = ThemeData(
      fontFamily: 'Inter',
      scaffoldBackgroundColor: const Color(0xFFF8F6FF),
      cardColor: Colors.white,

      // App-wide icon defaults
      iconTheme: const IconThemeData(
        color: Color(0xFF0F3D3E),
        size: 24,
      ),

      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 14, color: Colors.black),
      ),

      // ✅ Normalized AppBar + status bar style
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF8C6EAF),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.20,
          letterSpacing: 0.15,
        ),
        toolbarTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.20,
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        actionsIconTheme: IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        // Taller like your original screenshot
        toolbarHeight: 64,
        elevation: 2,
        centerTitle: false,
        // a bit of left padding like the screenshot
        titleSpacing: 16,
        // Ensure status bar icons are light and bar color matches
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Color(0xFF8C6EAF),
          statusBarIconBrightness: Brightness.light, // Android
          statusBarBrightness: Brightness.dark, // iOS
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF655193),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),

      useMaterial3: true,
    );

    return MaterialApp(
      title: 'SERV App',
      debugShowCheckedModeBanner: false,
      theme: myTheme,
      scaffoldMessengerKey: AppMessenger.key, // keep your global messenger

      // Gentle clamp for system text scaling + wrap with global NetworkGate
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scaler =
            media.textScaler.clamp(minScaleFactor: 0.90, maxScaleFactor: 1.15);
        final wrapped = NetworkGate(child: (child ?? const SizedBox.shrink()));
        return MediaQuery(
            data: media.copyWith(textScaler: scaler), child: wrapped);
      },

      // ✅ Start at AuthGuard (routes to login/admin/employee based on token/role)
      home: const AuthGuard(),

      // Optional named routes (still available if used elsewhere)
      routes: {
        '/login': (context) => const LoginPage(),
        '/leave': (context) => const LeavePage(),
        '/add-leave': (context) => const LeaveFormPage(),
        '/landing': (context) => const LandingScreen(),
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Wrappers for background tracking (kept from your first code)
// ────────────────────────────────────────────────────────────────────────────

/// Optional convenience if any file still references an `initBackgroundService()`.
Future<void> initBackgroundService() async {
  if (_isAndroid) {
    await initializeBackgroundSystems();
  }
}

/// Start the foreground tracking (and persist identity)
Future<void> startFgTracking({
  required String empid,
  required String token,
}) async {
  if (!_isAndroid) return;
  try {
    await setTrackingIdentity(empid: empid, token: token);
    await startForegroundTracking();
    // If you also want WorkManager backup to start right away, you can:
    // await scheduleBackgroundTracking(empid: empid, token: token);
  } catch (e) {
    debugPrint('startFgTracking error: $e');
  }
}

/// Stop the foreground tracking
Future<void> stopFgTracking() async {
  if (!_isAndroid) return;
  try {
    await stopForegroundTracking();
    // If you scheduled WorkManager backup on start, cancel here as needed.
  } catch (e) {
    debugPrint('stopFgTracking error: $e');
  }
}
