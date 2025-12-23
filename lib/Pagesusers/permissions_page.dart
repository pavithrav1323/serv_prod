import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'attendance_page.dart';

// Theme Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);

class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage>
    with WidgetsBindingObserver {
  // Track permission states
  final Map<Permission, bool> _permissionsStatus = {
    Permission.location: false,        // Foreground location
    Permission.locationAlways: false,  // Background location (Android 10+)
    Permission.notification: false,    // Android 13+ runtime
    Permission.camera: false,          // Optional; hide if you removed CAMERA
  };
  
  // Get employeeDocId from route arguments
  String? get _employeeDocId => ModalRoute.of(context)?.settings.arguments as String?;

  bool get _fgGranted => _permissionsStatus[Permission.location] ?? false;
  bool get _bgGranted => _permissionsStatus[Permission.locationAlways] ?? false;
  bool get _notifGranted => _permissionsStatus[Permission.notification] ?? false;

  // If you removed CAMERA from AndroidManifest, set this to false to hide the tile.
  // (You can also auto-hide at runtime; left as a constant for clarity.)
  static const bool _showCameraTile = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncPermissions().then((_) {
      // After syncing permissions, check if we need to request background location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkBackgroundLocationPermission();
      });
    });
  }

  // Check if we need to request background location permission
  Future<void> _checkBackgroundLocationPermission() async {
    if (!mounted) return;
    
    final locationStatus = await Permission.location.status;
    final bgLocationStatus = await Permission.locationAlways.status;
    
    // Show dialog if location is granted but background location is not
    if (locationStatus.isGranted && !bgLocationStatus.isGranted) {
      if (!mounted) return;
      
      // Show dialog explaining why we need background location
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Background Location Required'),
          content: const Text(
            'To track your attendance accurately, SERV needs access to your location even when the app is closed or not in use.\n\n'
            'Please change the location permission to "Allow all the time" in the next screen.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      
      if (shouldOpenSettings == true) {
        await openAppSettings();
        // Re-check permissions after returning from settings
        await _syncPermissions();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncPermissions().then((_) {
        if (mounted) {
          _checkBackgroundLocationPermission();
        }
      });
    }
  }

  Future<void> _syncPermissions() async {
    // Refresh the map atomically
    final entries = Map<Permission, bool>.fromEntries(
      await Future.wait(_permissionsStatus.keys.map((p) async {
        final s = await p.status;
        return MapEntry(p, s.isGranted);
      })),
    );
    if (!mounted) return;
    setState(() {
      _permissionsStatus
        ..clear()
        ..addAll(entries);
    });
  }

  // ======== SWITCH HANDLERS ========

  Future<void> _onTogglePermission(Permission permission, bool wantOn) async {
    if (wantOn) {
      // Request (system dialog)
      final res = await permission.request();

      // Special upgrade path: Background requires Foreground first
      if (permission == Permission.locationAlways && !_fgGranted) {
        if (!mounted) return;
        await _ensureForegroundThenBackground();
      } else {
        if (!mounted) return;
        final isGranted = res.isGranted;
        setState(() => _permissionsStatus[permission] = isGranted);
        
        // If location permission is granted, navigate to attendance page
        if ((permission == Permission.location || permission == Permission.locationAlways) && isGranted) {
          final employeeDocId = _employeeDocId;
          if (mounted && employeeDocId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AttendanceScreen(employeeDocId: employeeDocId),
              ),
            );
          } else if (mounted) {
            // Handle case where employeeDocId is not available
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Employee information not found')),
            );
          }
        }
        
        if (res.isPermanentlyDenied) _showSettingsSnackBar();
      }
    } else {
      // Turning OFF must go via Settings (apps cannot revoke programmatically)
      final confirmed = await _confirmOpenSettings(
        title: 'Change Permission',
        message:
            'To turn OFF ${_getPermissionTitle(permission)}, please use the system App Settings.',
      );
      if (confirmed == true) {
        await openAppSettings();
        await _syncPermissions();
      }
    }
  }

  Future<void> _ensureForegroundThenBackground() async {
    // 1) Foreground Location
    var fg = await Permission.location.status;
    if (!fg.isGranted) {
      final askFg = await Permission.location.request();
      if (!askFg.isGranted) {
        if (!mounted) return;
        setState(() => _permissionsStatus[Permission.location] = false);
        return;
      }
      if (!mounted) return;
      setState(() => _permissionsStatus[Permission.location] = true);
    }

    // 2) Explain why background is needed, then request Background
    final upgrade = await _confirmOpenSettings(
      title: 'Enable Background Location',
      message:
          'Background Location keeps tracking active when SERV is not on screen. '
          'A persistent notification will be shown while tracking.',
      confirmText: 'Enable',
      cancelText: 'Not now',
      openSettingsInstead: false,
    );

    if (upgrade == true) {
      final askBg = await Permission.locationAlways.request();
      if (!mounted) return;
      setState(() => _permissionsStatus[Permission.locationAlways] = askBg.isGranted);
      if (askBg.isPermanentlyDenied) _showSettingsSnackBar();
    }
  }

  Future<void> _ensureNotifications() async {
    final s = await Permission.notification.status;
    if (!s.isGranted) {
      final r = await Permission.notification.request();
      if (!mounted) return;
      setState(() => _permissionsStatus[Permission.notification] = r.isGranted);
      if (!r.isGranted) {
        _showInlineBanner(
          'Notifications are required to show that tracking is active. Please enable them.',
        );
      }
    }
  }

  // ======== UI HELPERS ========

  void _showSettingsSnackBar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Permission blocked. Change it in App Settings.'),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  void _showInlineBanner(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Future<bool?> _confirmOpenSettings({
    required String title,
    required String message,
    String confirmText = 'Open Settings',
    String cancelText = 'Cancel',
    bool openSettingsInstead = true,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelText)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    ).then((ok) async {
      if (ok == true && openSettingsInstead) {
        await openAppSettings();
      }
      return ok;
    });
  }

  String _getPermissionTitle(Permission permission) {
    switch (permission) {
      case Permission.location:
        return 'Location (While using the app)';
      case Permission.locationAlways:
        return 'Background Location';
      case Permission.notification:
        return 'Notifications';
      case Permission.camera:
        return 'Camera';
      default:
        return permission.toString().split('.').last;
    }
  }

  String _getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.location:
        return 'Needed for attendance check-in/out and live map.';
      case Permission.locationAlways:
        return 'Keeps tracking active when SERV is in background (shows a persistent notification).';
      case Permission.notification:
        return 'Required to show that tracking is active and to alert you about attendance.';
      case Permission.camera:
        return 'Optional: for profile capture (hide if not used).';
      default:
        return 'Required for app functionality.';
    }
  }

  IconData _getIcon(Permission permission) {
    switch (permission) {
      case Permission.location:
      case Permission.locationAlways:
        return Icons.location_on;
      case Permission.notification:
        return Icons.notifications_active;
      case Permission.camera:
        return Icons.camera_alt;
      default:
        return Icons.security;
    }
  }

  int _getPermissionPriority(Permission permission) {
    switch (permission) {
      case Permission.location:
        return 1;
      case Permission.locationAlways:
        return 2;
      case Permission.notification:
        return 3;
      case Permission.camera:
        return 4;
      default:
        return 5;
    }
  }

  List<Permission> _getSortedPermissions() {
    final keys = _permissionsStatus.keys.toList();
    // Optionally hide camera tile entirely when not desired
    if (!_showCameraTile) {
      keys.remove(Permission.camera);
    }
    keys.sort((a, b) => _getPermissionPriority(a).compareTo(_getPermissionPriority(b)));
    return keys;
  }

  // ======== WIDGETS ========

  Widget _buildTopBanners() {
    final List<Widget> banners = [];

    // Critical: Notifications required for visible foreground service on Android 13+
    if (!_notifGranted) {
      banners.add(_banner(
        text:
            'Notifications are OFF. They are required to show that tracking is active.',
        color: Colors.orange.shade700,
        actionText: 'Enable',
        onTap: _ensureNotifications,
      ));
    }

    // Recommended: Background Location for reliable tracking off-screen
    if (_fgGranted && !_bgGranted) {
      banners.add(_banner(
        text:
            'Background Location is OFF. Enable it for reliable attendance tracking when the app is not on screen.',
        color: Colors.orange.shade700,
        actionText: 'Enable',
        onTap: _ensureForegroundThenBackground,
      ));
    }

    // Blocking: No Foreground Location → cannot track at all
    if (!_fgGranted) {
      banners.add(_banner(
        text:
            'Location is OFF. Attendance tracking cannot start without Location permission.',
        color: Colors.red.shade700,
        actionText: 'Allow',
        onTap: () => _onTogglePermission(Permission.location, true),
      ));
    }

    if (banners.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: banners),
    );
  }

  Widget _banner({
    required String text,
    required Color color,
    required String actionText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13.5, height: 1.25),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onTap,
            child: Text(actionText),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(Permission permission) {
    final granted = _permissionsStatus[permission] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: granted ? Colors.green.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: granted ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(permission),
                color: granted ? Colors.green : Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getPermissionTitle(permission),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getPermissionDescription(permission),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Switch behaves like other apps: ON=request, OFF=open Settings
            Switch.adaptive(
              value: granted,
              onChanged: (wantOn) async {
                // Background Location must be requested only after foreground is granted
                if (permission == Permission.locationAlways && !_fgGranted && wantOn) {
                  await _ensureForegroundThenBackground();
                  return;
                }
                await _onTogglePermission(permission, wantOn);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _getSortedPermissions();

    // Optionally hide camera tile if you removed CAMERA from the manifest
    final visibleItems = _showCameraTile
        ? items
        : items.where((p) => p != Permission.camera).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Permissions'),
        centerTitle: false,
        backgroundColor: kAppBarColor,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Text(
                'SERV needs these permissions to record attendance accurately and show when tracking is active. '
                'You can change them anytime.',
                style: TextStyle(fontSize: 14.5, height: 1.35, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            _buildTopBanners(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: visibleItems.length,
                itemBuilder: (_, i) => _buildPermissionTile(visibleItems[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
