import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'attendance_page.dart';
import 'profile_page.dart';
import 'package:serv_app/Pagesusers/myserv_page.dart';

// App Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

class HomeScreen extends StatefulWidget {
  final String userName;
  final String employeeDocId;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.employeeDocId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationPermissionDialog();
    });
  }

  Future<void> _showLocationPermissionDialog() async {
    final status = await Permission.location.status;
    if (status.isDenied) {
      if (!mounted) return;
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: const Text(
            'We need your permission',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To provide the best experience, we need the following permissions:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _buildPermissionItem(
                icon: Icons.location_on_outlined,
                title: 'Location',
                description: 'To track your attendance and location during work hours',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 12),
              _buildPermissionItem(
                icon: Icons.camera_alt_outlined,
                title: 'Camera',
                description: 'To take photos for attendance and documentation',
                color: const Color(0xFF2196F3),
              ),
              const SizedBox(height: 12),
              _buildPermissionItem(
                icon: Icons.storage_outlined,
                title: 'Storage',
                description: 'To store and retrieve photos and documents',
                color: const Color(0xFFFF9800),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Not Now',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _requestPermissions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kButtonColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                elevation: 0,
              ),
              child: const Text(
                'Allow All',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _requestPermissions() async {
    // Request location permission
    var status = await Permission.location.request();
    if (status.isGranted) {
      // Request camera permission
      await Permission.camera.request();
      // Request storage permission
      await Permission.storage.request();
    }
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overlay = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: kAppBarColor,
      systemNavigationBarIconBrightness: Brightness.light,
    );

    final size = MediaQuery.of(context).size;
    final isShort = size.height < 650;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // ======= Enhanced Background (soft shapes) =======
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
                ),
              ),
            ),
            Positioned(
              top: -80,
              left: -60,
              child: _BlobCircle(
                diameter: 220,
                color: kAppBarColor.withOpacity(0.10),
              ),
            ),
            Positioned(
              top: 140,
              right: -70,
              child: _BlobCircle(
                diameter: 180,
                color: kButtonColor.withOpacity(0.08),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: _BlobCircle(
                diameter: 160,
                color: kAppBarColor.withOpacity(0.07),
              ),
            ),
            // ======= Page Content =======
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with transparent background
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),  // Increased padding
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),  // Slightly larger radius
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 6,  // Slightly more pronounced shadow
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logobg.png',
                            height: 48,  // Increased from 36
                            fit: BoxFit.contain,
                          ),
                        ),
                        const Spacer(),
                        const _HeaderIcon(icon: Icons.location_on),
                        const SizedBox(width: 14),
                        const _HeaderIcon(icon: Icons.warning),
                        const SizedBox(width: 14),
                        const _HeaderIcon(icon: Icons.person),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),

                        // Greeting — animated appear
                        _FadeSlide(
                          delayMs: 50,
                          child: Column(
                            children: [
                              Text(
                                'Hello, ${widget.userName}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'With SERV, You Deserve the Best',
                                style: TextStyle(
                                  color: Color(0xFF8C6EAF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Illustration
                        _FadeSlide(
                          delayMs: 200,
                          child: Image.asset(
                            'assets/images/attendance-management.png',
                            width: MediaQuery.of(context).size.width * 0.78,
                            height: MediaQuery.of(context).size.height < 650 ? 230 : 300,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Tiles row — animated
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: _FadeSlide(
                            delayMs: 280,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _HomeTile(
                                  icon: Icons.calendar_month,
                                  label: 'Attendance',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AttendanceScreen(
                                          employeeDocId: widget.employeeDocId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                _HomeTile(
                                  icon: Icons.handshake,
                                  label: 'My Serv',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const MyServPage(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Spacer to keep distance from footer
                        SizedBox(height: isShort ? 8 : 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ---------- Footer ----------
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            height: 50,
            decoration: const BoxDecoration(color: kAppBarColor),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const BottomNavItem(icon: Icons.home, label: 'Home'),
                BottomNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfilePage(userData: {
                          'name': widget.userName,
                          'id': widget.employeeDocId,
                        }),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Decorative soft circle ----------
class _BlobCircle extends StatelessWidget {
  final double diameter;
  final Color color;
  const _BlobCircle({required this.diameter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.35),
            blurRadius: 40,
            spreadRadius: 6,
          ),
        ],
      ),
    );
  }
}

// ---------- Header icon chip ----------
class _HeaderIcon extends StatelessWidget {
  final IconData icon;
  const _HeaderIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,  // Increased from 34
      height: 42, // Increased from 34
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.black87, size: 24), // Increased from 18
    );
  }
}

// ---------- Fade & slight slide-in (stateless utility) ----------
class _FadeSlide extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const _FadeSlide({required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: Future.delayed(Duration(milliseconds: delayMs)),
      builder: (context, snapshot) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 12),
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

// ---------- Small square tile widget ----------
class _HomeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final tileW = size.width * 0.36;
    final tileH = size.height < 650 ? 98.0 : 112.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: kAppBarColor.withOpacity(0.15),
        highlightColor: kButtonColor.withOpacity(0.10),
        child: Ink(
          width: tileW,
          height: tileH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                kPrimaryBackgroundBottom.withOpacity(0.95),
                kPrimaryBackgroundBottom.withOpacity(0.80),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.6), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 44, color: kAppBarColor),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Footer item ----------
class BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const BottomNavItem({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 86,
        height: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kTextColor, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: kTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
