import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

import 'package:serv_app/models/company_data.dart';

// Background scheduler (WorkManager wrapper)
import 'package:serv_app/background/background_tasks.dart';
import 'package:serv_app/main.dart' show startFgTracking, stopFgTracking;
// Foreground timer (legacy – extra backup)
import 'package:serv_app/services/tracking_service.dart';

// 🔹 Firestore for dynamic shift times
import 'package:cloud_firestore/cloud_firestore.dart';

// ==== Colors ====
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// ---- API base ----
const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

// ---- Local persistence keys ----
const String _kCheckedInKeyBase = 'att_checked_in_';
const String _kCheckInDateKeyBase = 'att_checkin_date_';
const String _kCheckInTimeKeyBase = 'att_checkin_time_';

class ShiftTimes {
  final TimeOfDay start;
  final TimeOfDay end;
  const ShiftTimes(this.start, this.end);
}

class _Branch {
  final String name;
  final double lat;
  final double lng;
  final double radius;
  const _Branch(this.name, this.lat, this.lng, this.radius);
}

class AttendanceScreen extends StatefulWidget {
  final String employeeDocId;
  const AttendanceScreen({super.key, required this.employeeDocId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with WidgetsBindingObserver {
  bool isFaceRegistered = false;
  bool isShiftSelected = false;
  bool isCheckedIn = false;
  bool isTimerRunning = false;
  bool _locationPermissionGranted = false;

  // ✅ FIX: prevent multiple checkout taps / duplicate API calls
  bool _checkoutInProgress = false;

  // Track check-in and check-out times (for UI labels only)
  DateTime? _checkInTime;
  DateTime? _checkOutTime;

  // Format time for display (HH:MM AM/PM)
  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $amPm';
  }

  String userName = "";
  String userId = ""; // empid
  String dept = "";
  String location = "";

  String selectedShift = "Shift";
  bool shiftClicked = false;

  Timer? _timer;

  int totalSeconds = 0;
  String hours = "00";
  String minutes = "00";
  String seconds = "00";

  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _authInProgress = false;

  // remember the source of today's check-in ('biometric' | 'manual')
  String _checkInSource = '';

  // Optional legacy foreground tracker
  TrackingService? _tracking;

  // 🔹 cache the dynamic shift times loaded from Firestore
  ShiftTimes? _shiftTimes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserInfo();
    _checkUserFaceRegistration();
    _requestBackgroundLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_authInProgress) return;
      _restoreCheckInFromPrefs().then((_) => _loadTodayStatus());
    }
  }

  Map<String, String> _authHeaders() {
    final token = CompanyData.token;
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();
  String _key(String base) => '$base$userId';

  Future<void> _saveCheckInToPrefs({DateTime? at}) async {
    if (userId.isEmpty) return;
    final prefs = await _prefs();
    final now = at ?? DateTime.now();
    final ymd =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hms =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    await prefs.setBool(_key(_kCheckedInKeyBase), true);
    await prefs.setString(_key(_kCheckInDateKeyBase), ymd);
    await prefs.setString(_key(_kCheckInTimeKeyBase), hms);
  }

  Future<void> _clearCheckInFromPrefs() async {
    if (userId.isEmpty) return;
    final prefs = await _prefs();
    await prefs.remove(_key(_kCheckedInKeyBase));
    await prefs.remove(_key(_kCheckInDateKeyBase));
    await prefs.remove(_key(_kCheckInTimeKeyBase));
  }

  Future<void> _restoreCheckInFromPrefs() async {
    if (userId.isEmpty) return;
    final prefs = await _prefs();
    final locallyCheckedIn = prefs.getBool(_key(_kCheckedInKeyBase)) ?? false;
    final dateStr = prefs.getString(_key(_kCheckInDateKeyBase));
    final timeStr = prefs.getString(_key(_kCheckInTimeKeyBase));
    if (!locallyCheckedIn || dateStr == null || timeStr == null) return;

    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (dateStr != todayStr) {
      await _clearCheckInFromPrefs();
      return;
    }

    if (!mounted) return;
    setState(() {
      isCheckedIn = true;
      isTimerRunning = true;
    });

    try {
      final hms = timeStr.split(':');
      final inDT = DateTime(
        today.year,
        today.month,
        today.day,
        int.parse(hms[0]),
        int.parse(hms[1]),
        int.parse(hms[2]),
      );
      final diff = DateTime.now().difference(inDT).inSeconds;
      totalSeconds = diff > 0 ? diff : 0;
    } catch (_) {
      totalSeconds = 0;
    }
    hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    seconds = (totalSeconds % 60).toString().padLeft(2, '0');

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        totalSeconds++;
        hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
        minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
        seconds = (totalSeconds % 60).toString().padLeft(2, '0');
      });
    });
  }

  Future<void> _loadUserInfo() async {
    final token = CompanyData.token;
    final url = Uri.parse('$_apiBase/auth/me');

    try {
      final res =
          await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final profile = (data['employeeProfile'] is Map<String, dynamic>)
            ? (data['employeeProfile'] as Map<String, dynamic>)
            : <String, dynamic>{};

        setState(() {
          userName = (data['name'] ?? profile['name'] ?? "") as String;
          userId = (data['empid'] ?? profile['empid'] ?? "") as String;
          dept = (profile['dept'] ?? data['dept'] ?? "") as String;
          location = (profile['location'] ?? data['location'] ?? "") as String;
          selectedShift = (profile['shiftGroup'] ??
              data['shiftGroup'] ??
              "Shift") as String;

          final hasShift = selectedShift.isNotEmpty && selectedShift != "Shift";
          shiftClicked = hasShift;
          isShiftSelected = hasShift;
        });

        await _loadShiftTimes();

        await _restoreCheckInFromPrefs();
        await _loadTodayStatus();
      } else {
        setState(() {
          userName = "(unknown)";
          userId = widget.employeeDocId;
          dept = "";
          location = "";
        });
        await _restoreCheckInFromPrefs();
      }
    } catch (_) {
      setState(() {
        userName = "(error)";
        userId = widget.employeeDocId;
        dept = "";
        location = "";
      });
      await _restoreCheckInFromPrefs();
    }
  }

  Future<void> _loadTodayStatus() async {
    final token = CompanyData.token;
    if (userId.isEmpty || token.isEmpty) return;

    final url = Uri.parse('$_apiBase/attendance/live');

    try {
      final res =
          await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode != 200) return;

      final list = List<Map<String, dynamic>>.from(jsonDecode(res.body));
      final me = list.firstWhere(
        (e) => (e['empid']?.toString() ?? '') == userId,
        orElse: () => const {},
      );

      final checkIn = (me['checkIn']) as String?;
      final checkOut = (me['checkOut']) as String?;
      _checkInSource =
          (me['checkInSource'] ?? me['source'] ?? '').toString().toLowerCase();

      if (checkOut != null && checkOut.isNotEmpty) {
        _resetTimerAndState();
        await _clearCheckInFromPrefs();
        if (!mounted) return;
        setState(() {
          isCheckedIn = false;
          _checkInSource = '';
        });
        return;
      }

      if (checkIn != null && checkIn.isNotEmpty) {
        _applyCheckedInFromServer(checkIn);
        await _saveCheckInToPrefs();
        return;
      }

      _resetTimerAndState();
      await _clearCheckInFromPrefs();
      if (!mounted) return;
      setState(() {
        isCheckedIn = false;
        _checkInSource = '';
      });
    } catch (_) {}
  }

  void _applyCheckedInFromServer(String hhmmss) {
    try {
      final now = DateTime.now();
      final parts = hhmmss.split(':').map((s) => int.tryParse(s) ?? 0).toList();
      _checkInTime = DateTime(now.year, now.month, now.day, parts[0], parts[1],
          parts.length > 2 ? parts[2] : 0);
      _checkOutTime = null;

      final inDT = DateTime(
        now.year,
        now.month,
        now.day,
        parts[0],
        parts[1],
        parts[2],
      );
      final diff = now.difference(inDT).inSeconds;
      final startSeconds = diff > 0 ? diff : 0;

      _timer?.cancel();
      setState(() {
        isCheckedIn = true;
        isTimerRunning = true;
        totalSeconds = startSeconds;
        hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
        minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
        seconds = (totalSeconds % 60).toString().padLeft(2, '0');
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          totalSeconds++;
          hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
          minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
          seconds = (totalSeconds % 60).toString().padLeft(2, '0');
        });
      });
    } catch (_) {
      _startWorkTimer();
      setState(() => isCheckedIn = true);
    }
  }

  void _resetTimerAndState() {
    _timer?.cancel();
    _timer = null; // ✅ FIX: ensure timer is fully stopped
    setState(() {
      isCheckedIn = false;
      isTimerRunning = false;
      totalSeconds = 0;
      hours = "00";
      minutes = "00";
      seconds = "00";
    });
  }

  Future<void> _checkUserFaceRegistration() async {
    setState(() => isFaceRegistered = false);
  }

  bool _isOpenShift(String s) {
    final name = (s).trim().toLowerCase();
    return name.contains('open');
  }

  String _todayYmd() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ✅ UPDATED ONLY: retry logic + fallback accuracy + exact error messages (no UI flow change)
  Future<Position?> _getPositionUsingDemo({
    bool quiet = false,
    LocationAccuracy accuracy = LocationAccuracy.best,
  }) async {
    final hasPermission = await _ensurePermissionDemo(quiet: quiet);
    if (!hasPermission) return null;

    // Important: stop immediately if location services are OFF (previous code only showed snackbar)
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!quiet && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
      }
      return null;
    }

    // Fallback chain: try requested accuracy -> high -> medium
    final List<LocationAccuracy> accuracyChain = <LocationAccuracy>[
      accuracy,
      if (accuracy != LocationAccuracy.high) LocationAccuracy.high,
      if (accuracy != LocationAccuracy.medium) LocationAccuracy.medium,
    ];

    // Retry: total attempts = 2 rounds across the chain (helps random GPS delays)
    const int rounds = 2;

    String lastReadableError = 'Unknown error';
    Object? lastErrorObj;

    Future<Position?> attempt(LocationAccuracy acc, Duration timeout) async {
      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: acc,
          timeLimit: timeout,
        );
      } on TimeoutException catch (e) {
        lastReadableError =
            'Timed out while fetching location (accuracy: ${acc.name}). Please move to an open area and try again.';
        lastErrorObj = e;
        return null;
      } on LocationServiceDisabledException catch (e) {
        lastReadableError =
            'Location services are turned off. Please enable GPS/location services.';
        lastErrorObj = e;
        return null;
      } on PermissionDeniedException catch (e) {
        lastReadableError =
            'Location permission is denied. Please allow location permission.';
        lastErrorObj = e;
        return null;
      } on Exception catch (e) {
        // Covers platform-specific exceptions from Geolocator
        lastReadableError =
            'Could not get current location (accuracy: ${acc.name}). ${e.toString()}';
        lastErrorObj = e;
        return null;
      } catch (e) {
        lastReadableError =
            'Could not get current location (accuracy: ${acc.name}). ${e.toString()}';
        lastErrorObj = e;
        return null;
      }
    }

    for (int r = 0; r < rounds; r++) {
      for (final acc in accuracyChain) {
        // Longer timeouts for high/best; shorter for medium
        final timeout = (acc == LocationAccuracy.medium)
            ? const Duration(seconds: 20)
            : const Duration(seconds: 40);

        final pos = await attempt(acc, timeout);
        if (pos != null) return pos;

        // small delay between attempts to allow GPS to warm up
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // If we reach here, all attempts failed — show the exact reason
    if (!quiet && mounted) {
      final msg = lastReadableError;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }

    // Optional: debug print (does not affect UI flow)
    // ignore: avoid_print
    print('Location fetch failed: $lastReadableError | error=$lastErrorObj');

    return null;
  }

  Future<void> _requestBackgroundLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always) {
      setState(() {
        _locationPermissionGranted = true;
      });
      return;
    }

    if (!mounted) return;

    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'Background Location Access',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To track your work hours accurately, please allow background location access.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              icon: Icons.location_on_outlined,
              title: 'Background Location',
              description:
                  'To track your work hours even when the app is in the background',
              color: const Color(0xFF4CAF50),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please select "Allow all the time" when prompted',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    if (shouldRequest == true && mounted) {
      await openAppSettings();
      permission = await Geolocator.checkPermission();

      if (mounted) {
        setState(() {
          _locationPermissionGranted = permission == LocationPermission.always;
        });

        if (permission != LocationPermission.always) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Please enable "Allow all the time" for location access'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        }
      }
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
      margin: const EdgeInsets.only(bottom: 12),
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
                const SizedBox(height: 4),
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

  Future<bool> _ensurePermissionDemo({bool quiet = false}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (quiet) return false;
      if (!mounted) return false;

      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
              'Please enable location services to use this feature.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                await Geolocator.openLocationSettings();
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (go != true) return false;
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (quiet) return false;
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted && !quiet) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Location permissions are required for this feature')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (quiet) return false;
      if (!mounted) return false;

      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
              'Location permissions are permanently denied. Please enable them in app settings.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                await Geolocator.openAppSettings();
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (go != true) return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<_Branch?> _fetchMyBranch() async {
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/office/locations'),
        headers: _authHeaders(),
      );
      if (res.statusCode != 200) return null;
      final list = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      final match = list.firstWhere(
        (m) =>
            (m['branchName'] ?? m['name'] ?? '')
                .toString()
                .trim()
                .toLowerCase() ==
            location.trim().toLowerCase(),
        orElse: () => const {},
      );
      if (match.isEmpty) return null;
      final lat = (match['latitude'] as num).toDouble();
      final lng = (match['longitude'] as num).toDouble();
      final rad = (match['radius'] as num).toDouble();
      final nm = (match['branchName'] ?? match['name'] ?? '').toString();
      return _Branch(nm, lat, lng, rad);
    } catch (_) {
      return null;
    }
  }

  double _distanceMeters({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  Future<bool> _confirmOutside(
    double distance,
    double radius,
    String branchName,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Other location'),
            content: const Text(
              'You are in other location. Do you want to proceed with check-in here?',
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Proceed')),
            ],
          ),
        ) ??
        false;
  }

  String? _detectCheckInCategory() {
    if (_isOpenShift(selectedShift)) return null;

    final times = _getShiftTimes(selectedShift);
    final now = DateTime.now();
    final start = _toDateTime(times.start);

    final graceEnd = start.add(const Duration(minutes: 5));
    if (now.isAfter(graceEnd)) return 'Late Check-in';
    return null;
  }

  String? _detectCheckoutCategory() {
    if (_isOpenShift(selectedShift)) return null;

    final times = _getShiftTimes(selectedShift);
    var end = _toDateTime(times.end);
    final start = _toDateTime(times.start);
    if (end.isBefore(start)) end = end.add(const Duration(days: 1));

    final now = DateTime.now();
    if (now.isBefore(end)) {
      return 'Early Checkout';
    }

    final graceEnd = end.add(const Duration(minutes: 5));
    if (now.isAfter(graceEnd)) {
      return 'Late Checkout';
    }

    return null;
  }

  Future<List<Map<String, String>>> _fetchAllReasons() async {
    try {
      final res = await http.get(Uri.parse('$_apiBase/reasons?limit=200'));
      if (res.statusCode != 200) return <Map<String, String>>[];

      final body = jsonDecode(res.body);
      final List items =
          (body is List) ? body : (body['items'] as List? ?? <dynamic>[]);

      return items
          .map<Map<String, String>>((raw) {
            final m = (raw as Map).cast<String, dynamic>();
            return {
              'id': (m['id'] ?? m['_id'] ?? '').toString(),
              'reason': (m['reason'] ?? '').toString(),
              'typeId': (m['typeId'] ?? '').toString(),
              'typeName': (m['typeName'] ?? '').toString(),
            };
          })
          .where((e) => (e['reason'] ?? '').toString().isNotEmpty)
          .toList();
    } catch (_) {
      return <Map<String, String>>[];
    }
  }

  Future<Map<String, String>?> _pickReason(String title,
      {String? prefer}) async {
    final reasons = await _fetchAllReasons();
    if (reasons.isEmpty) {
      _showInfoDialog('No reasons configured.');
      return null;
    }

    String? selectedId;
    if ((prefer ?? '').isNotEmpty) {
      final match = reasons.firstWhere(
        (r) =>
            (r['reason'] ?? '').toLowerCase().contains(prefer!.toLowerCase()),
        orElse: () => reasons.first,
      );
      selectedId = match['id'];
    } else {
      selectedId = reasons.first['id'];
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(title),
          content: DropdownButtonFormField<String>(
            initialValue: selectedId,
            isExpanded: true,
            items: reasons
                .map((r) => DropdownMenuItem(
                      value: r['id'],
                      child: Text(r['reason'] ?? ''),
                    ))
                .toList(),
            onChanged: (v) => setSt(() => selectedId = v),
            decoration: const InputDecoration(
              labelText: 'Select reason',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedId == null ? null : () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );

    if (selectedId == null) return null;
    final chosen = reasons.firstWhere((r) => r['id'] == selectedId);
    final chosenText = (chosen['reason'] ?? '').toLowerCase();

    if (chosenText.contains('other')) {
      final controller = TextEditingController();
      String? typed;
      await showDialog(
        context: context,
        builder: (c) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: TextField(
                      controller: controller,
                      maxLines: 5,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Type your reason',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final v = controller.text.trim();
                          if (v.isNotEmpty) {
                            typed = v;
                            Navigator.pop(c);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      if (typed == null || typed!.isEmpty) return null;

      return {
        'reasonId': '',
        'reasonText': typed!,
        'reasonTypeId': chosen['typeId'] ?? '',
        'reasonTypeName': chosen['typeName'] ?? '',
      };
    }

    return {
      'reasonId': chosen['id'] ?? '',
      'reasonText': chosen['reason'] ?? '',
      'reasonTypeId': chosen['typeId'] ?? '',
      'reasonTypeName': chosen['typeName'] ?? '',
    };
  }

  Future<void> _authenticateAndCheckIn() async {
    try {
      _authInProgress = true;

      final canBio = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canBio && !supported) {
        _showErrorDialog('Biometric not available on this device');
        return;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate to check in',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (ok) {
        if (mounted) await _performCheckIn('biometric');
      } else {
        _showInfoDialog('Authentication cancelled');
      }
    } catch (e) {
      _showErrorDialog('Auth error: $e');
    } finally {
      _authInProgress = false;
    }
  }

  Future<void> _performCheckIn(String type) async {
    Map<String, String>? reasonInfo;
    final category = _detectCheckInCategory();
    if (category != null) {
      reasonInfo = await _pickReason(category, prefer: category);
      if (category.isNotEmpty && reasonInfo == null) return;
    }

    final pos = await _getPositionUsingDemo(
      accuracy: LocationAccuracy.bestForNavigation,
    );
    if (pos == null) return;

    final branch = await _fetchMyBranch();

    bool within = true;
    double distance = 0.0;
    String branchName = location;
    double expLat = 0, expLng = 0, expRad = 0;

    if (branch != null) {
      branchName = branch.name;
      expLat = branch.lat;
      expLng = branch.lng;
      expRad = branch.radius;
      distance = _distanceMeters(
        lat1: pos.latitude,
        lng1: pos.longitude,
        lat2: branch.lat,
        lng2: branch.lng,
      );
      within = distance <= branch.radius;

      if (!within) {
        final ok = await _confirmOutside(distance, branch.radius, branch.name);
        if (!ok) return;
      }
    } else {
      final ok = await _confirmOutside(
        0,
        0,
        location.isEmpty ? 'Unknown' : location,
      );
      if (!ok) return;
      within = false;
    }

    final token = CompanyData.token;
    final url = Uri.parse('$_apiBase/attendance/check-in');

    final bodyMap = {
      'empid': userId,
      'name': userName,
      'location': location,
      'latitude': pos.latitude,
      'longitude': pos.longitude,
      'accuracy': pos.accuracy,
      'source': type,
      'branchName': branchName,
      'expectedLatitude': expLat,
      'expectedLongitude': expLng,
      'expectedRadius': expRad,
      'distanceFromBranch': double.parse(distance.toStringAsFixed(2)),
      'withinRadius': within,
      'otherLocation': !within,
      if (reasonInfo != null) 'reasonId': reasonInfo['reasonId'],
      if (reasonInfo != null) 'reasonText': reasonInfo['reasonText'],
      if (reasonInfo != null) 'reasonTypeId': reasonInfo['reasonTypeId'],
      if (reasonInfo != null) 'reasonTypeName': reasonInfo['reasonTypeName'],
    };

    final prevState = (
      wasCheckedIn: isCheckedIn,
      wasTimerRunning: isTimerRunning,
      prevSeconds: totalSeconds,
      prevH: hours,
      prevM: minutes,
      prevS: seconds
    );

    final now = DateTime.now();
    setState(() {
      isCheckedIn = true;
      _checkInSource = type.toLowerCase();
      _checkInTime = now;
      _checkOutTime = null;
    });
    _startWorkTimer();
    await _saveCheckInToPrefs();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking in… syncing in background')),
    );

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyMap),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        unawaited(_trackingCheckInAndSeed(pos));
        unawaited(_ensureNotificationPermission());
        unawaited(_maybePromptBatteryOptimization());
        unawaited(startFgTracking(empid: userId, token: CompanyData.token));
        unawaited(scheduleBackgroundTracking(
            empid: userId, token: CompanyData.token));
        _tracking ??= TrackingService(
          apiBase: _apiBase,
          jwtToken: CompanyData.token,
          empId: userId,
        );
        unawaited(_tracking!.startAfterCheckIn());

        _showSuccessDialog('Checked in successfully!');
      } else {
        final msg =
            (jsonDecode(res.body)['error'] ?? jsonDecode(res.body)['message'])
                .toString();
        await _rollbackAfterFailedCheckIn(
          wasCheckedIn: prevState.wasCheckedIn,
          wasTimerRunning: prevState.wasTimerRunning,
          prevSeconds: prevState.prevSeconds,
          prevH: prevState.prevH,
          prevM: prevState.prevM,
          prevS: prevState.prevS,
        );
        setState(() => _checkInSource = '');
        _showErrorDialog(msg);
      }
    } catch (e) {
      await _rollbackAfterFailedCheckIn(
        wasCheckedIn: prevState.wasCheckedIn,
        wasTimerRunning: prevState.wasTimerRunning,
        prevSeconds: prevState.prevSeconds,
        prevH: prevState.prevH,
        prevM: prevState.prevM,
        prevS: prevState.prevS,
      );
      setState(() => _checkInSource = '');
      _showErrorDialog('Network error: $e');
    }
  }

  Future<void> _rollbackAfterFailedCheckIn({
    required bool wasCheckedIn,
    required bool wasTimerRunning,
    required int prevSeconds,
    required String prevH,
    required String prevM,
    required String prevS,
  }) async {
    await _clearCheckInFromPrefs();
    _timer?.cancel();
    setState(() {
      isCheckedIn = wasCheckedIn;
      isTimerRunning = wasTimerRunning;
      totalSeconds = prevSeconds;
      hours = prevH;
      minutes = prevM;
      seconds = prevS;
    });
  }

  Future<void> _authenticateAndCheckOut() async {
    try {
      _authInProgress = true;

      final canBio = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (!canBio && !supported) {
        _showErrorDialog('Biometric not available on this device');
        return;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: 'Authenticate to check out',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (ok) {
        _confirmCheckOut(proceedAction: () => _performCheckOut());
      } else {
        _showInfoDialog('Authentication cancelled');
      }
    } catch (e) {
      _showErrorDialog('Auth error: $e');
    } finally {
      _authInProgress = false;
    }
  }

  Future<void> _performCheckOut({bool silent = false}) async {
    // ✅ FIX: block multiple checkout calls
    if (_checkoutInProgress) return;
    _checkoutInProgress = true;

    try {
      Map<String, String>? reasonInfo;
      final category = _detectCheckoutCategory();
      if (category != null) {
        reasonInfo = await _pickReason(category, prefer: category);
        if (category.isNotEmpty && reasonInfo == null) {
          if (!silent) _showInfoDialog('Checkout cancelled');
          return;
        }
      }

      final pos = await _getPositionUsingDemo(
        quiet: silent,
        accuracy: LocationAccuracy.bestForNavigation,
      );
      if (pos == null) {
        if (!silent) _showErrorDialog('Could not determine location');
        return;
      }

      final branch = await _fetchMyBranch();
      bool within = true;
      double distance = 0.0;
      String branchName = location;
      double expLat = 0, expLng = 0, expRad = 0;

      if (branch != null) {
        branchName = branch.name;
        expLat = branch.lat;
        expLng = branch.lng;
        expRad = branch.radius;
        distance = _distanceMeters(
          lat1: pos.latitude,
          lng1: pos.longitude,
          lat2: branch.lat,
          lng2: branch.lng,
        );
        within = distance <= branch.radius;
      }

      final token = CompanyData.token;
      final url = Uri.parse('$_apiBase/attendance/check-out');

      final bodyMap = {
        'empid': userId,
        'location': location,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'accuracy': pos.accuracy,
        'branchName': branchName,
        'expectedLatitude': expLat,
        'expectedLongitude': expLng,
        'expectedRadius': expRad,
        'distanceFromBranch': double.parse(distance.toStringAsFixed(2)),
        'withinRadius': within,
        'otherLocation': !within,
        if (reasonInfo != null) 'reasonId': reasonInfo['reasonId'],
        if (reasonInfo != null) 'reasonText': reasonInfo['reasonText'],
        if (reasonInfo != null) 'reasonTypeId': reasonInfo['reasonTypeId'],
        if (reasonInfo != null) 'reasonTypeName': reasonInfo['reasonTypeName'],
      };

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checking out…')),
        );
      }

      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyMap),
      );

      if (res.statusCode == 200) {
        await stopFgTracking();
        await cancelBackgroundTracking(empid: userId);
        await _tracking?.stopAfterCheckOut();

        _stopWorkTimer();
        await _clearCheckInFromPrefs();
        setState(() {
          isCheckedIn = false;
          _checkOutTime = DateTime.now();
          _checkInSource = '';
        });
        if (!silent) _showSuccessDialog('Checked out successfully!');
        await _trackingCheckOut();
      } else {
        final msg =
            (jsonDecode(res.body)['error'] ?? jsonDecode(res.body)['message'])
                .toString();
        if (!silent) _showErrorDialog(msg);
      }
    } catch (e) {
      if (!silent) {
        _showErrorDialog('Network error: $e');
      }
    } finally {
      // ✅ always release lock
      _checkoutInProgress = false;
    }
  }

  Future<void> _trackingCheckInAndSeed(Position pos) async {
    final token = CompanyData.token;
    if (token.isEmpty || userId.isEmpty) return;
    try {
      final base = 'https://api-zmj7dqloiq-el.a.run.app/api/tracking';

      await http.post(
        Uri.parse('$base/check-in'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-empid': userId,
        },
        body: jsonEncode({}),
      );

      await http.post(
        Uri.parse('$base/pos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-empid': userId,
        },
        body: jsonEncode({'lat': pos.latitude, 'lng': pos.longitude}),
      );
    } catch (_) {}
  }

  Future<void> _trackingCheckOut() async {
    final token = CompanyData.token;
    if (token.isEmpty || userId.isEmpty) return;
    try {
      final base = 'https://api-zmj7dqloiq-el.a.run.app/api/tracking';
      await http.post(
        Uri.parse('$base/check-out'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'x-empid': userId,
        },
        body: jsonEncode({}),
      );
    } catch (_) {}
  }

  Future<void> _ensureNotificationPermission() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<void> _maybePromptBatteryOptimization() async {
    try {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
      );
      await intent.launch();
    } catch (_) {
      try {
        const intent = AndroidIntent(
          action: 'android.settings.IGNORE_BATTERY_OPTIMATION_SETTINGS',
        );
        await intent.launch();
      } catch (_) {}
    }
  }

  void _startWorkTimer() {
    _timer?.cancel();
    setState(() {
      isTimerRunning = true;
      totalSeconds = 0;
      hours = "00";
      minutes = "00";
      seconds = "00";
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        totalSeconds++;
        hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
        minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
        seconds = (totalSeconds % 60).toString().padLeft(2, '0');
      });
    });
  }

  void _stopWorkTimer() {
    final h = hours, m = minutes, s = seconds;
    _resetTimerAndState();
    _showSuccessDialog(
        'Check-out successful!\nWork duration: ${h}h ${m}m ${s}s');
  }

  Future<void> _loadShiftTimes() async {
    try {
      if ((selectedShift).trim().isEmpty || selectedShift == "Shift") {
        _shiftTimes = null;
        return;
      }
      final snap = await FirebaseFirestore.instance
          .collection('shifts')
          .where('shiftname', isEqualTo: selectedShift)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        _shiftTimes = null;
        return;
      }

      final data = snap.docs.first.data();
      final startStr = (data['startTime'] ?? '').toString().trim();
      final endStr = (data['endTime'] ?? '').toString().trim();

      TimeOfDay? start = _parseHHmm(startStr);
      TimeOfDay? end = _parseHHmm(endStr);

      if (start == null || end == null) {
        final nameStr = (data['name'] ?? '').toString();
        final pair = _parseNameRange(nameStr);
        start ??= pair?.start;
        end ??= pair?.end;
      }

      if (start != null && end != null) {
        _shiftTimes = ShiftTimes(start, end);
      } else {
        _shiftTimes = null;
      }
    } catch (_) {
      _shiftTimes = null;
    }
    if (mounted) setState(() {});
  }

  ShiftTimes _getShiftTimes(String shift) {
    if (_shiftTimes != null) return _shiftTimes!;
    return const ShiftTimes(
        TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 18, minute: 0));
  }

  TimeOfDay? _parseHHmm(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    if (h == null || min == null) return null;
    if (h < 0 || h > 23 || min < 0 || min > 59) return null;
    return TimeOfDay(hour: h, minute: min);
  }

  ShiftTimes? _parseNameRange(String s) {
    final m = RegExp(
      r'(\d{1,2})(?:[:\.](\d{1,2}))?\s*(AM|PM)\s*-\s*(\d{1,2})(?:[:\.](\d{1,2}))?\s*(AM|PM)',
      caseSensitive: false,
    ).firstMatch(s);
    if (m == null) return null;

    int h1 = int.parse(m.group(1)!);
    int m1 = int.tryParse(m.group(2) ?? '0') ?? 0;
    final p1 = (m.group(3) ?? '').toUpperCase();

    int h2 = int.parse(m.group(4)!);
    int m2 = int.tryParse(m.group(5) ?? '0') ?? 0;
    final p2 = (m.group(6) ?? '').toUpperCase();

    h1 = _to24h(h1, p1);
    h2 = _to24h(h2, p2);

    return ShiftTimes(
        TimeOfDay(hour: h1, minute: m1), TimeOfDay(hour: h2, minute: m2));
  }

  int _to24h(int h, String period) {
    int hh = h % 12;
    if (period == 'PM') hh += 12;
    return hh;
  }

  DateTime _toDateTime(TimeOfDay tod, {DateTime? base}) {
    final b = base ?? DateTime.now();
    return DateTime(b.year, b.month, b.day, tod.hour, tod.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attendance',
          style: TextStyle(
              color: kTextColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              top: 16,
              right: 16,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(userName,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('$userId | $dept',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'In: ${_formatTime(_checkInTime)}',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isCheckedIn
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Out: ${_formatTime(_checkOutTime)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _checkOutTime != null
                                      ? Colors.red
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                              '${DateTime.now().day.toString().padLeft(2, '0')} ${_getMonthName(DateTime.now().month)} ${DateTime.now().year}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 96,
                  height: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset('assets/images/splash2.jpg',
                        fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTimeBox(hours),
                    const SizedBox(width: 6),
                    const Text(
                      ':',
                      style: TextStyle(
                          fontSize: 20,
                          color: Color.fromARGB(255, 169, 163, 182),
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    _buildTimeBox(minutes),
                    const SizedBox(width: 6),
                    const Text(
                      ':',
                      style: TextStyle(
                          fontSize: 20,
                          color: Color.fromARGB(255, 169, 163, 182),
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    _buildTimeBox(seconds),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                      color: kButtonColor,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text(selectedShift,
                      style: const TextStyle(
                          color: kTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 15),
                if (!isCheckedIn)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _authenticateAndCheckIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kButtonColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.face, color: kTextColor, size: 14),
                                SizedBox(height: 2),
                                Text('Biometric',
                                    style: TextStyle(
                                        color: kTextColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () => _performCheckIn('manual'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kButtonColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.touch_app,
                                    color: kTextColor, size: 14),
                                SizedBox(height: 2),
                                Text('Manual',
                                    style: TextStyle(
                                        color: kTextColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      // ✅ FIX: disable while checkout is in progress
                      onPressed: _checkoutInProgress
                          ? null
                          : () {
                              if (_checkInSource == 'biometric') {
                                _authenticateAndCheckOut();
                              } else {
                                _confirmCheckOut(
                                    proceedAction: () => _performCheckOut());
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B6B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: kTextColor, size: 13),
                          SizedBox(width: 8),
                          Text('Check Out',
                              style: TextStyle(
                                  color: kTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBox(String time) {
    return Container(
      width: 42,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            spreadRadius: 1,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          time,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kButtonColor,
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC'
    ];
    return months[month];
  }

  void _confirmCheckOut({required VoidCallback proceedAction}) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (c) => AlertDialog(
        title: const Text('Check Out'),
        content: Text(
            'Are you sure you want to check out?\nWork duration: ${hours}h ${minutes}m ${seconds}s'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c, rootNavigator: true).pop(),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.of(c, rootNavigator: true).pop();
              proceedAction();
            },
            child: const Text('Check Out'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(String message, {String title = 'Notice'}) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
