import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' as MathLib;
import 'package:serv_app/models/company_data.dart';

// ----- Theme -----
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// ---------- Model ----------
class _TrackPoint {
  final double lat;
  final double lng;
  final DateTime ts;
  const _TrackPoint({required this.lat, required this.lng, required this.ts});
  LatLng get ll => LatLng(lat, lng);
}

// Haversine (meters)
double _distM(LatLng a, LatLng b) {
  const R = 6371000.0;
  final dLat = (b.latitude - a.latitude) * (3.141592653589793 / 180.0);
  final dLng = (b.longitude - a.longitude) * (3.141592653589793 / 180.0);
  final s1 = (dLat / 2.0).sin(), s2 = (dLng / 2.0).sin();
  final aa = s1 * s1 +
      (a.latitude * (3.14159 / 180.0)).cos() *
          (b.latitude * (3.14159 / 180.0)).cos() *
          s2 *
          s2;
  final c = 2.0 * aa.sqrt().atan2((1 - aa).sqrt());
  return R * c;
}

extension _NumMath on double {
  double sin() => Math.sin(this);
  double cos() => Math.cos(this);
  double sqrt() => Math.sqrt(this);
  double atan2(double x) => Math.atan2(this, x);
}

class Math {
  static double sin(double x) => MathInternal.sin(x);
  static double cos(double x) => MathInternal.cos(x);
  static double sqrt(double x) => MathInternal.sqrt(x);
  static double atan2(double y, double x) => MathInternal.atan2(y, x);
}

// ignore: avoid_classes_with_only_static_members
class MathInternal {
  static double sin(double x) => MathLib.sin(x);
  static double cos(double x) => MathLib.cos(x);
  static double sqrt(double x) => MathLib.sqrt(x);
  static double atan2(double y, double x) => MathLib.atan2(y, x);
}

class MyTrackPage extends StatefulWidget {
  const MyTrackPage({super.key});
  @override
  State<MyTrackPage> createState() => _MyTrackPageState();
}

class _MyTrackPageState extends State<MyTrackPage> {
  // --- date control ---
  DateTime? selectedDate;
  final TextEditingController dateController = TextEditingController();

  // --- API base/token/empid ---
  final String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app';
  String? _jwt;
  String? _empId;

  // --- Google map state ---
  GoogleMapController? _mapCtrl;
  MapType _mapType = MapType.normal;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  LatLng? _center;

  // show end marker only after checkout
  bool _sessionEnded = false;

  final DateFormat _timeFmt = DateFormat('hh:mm a');

  @override
  void initState() {
    super.initState();
    print('TOKEN: $_jwt EMPID: $_empId');
    _jwt = CompanyData.token;
    _empId = CompanyData.empid;

    final now = DateTime.now();
    selectedDate = now;
    dateController.text =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    _loadAndDrawPath();
  }

  String _dateIso() {
    final d = selectedDate ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List<_TrackPoint> _parseTrackPoints(List<dynamic> raw) {
    final pts = <_TrackPoint>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final lat = (e['lat'] as num?)?.toDouble();
      final lng = (e['lng'] as num?)?.toDouble();
      final tsRaw = e['ts'];
      if (lat == null || lng == null || tsRaw == null) continue;

      DateTime ts;
      if (tsRaw is String) {
        ts = DateTime.tryParse(tsRaw)?.toLocal() ?? DateTime.now();
      } else if (tsRaw is int) {
        ts = DateTime.fromMillisecondsSinceEpoch(tsRaw).toLocal();
      } else {
        continue;
      }
      pts.add(_TrackPoint(lat: lat, lng: lng, ts: ts));
    }
    pts.sort((a, b) => a.ts.compareTo(b.ts));
    return pts;
  }

  /// NEW: remove jitter before drawing — keeps first point, then
  /// only adds a point if moved >= [minMeters] from the last kept point.
  List<_TrackPoint> _simplifyByDistance(List<_TrackPoint> points,
      {double minMeters = 10}) {
    if (points.length <= 1) return points;
    final kept = <_TrackPoint>[points.first];
    for (var i = 1; i < points.length; i++) {
      final prev = kept.last.ll;
      final cur = points[i].ll;
      if (_distM(prev, cur) >= minMeters) {
        kept.add(points[i]);
      }
    }
    return kept;
  }

  List<Marker> _buildMarkers(List<_TrackPoint> points) {
    if (points.isEmpty) return const [];

    final markers = <Marker>[];

    // Start (green)
    final start = points.first;
    markers.add(
      Marker(
        markerId: const MarkerId('start'),
        position: start.ll,
        infoWindow: InfoWindow(title: 'Start • ${_timeFmt.format(start.ts)}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // All interior points (INCLUDING the last point when session not ended)
    for (var i = 1; i < points.length; i++) {
      // If session ended, the last point is reserved for the red "End" marker
      if (_sessionEnded && i == points.length - 1) continue;

      final p = points[i];
      markers.add(
        Marker(
          markerId: MarkerId('p$i'),
          position: p.ll,
          infoWindow: InfoWindow(title: _timeFmt.format(p.ts)),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }

    // End (red) only if session ended
    if (_sessionEnded && points.length > 1) {
      final end = points.last;
      markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: end.ll,
          infoWindow: InfoWindow(title: 'End • ${_timeFmt.format(end.ts)}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return markers;
  }

  Future<void> _loadAndDrawPath() async {
    try {
      if ((_jwt ?? '').isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not logged in.')),
        );
        return;
      }

      final uri = Uri.parse('$_apiBase/api/tracking/day')
          .replace(queryParameters: {'dateIso': _dateIso()});

      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $_jwt',
          if ((_empId ?? '').isNotEmpty) 'x-empid': _empId!,
        },
      );
      print('TRACK RES: ${res.statusCode} ${res.body}');
      if (res.statusCode >= 400) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: ${res.statusCode}')));
        return;
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final data =
          (json['data'] ?? <String, dynamic>{}) as Map<String, dynamic>;
      final endedAt = (data['endedAt'] as String?);
      _sessionEnded = (endedAt != null && endedAt.isNotEmpty);

      // ---------- ACCEPT list or map for pathMap ----------
      final dynamic pm = data['pathMap'];
      List<dynamic> raw;
      if (pm is List) {
        raw = pm;
      } else if (pm is Map) {
        // Convert { "0": {...}, "1": {...}, ... } to a list in index order
        final entries = pm.entries.toList()
          ..sort((a, b) => int.tryParse(a.key.toString())!
              .compareTo(int.tryParse(b.key.toString())!));
        raw = entries.map((e) => e.value).toList();
      } else {
        raw = const [];
      }
      // ----------------------------------------------------

      var points = _parseTrackPoints(raw);

      // Client-side clean-up (matches server MIN_MOVE_M ~12m; we use 10m)
      points = _simplifyByDistance(points, minMeters: 10);

      if (points.isEmpty) {
        if (!mounted) return;
        setState(() {
          _polylines = {};
          _markers = {};
          _center ??= const LatLng(12.9716, 77.5946);
        });
        return;
      }

      final latLngs = points.map((p) => p.ll).toList(growable: false);

      // Polyline only if we have ≥ 2 points
      final Set<Polyline> polylines = (latLngs.length >= 2)
          ? {
              Polyline(
                polylineId: const PolylineId('route'),
                points: latLngs,
                width: 5,
                color: const Color(0xFFB39DDB), // lavender
              ),
            }
          : {};

      final markers = _buildMarkers(points);

      if (!mounted) return;
      setState(() {
        _polylines = polylines;
        _markers = {...markers};
        _center = latLngs.last;
      });

      if (_mapCtrl != null) {
        if (latLngs.length >= 2) {
          await _mapCtrl!.animateCamera(
            CameraUpdate.newLatLngBounds(_boundsFromLatLngs(latLngs), 48),
          );
        } else {
          await _mapCtrl!.animateCamera(
            CameraUpdate.newLatLngZoom(latLngs.first, 17),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading path: $e')));
    }
  }

  LatLngBounds _boundsFromLatLngs(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in list) {
      minLat = (minLat == null)
          ? p.latitude
          : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null)
          ? p.latitude
          : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null)
          ? p.longitude
          : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null)
          ? p.longitude
          : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    return LatLngBounds(
      southwest: LatLng(minLat ?? 0, minLng ?? 0),
      northeast: LatLng(maxLat ?? 0, maxLng ?? 0),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        dateController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
      _loadAndDrawPath();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Use real AppBar so global AppBarTheme applies everywhere
      appBar: AppBar(
        title: const Text('My Track'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: SafeArea(
          top: false, // AppBar already handles status bar
          child: Column(
            children: [
              // Controls
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: dateController,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: InputDecoration(
                          labelText: "Choose date",
                          prefixIcon: const Icon(Icons.calendar_today,
                              color: kButtonColor),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: kButtonColor, width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Map'),
                      selected: _mapType == MapType.normal,
                      onSelected: (_) =>
                          setState(() => _mapType = MapType.normal),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Satellite'),
                      selected: _mapType == MapType.satellite,
                      onSelected: (_) =>
                          setState(() => _mapType = MapType.satellite),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Reload path',
                      onPressed: _loadAndDrawPath,
                    ),
                  ],
                ),
              ),

              // Map
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _center ?? const LatLng(12.9716, 77.5946),
                      zoom: 16,
                    ),
                    onMapCreated: (c) {
                      _mapCtrl = c;
                      if (_polylines.isNotEmpty) {
                        final pts = _polylines.first.points;
                        if (pts.isNotEmpty) {
                          _mapCtrl!.moveCamera(
                            CameraUpdate.newLatLngBounds(
                                _boundsFromLatLngs(pts), 48),
                          );
                        }
                      }
                    },
                    mapType: _mapType,
                    polylines: _polylines,
                    markers: _markers,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    compassEnabled: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
