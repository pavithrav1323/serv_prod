import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A scaffold that always keeps the bottom nav above
/// gesture/3-button areas with a guaranteed extra gap.
class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final BottomNavigationBar? bottomNav;

  const AppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNav,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // true system padding under the bottom system bar
    final sysBottom = mq.viewPadding.bottom; // works for both gesture & 3-button
    // add a little extra so it never kisses the glass on weird ROMs
    final enforcedGap = math.max(16.0, sysBottom + 8.0);

    return Scaffold(
      extendBody: false,     // don't draw under system bars
      extendBodyBehindAppBar: false,
      appBar: appBar,
      body: body,
      bottomNavigationBar: bottomNav == null
          ? null
          : SafeArea(
              // keep top rounded corners from touching content
              minimum: const EdgeInsets.only(top: 8),
              bottom: false, // we handle bottom with padding below
              child: Padding(
                // ← this is the whole trick
                padding: EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: enforcedGap,
                ),
                child: bottomNav!,
              ),
            ),
    );
  }
}
