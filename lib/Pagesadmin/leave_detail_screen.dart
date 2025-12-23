import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// If you keep these in a config, you can remove them here.
import 'package:serv_app/models/company_data.dart';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

const String _defaultApiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';
const String apiBase =
    String.fromEnvironment('API_BASE', defaultValue: _defaultApiBase);

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

const double kDefaultRadiusMeters = 100;

class RequestDetailsCard extends StatefulWidget {
  final Map<String, dynamic> data;
  const RequestDetailsCard({super.key, required this.data});

  @override
  State<RequestDetailsCard> createState() => _RequestDetailsCardState();
}

class _RequestDetailsCardState extends State<RequestDetailsCard> {
  final Completer<GoogleMapController> _mapCtrl =
      Completer<GoogleMapController>();
  LatLng? _pendingTarget;
  String? _pendingMarkerId;

  /// Local merged copy of data (what UI reads from)
  late Map<String, dynamic> _data;

  bool _loadingDetails = false;
  String? _loadError;

  /* -------------------- tolerant getters -------------------- */

  double? _toDouble(dynamic v) =>
      v == null ? null : double.tryParse(v.toString().trim());

  bool? _toBool(dynamic v) {
    if (v == null) return null;
    final s = v.toString().toLowerCase().trim();
    if (s == 'true' || s == 'yes' || s == '1') return true;
    if (s == 'false' || s == 'no' || s == '0') return false;
    return null;
  }

  String _pickStr(List<String> keys) {
    for (final k in keys) {
      final v = _data[k] ?? _data[k.toLowerCase()] ?? _data[k.toUpperCase()];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  double? _pickNum(List<String> keys) {
    for (final k in keys) {
      final v = _data[k] ?? _data[k.toLowerCase()] ?? _data[k.toUpperCase()];
      final d = _toDouble(v);
      if (d != null) return d;
    }
    return null;
  }

  /* -------------------- lat/lng parsing helpers -------------------- */

  LatLng? _parseLatLngString(String s) {
    final parts =
        s.split(RegExp(r'[,\s]+')).where((e) => e.isNotEmpty).toList();
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? _latLngFromMap(Map m) {
    double? lat = _toDouble(
      m['latitude'] ??
          m['lat'] ??
          m['Latitude'] ??
          m['Lat'] ??
          m['branchLat'] ??
          m['branch_latitude'],
    );
    double? lng = _toDouble(
      m['longitude'] ??
          m['lng'] ??
          m['lon'] ??
          m['Longitude'] ??
          m['Lng'] ??
          m['branchLng'] ??
          m['branch_longitude'],
    );
    if (lat != null && lng != null) return LatLng(lat, lng);

    try {
      final lat2 = _toDouble(m['geo']?['lat'] ?? m['coords']?['lat']);
      final lng2 = _toDouble(m['geo']?['lng'] ?? m['coords']?['lng']);
      if (lat2 != null && lng2 != null) return LatLng(lat2, lng2);
    } catch (_) {}

    final locStr = m['location']?.toString();
    if (locStr != null && locStr.contains(',')) {
      final ll = _parseLatLngString(locStr);
      if (ll != null) return ll;
    }
    return null;
  }

  LatLng? _latLngFrom(dynamic any) {
    if (any == null) return null;
    if (any is LatLng) return any;
    if (any is Map) return _latLngFromMap(any);
    if (any is String) return _parseLatLngString(any);
    try {
      final lat = _toDouble(any.latitude);
      final lng = _toDouble(any.longitude);
      if (lat != null && lng != null) return LatLng(lat, lng);
    } catch (_) {}
    return null;
  }

  /* -------------------- lat/lng selection -------------------- */

  LatLng? _findRequestLatLng() {
    double? lat =
        _pickNum(['latitude', 'lat', 'requestLatitude', 'requestedLatitude']);
    double? lng = _pickNum(
        ['longitude', 'lng', 'lon', 'requestLongitude', 'requestedLongitude']);
    if (lat != null && lng != null) return LatLng(lat, lng);

    for (final key in [
      'otherLocation',
      'requestLocation',
      'locationObj',
      'requestedLocation',
      'geo',
      'coords'
    ]) {
      final v = _data[key];
      final ll = _latLngFrom(v);
      if (ll != null) return ll;
    }

    for (final key in ['location', 'otherLocation']) {
      final s = _data[key]?.toString();
      if (s != null) {
        final ll = _parseLatLngString(s);
        if (ll != null) return ll;
      }
    }

    lat ??= _pickNum(['checkInLatitude', 'check_in_latitude']);
    lng ??= _pickNum(['checkInLongitude', 'check_in_longitude']);
    if (lat != null && lng != null) return LatLng(lat, lng);

    lat ??= _pickNum(['checkOutLatitude', 'check_out_latitude']);
    lng ??= _pickNum(['checkOutLongitude', 'check_out_longitude']);
    if (lat != null && lng != null) return LatLng(lat, lng);

    return null;
  }

  LatLng? _findBranchCenter() {
    double? lat = _pickNum([
      'expectedLatitude',
      'branchLatitude',
      'officeLatitude',
      'expected_latitude',
      'branchLat',
      'branch_latitude',
    ]);
    double? lng = _pickNum([
      'expectedLongitude',
      'branchLongitude',
      'officeLongitude',
      'expected_longitude',
      'branchLng',
      'branch_longitude',
    ]);
    if (lat != null && lng != null) return LatLng(lat, lng);

    for (final key in [
      'branch',
      'expected',
      'expectedLocation',
      'office',
      'branchCenter',
      'branchLocationObj'
    ]) {
      final v = _data[key];
      final ll = _latLngFrom(v);
      if (ll != null) return ll;
    }

    for (final key in ['branchLocation', 'expectedLocation']) {
      final s = _data[key]?.toString();
      if (s != null) {
        final ll = _parseLatLngString(s);
        if (ll != null) return ll;
      }
    }

    return null;
  }

  /* -------------------- helpers -------------------- */

  double _haversineMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  String _withinRadiusText({
    required LatLng? req,
    required LatLng? center,
    required double? expectedRadius,
    required double? distanceFromBranch,
    required bool? withinFlag,
  }) {
    if (withinFlag != null) return withinFlag ? 'Yes' : 'No';
    if (distanceFromBranch != null && expectedRadius != null) {
      return distanceFromBranch <= expectedRadius ? 'Yes' : 'No';
    }
    if (req != null && center != null && expectedRadius != null) {
      return _haversineMeters(req, center) <= expectedRadius ? 'Yes' : 'No';
    }
    if (req != null && center != null) {
      return _haversineMeters(req, center) <= kDefaultRadiusMeters
          ? 'Yes'
          : 'No';
    }
    return '-';
  }

  Future<void> _focusOn(LatLng target,
      {double zoom = 17, String? markerId}) async {
    if (!_mapCtrl.isCompleted) {
      _pendingTarget = target;
      _pendingMarkerId = markerId;
      return;
    }
    final c = await _mapCtrl.future;
    final cam = CameraPosition(target: target, zoom: zoom);
    try {
      await c.animateCamera(CameraUpdate.newCameraPosition(cam));
    } catch (_) {
      await c.moveCamera(CameraUpdate.newCameraPosition(cam));
    }
    if (markerId != null) {
      await Future.delayed(const Duration(milliseconds: 60));
      try {
        await c.showMarkerInfoWindow(MarkerId(markerId));
      } catch (_) {}
    }
  }

  /* -------------------- API plumbing (local) -------------------- */

  Future<Map<String, String>> _authHeaders({bool json = true}) async {
    String? token = CompanyData.token;
    if ((token!.isEmpty) && kIsWeb) {
      try {
        final t1 = html.window.localStorage['token'];
        final t2 = html.window.sessionStorage['token'];
        token = (t1 != null && t1.isNotEmpty) ? t1 : (t2 ?? token);
      } catch (_) {}
    }
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _inferSrc(Map<String, dynamic> m) {
    final s = (m['source'] ?? m['src'] ?? '').toString().toLowerCase();
    if (s == 'attendance' || s == 'other_location') return s;

    final t = (m['type'] ?? m['category'] ?? '').toString().toLowerCase();
    if (t.contains('other') && t.contains('location')) return 'other_location';
    if (t.contains('late') || t.contains('early')) return 'attendance';
    if (m.containsKey('withinRadius') ||
        m.containsKey('expectedLatitude') ||
        m.containsKey('otherLocation')) {
      return 'other_location';
    }
    return 'attendance';
  }

  Future<void> _fetchAndMergeDetails() async {
    // Prepare query using whatever we have
    String id = (_data['id'] ??
                _data['requestId'] ??
                _data['docId'] ??
                _data['attendanceId'] ??
                _data['otherLocId'])
            ?.toString() ??
        '';
    String empid =
        (_data['empid'] ?? _data['empId'] ?? _data['employeeId'])?.toString() ??
            '';
    String date = (_data['requestDate'] ?? _data['date'] ?? _data['onDate'])
            ?.toString() ??
        '';
    if (date.length > 10) date = date.substring(0, 10);
    final src = _inferSrc(_data);

    if (id.isEmpty && (empid.isEmpty || date.isEmpty)) {
      // Nothing to query with; bail quietly.
      return;
    }

    setState(() {
      _loadingDetails = true;
      _loadError = null;
    });

    try {
      final qp = <String, String>{
        if (id.isNotEmpty) 'id': id,
        if (id.isNotEmpty) 'src': src,
        if (id.isEmpty && empid.isNotEmpty) 'empid': empid,
        if (id.isEmpty && date.isNotEmpty) 'date': date,
      };
      final uri = Uri.parse('$apiBase/attendance/request-details')
          .replace(queryParameters: qp);

      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final body = jsonDecode(res.body);
      if (body is Map<String, dynamic>) {
        setState(() {
          _data = {..._data, ...body};
        });
      }
    } catch (e) {
      // Keep for debugging / logs, but do not show in UI
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);
    // debug
    // ignore: avoid_print
    print('[RequestDetailsCard] keys = ${_data.keys.toList()}');

    // Fetch server-normalized details to ensure we get branch + request coords
    // (does nothing if we don't have enough identifiers)
    // Errors are non-fatal; UI still shows local data.
    unawaited(_fetchAndMergeDetails());
  }

  /* -------------------- UI -------------------- */

  @override
  Widget build(BuildContext context) {
    // Basic fields
    final empId = _pickStr(['empid', 'employeeId', 'id', 'EmpID']);
    final name = _pickStr(['name', 'employeeName']);
    final requestTime = _pickStr([
      'requestTime',
      'time',
      'createdAt',
      'updatedAt',
      'checkInTime',
      'checkOutTime'
    ]);
    final requestDate =
        _pickStr(['requestDate', 'date', 'onDate', 'startDate', 'selectDate']);
    final branchName = _pickStr(['branchName', 'branchLocation', 'location']);
    final freeTextReason =
        _pickStr(['reason', 'otherLocation', 'note', 'remarks']);
    final rejectionRemarks = _pickStr(['rejectionRemarks']);

    // Coordinates from payload (after merge)
    final reqLL = _findRequestLatLng();
    final centerLL = _findBranchCenter();
    final expectedRadius = _pickNum(['expectedRadius', 'radius']);
    final distanceFromBranch =
        _pickNum(['distanceFromBranch', 'distance_from_branch', 'distance']);
    final withinRadiusFlag = _toBool(_data['withinRadius'] ??
        _data['within_radius'] ??
        _data['isWithinRadius'] ??
        _data['insideRadius'] ??
        _data['within'] ??
        _data['inRadius']);

    // Hidden explicit coordinates; show only generic labels on buttons
    final withinRadiusText = _withinRadiusText(
      req: reqLL,
      center: centerLL,
      expectedRadius: expectedRadius,
      distanceFromBranch: distanceFromBranch,
      withinFlag: withinRadiusFlag,
    );

    final distanceText = (distanceFromBranch != null)
        ? distanceFromBranch.toStringAsFixed(0)
        : '-';

    // Map target preference
    final LatLng initialTarget =
        reqLL ?? centerLL ?? const LatLng(20.5937, 78.9629); // India center
    final double initialZoom = (reqLL != null || centerLL != null) ? 17 : 4;

    // Markers/circles
    final Set<Marker> markers = {
      if (reqLL != null)
        const Marker(
          markerId: MarkerId('request'),
          // position set below via copyWith for const safety not possible; rebuild directly:
        ),
    };

    final Set<Marker> fullMarkers = {
      if (reqLL != null)
        Marker(
          markerId: const MarkerId('request'),
          position: reqLL,
          infoWindow: const InfoWindow(title: 'Requested location'),
        ),
      if (centerLL != null)
        Marker(
          markerId: const MarkerId('branch'),
          position: centerLL,
          // Show the real branch name on the marker, not on the button
          infoWindow: InfoWindow(
            title: branchName.isNotEmpty ? branchName : 'Branch location',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
    };

    final Set<Circle> circles = {
      if (centerLL != null && expectedRadius != null)
        Circle(
          circleId: const CircleId('geofence'),
          center: centerLL,
          radius: expectedRadius,
          strokeWidth: 2,
          strokeColor: const Color(0x8032CD32),
          fillColor: const Color(0x3032CD32),
        ),
    };

    void focusRequest() {
      if (reqLL != null) _focusOn(reqLL, markerId: 'request');
    }

    void focusExpected() {
      if (centerLL != null) _focusOn(centerLL, markerId: 'branch');
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          backgroundColor: kAppBarColor,
          elevation: 1,
          automaticallyImplyLeading: false,
          title: Text('Employee ID: $empId',
              style: const TextStyle(fontSize: 16, color: kTextColor)),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: kTextColor),
              onPressed: () => Navigator.pop(context)),
        ),
      ),
      body: _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: $_loadError',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loadingDetails) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 4),

            // scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Employee Name', name, 'Request Type',
                        _pickStr(['type', 'category'])),
                    _row('Requested Time', requestTime, 'Request Date',
                        requestDate),
                    _row(
                      'Employee Reason',
                      freeTextReason.isEmpty ? '-' : freeTextReason,
                      'Rejection Remarks',
                      rejectionRemarks.isEmpty ? '-' : rejectionRemarks,
                    ),

                    const SizedBox(height: 12),
                    // ---- Buttons (generic labels) ----
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: reqLL != null ? focusRequest : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kButtonColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.my_location),
                            label: const Text('Requested location'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: centerLL != null ? focusExpected : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8C6EAF),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.place),
                            // 🔒 Always show a generic label here (not the actual branch name)
                            label: const Text('Branch location'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),
                    _row('Within radius', withinRadiusText,
                        'Distance from branch (m)', distanceText),

                    const SizedBox(height: 10),
                    SizedBox(
                      height: 250,
                      child: GoogleMap(
                        onMapCreated: (c) async {
                          if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
                          if (_pendingTarget != null) {
                            final t = _pendingTarget!;
                            final id = _pendingMarkerId;
                            _pendingTarget = null;
                            _pendingMarkerId = null;
                            await Future.microtask(
                                () => _focusOn(t, markerId: id));
                          }
                        },
                        initialCameraPosition: CameraPosition(
                            target: initialTarget, zoom: initialZoom),
                        markers: fullMarkers,
                        circles: circles,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        compassEnabled: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // Bottom action buttons
            SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kButtonColor),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(color: kButtonColor)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'rejected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Reject'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'approved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* -------------------- small UI helpers -------------------- */

  Widget _row(String l1, String v1, String l2, String v2) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _col(l1, v1)),
          Expanded(child: _col(l2, v2)),
        ]),
      );

  Widget _col(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '-' : value,
              style: const TextStyle(color: Colors.black87)),
        ],
      );
}
