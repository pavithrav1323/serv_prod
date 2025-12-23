import 'package:flutter/material.dart';

class AppMessenger {
  // Plug this into MaterialApp.scaffoldMessengerKey
  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void show(String msg) {
    final m = key.currentState;
    if (m == null) return;
    m.clearSnackBars();
    m.showSnackBar(SnackBar(content: Text(msg)));
  }
}
