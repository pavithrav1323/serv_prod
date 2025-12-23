// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android: return android;
      case TargetPlatform.iOS:     return ios;
      case TargetPlatform.macOS:   return ios;     // ok to reuse in dev
      case TargetPlatform.windows: return web;     // ok to reuse in dev
      case TargetPlatform.linux:   return web;     // ok to reuse in dev
      default:                     return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCdlqOlxgqLHaeiT43_rWd2p2XWbPloBAI',
    appId: '1:227341863889:web:3fcef372ec7a14af7e6ef0',
    messagingSenderId: '227341863889',
    projectId: 'servappbackend',
    authDomain: 'servappbackend.firebaseapp.com',
    storageBucket: 'servappbackend.firebasestorage.app',
    measurementId: 'G-GY3NN1JZQ5',
  );

  // ---- Fill from Firebase Console Web config ----

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBg_e9D6Kfp8_2uY0VY6Q-k6AxrR5YkMH4',
    appId: '1:227341863889:android:be107e7361c79c947e6ef0',
    messagingSenderId: '227341863889',
    projectId: 'servappbackend',
    storageBucket: 'servappbackend.firebasestorage.app',
  );

  // Optional (fill later if you build these platforms)

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyASfCUwrzdazi3U59d7HYQ29F9lqyyI_ZI',
    appId: '1:227341863889:ios:76c578092aef17337e6ef0',
    messagingSenderId: '227341863889',
    projectId: 'servappbackend',
    storageBucket: 'servappbackend.firebasestorage.app',
    iosBundleId: 'com.serv.servApp',
  );

}