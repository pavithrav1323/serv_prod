// lib/core/firebase_boot.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:serv_app/firebase_options.dart';

/// Call this instead of Firebase.initializeApp() anywhere in the app.
/// - If the default app already exists (auto-init on Android), just return it.
/// - If not, initialize it with your options.
Future<FirebaseApp> ensureDefaultFirebaseApp() async {
  try {
    return Firebase.app(); // already initialized (e.g., by FirebaseInitProvider)
  } on FirebaseException catch (e) {
    if (e.code == 'no-app') {
      return Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    rethrow;
  }
}
