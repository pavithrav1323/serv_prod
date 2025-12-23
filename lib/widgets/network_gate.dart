import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../pages/no_network_page.dart';

/// Wraps the whole app; shows NoNetworkPage when offline.
class NetworkGate extends StatelessWidget {
  final Widget child;
  const NetworkGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.I.online$,
      builder: (context, snap) {
        final online = snap.data ?? true; // default to true on boot
        return online ? child : const NoNetworkPage();
      },
    );
  }
}
