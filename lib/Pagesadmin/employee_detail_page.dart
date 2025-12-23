// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:http/http.dart' as http;
// import 'dart:math' as math;

// import 'package:google_maps_flutter/google_maps_flutter.dart';

// import '../services/api_service.dart';
// import 'package:serv_app/models/company_data.dart';

// // Theme
// const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
// const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
// const Color kAppBarColor = Color(0xFF8C6EAF);
// const Color kButtonColor = Color(0xFF655193);
// const Color kTextColor = Colors.white;

// /* ---------- Tracking helpers (match My Track) ---------- */

// class _TrackPoint {
//   final double lat;
//   final double lng;
//   final DateTime ts;
//   const _TrackPoint(this.lat, this.lng, this.ts);
//   LatLng get ll => LatLng(lat, lng);
// }

// // Haversine (meters)
// double _distM(LatLng a, LatLng b) {
//   const R = 6371000.0;
//   final dLat = (b.latitude - a.latitude) * (math.pi / 180.0);
//   final dLng = (b.longitude - a.longitude) * (math.pi / 180.0);
//   final aa = math.sin(dLat / 2) * math.sin(dLat / 2) +
//       math.cos(a.latitude * math.pi / 180.0) *
//           math.cos(b.latitude * math.pi / 180.0) *
//           math.sin(dLng / 2) *
//           math.sin(dLng / 2);
//   final c = 2.0 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
//   return R * c;
// }

// /// Keep first point, then only add if moved >= minMeters
// List<_TrackPoint> _simplifyByDistance(List<_TrackPoint> points,
//     {double minMeters = 10}) {
//   if (points.length <= 1) return points;
//   final kept = <_TrackPoint>[points.first];
//   for (var i = 1; i < points.length; i++) {
//     if (_distM(kept.last.ll, points[i].ll) >= minMeters) {
//       kept.add(points[i]);
//     }
//   }
//   return kept;
// }

// class EmployeeDetailPage extends StatefulWidget {
//   final Map<String, dynamic> employee; // at least {'id': empid}, optional {'date': 'YYYY-MM-DD'}
//   const EmployeeDetailPage({super.key, required this.employee});

//   @override
//   State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
// }

// class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
//   bool _loading = true;
//   String? _error;

//   // From backend (attendance)
//   late String empid;
//   late String dateIso;
//   String name = '-';
//   String shift = '-';
//   String branchName = '-'; // attendance.branchName
//   String status = '-';
//   String? checkIn; // HH:mm:ss
//   String? checkOut; // HH:mm:ss

//   // Stored check-in coordinates (attendance.checkInLatitude/Longitude)
//   double? checkInLat;
//   double? checkInLng;

//   // Branch (expected) coordinates (attendance.expectedLatitude/Longitude)
//   double? expectedLat;
//   double? expectedLng;

//   // Google Map
//   GoogleMapController? _mapController;
//   final Set<Marker> _markers = {};
//   final Set<Polyline> _polylines = {};
//   CameraPosition _initialCam =
//       const CameraPosition(target: LatLng(13.0827, 80.2707), zoom: 16); // Chennai

//   // Tracking UI parity with My Track
//   final DateFormat _timeFmt = DateFormat('hh:mm a');
//   bool _sessionEnded = false; // red end pin only if true

//   @override
//   void initState() {
//     super.initState();
//     empid = (widget.employee['id'] ?? widget.employee['empid'] ?? '').toString();
//     final passedDate = (widget.employee['date'] ?? '').toString();
//     dateIso = passedDate.isNotEmpty
//         ? passedDate
//         : DateFormat('yyyy-MM-dd').format(DateTime.now());
//     _loadLiveDetails();
//   }

//   // ----------- Load live details (attendance for the given emp/date) -----------
//   Future<void> _loadLiveDetails() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });
//     try {
//       final headers = {
//         'Content-Type': 'application/json',
//         if ((CompanyData.token ?? '').isNotEmpty)
//           'Authorization': 'Bearer ${CompanyData.token}',
//       };
//       final uri = Uri.parse('$apiBase/liveEmployeeDetails/$empid')
//           .replace(queryParameters: {'dateIso': dateIso});
//       final resp = await http.get(uri, headers: headers);

//       if (resp.statusCode != 200) {
//         throw 'HTTP ${resp.statusCode}: ${resp.body}';
//       }

//       final body = jsonDecode(resp.body);
//       final data = (body is Map && body['data'] is Map)
//           ? Map<String, dynamic>.from(body['data'])
//           : <String, dynamic>{};

//       setState(() {
//         name = (data['name'] ?? '-') as String;
//         shift = (data['shift'] ?? '-') as String;
//         branchName =
//             (data['location'] ?? '-') as String; // server sends branchName as 'location'
//         status = (data['status'] ?? '-') as String;

//         final ci = (data['checkIn'] as String?);
//         checkIn = (ci == null || ci.trim().isEmpty) ? null : ci;
//         final co = (data['checkOut'] as String?);
//         checkOut = (co == null || co.trim().isEmpty) ? null : co;

//         // Server returns check-in lat/lng in top-level latitude/longitude
//         checkInLat = _toDoubleOrNull(data['latitude']);
//         checkInLng = _toDoubleOrNull(data['longitude']);

//         // If backend provided expected coordinates & branch name, store them
//         expectedLat = _toDoubleOrNull(data['expectedLatitude']);
//         expectedLng = _toDoubleOrNull(data['expectedLongitude']);
//       });

//       // Default map to check-in point if present
//       if (checkInLat != null && checkInLng != null) {
//         _showCheckInOnMap();
//       } else {
//         setState(() {
//           _markers.clear();
//           _polylines.clear();
//         });
//       }
//     } catch (e) {
//       setState(() => _error = '$e');
//     } finally {
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   double? _toDoubleOrNull(dynamic v) {
//     if (v is num) return v.toDouble();
//     if (v is String) {
//       final d = double.tryParse(v);
//       return d;
//     }
//     return null;
//   }

//   // ---------------- Buttons ----------------

//   /// 1) Check-in Location — show stored attendance check-in coords (green pin)
//   void _showCheckInOnMap() {
//     if (checkInLat == null || checkInLng == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No stored check-in location for this day.')),
//       );
//     } else {
//       final pos = LatLng(checkInLat!, checkInLng!);

//       _markers
//         ..clear()
//         ..add(
//           Marker(
//             markerId: const MarkerId('checkin'),
//             position: pos,
//             infoWindow: const InfoWindow(title: 'Check-in location'),
//             icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
//           ),
//         );
//       _polylines.clear();

//       _animate(pos, 18);
//     }
//     setState(() {});
//   }

//   /// 2) Geolocation — draw FULL path for the day from tracking collection.
//   ///    Start: green default marker (index 0)
//   ///    Interior points (1..N-1): orange pins with local time
//   ///    End: red pin only if the session ended (endedAt present)
//   Future<void> _showLastTrackingPath() async {
//     try {
//       final headers = {
//         'Content-Type': 'application/json',
//         'x-empid': empid,
//         if ((CompanyData.token ?? '').isNotEmpty)
//           'Authorization': 'Bearer ${CompanyData.token}',
//       };
//       final uri = Uri.parse('$apiBase/tracking/day')
//           .replace(queryParameters: {'dateIso': dateIso});

//       final resp = await http.get(uri, headers: headers);
//       if (resp.statusCode != 200) {
//         throw 'HTTP ${resp.statusCode}: ${resp.body}';
//       }
//       final json = jsonDecode(resp.body);
//       final data = (json is Map && json['data'] is Map)
//           ? Map<String, dynamic>.from(json['data'])
//           : <String, dynamic>{};

//       // endedAt controls whether we show a red final pin
//       _sessionEnded = (data['endedAt'] != null && '${data['endedAt']}'.isNotEmpty);

//       final raw = (data['pathMap'] is List) ? List.from(data['pathMap']) : [];

//       // Normalize to TrackPoints
//       final pts = <_TrackPoint>[];
//       for (final e in raw) {
//         final m = Map<String, dynamic>.from(e as Map);
//         final lat = _toDoubleOrNull(m['lat']);
//         final lng = _toDoubleOrNull(m['lng']);
//         final tsRaw = (m['ts'] ?? '').toString();
//         if (lat == null || lng == null) continue;

//         DateTime ts;
//         final tryIso = DateTime.tryParse(tsRaw);
//         if (tryIso != null) {
//           ts = tryIso.toLocal();
//         } else {
//           // if server stored millis
//           final millis = int.tryParse(tsRaw);
//           ts = millis != null
//               ? DateTime.fromMillisecondsSinceEpoch(millis).toLocal()
//               : DateTime.now();
//         }
//         pts.add(_TrackPoint(lat, lng, ts));
//       }

//       if (pts.isEmpty) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('No tracking points for this day.')),
//         );
//         return;
//       }

//       // Client-side clean-up (10 m)
//       final points = _simplifyByDistance(pts, minMeters: 10);
//       final latLngs = points.map((p) => p.ll).toList(growable: false);

//       // Build markers (match My Track)
//       final mk = <Marker>{};

//       // Start (green)
//       final start = points.first;
//       mk.add(
//         Marker(
//           markerId: const MarkerId('start'),
//           position: start.ll,
//           infoWindow: InfoWindow(title: 'Start • ${_timeFmt.format(start.ts)}'),
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
//         ),
//       );

//       // Interior points (orange with time)
//       for (var i = 1; i < points.length - 1; i++) {
//         final p = points[i];
//         mk.add(
//           Marker(
//             markerId: MarkerId('p$i'),
//             position: p.ll,
//             infoWindow: InfoWindow(title: _timeFmt.format(p.ts)),
//             icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
//           ),
//         );
//       }

//       // End (red) only if session ended
//       if (_sessionEnded && points.length > 1) {
//         final end = points.last;
//         mk.add(
//           Marker(
//             markerId: const MarkerId('end'),
//             position: end.ll,
//             infoWindow: InfoWindow(title: 'End • ${_timeFmt.format(end.ts)}'),
//             icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//           ),
//         );
//       }

//       // Polyline
//       final poly = Polyline(
//         polylineId: const PolylineId('path'),
//         points: latLngs,
//         width: 6,
//         color: const Color(0xFF7B5CD6),
//       );

//       setState(() {
//         _markers
//           ..clear()
//           ..addAll(mk);
//         _polylines
//           ..clear()
//           ..add(poly);
//       });

//       _fitCameraToAll(latLngs, padding: 72.0);
//     } catch (e) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Geo load failed: $e')));
//     }
//   }

//   /// 3) Branch Location — show attendance.expectedLat/Lng (lavender pin)
//   void _showBranchOnMap() {
//     if (expectedLat == null || expectedLng == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Branch coordinates not available from server.'),
//         ),
//       );
//       return;
//     }
//     final pos = LatLng(expectedLat!, expectedLng!);
//     _markers
//       ..clear()
//       ..add(
//         Marker(
//           markerId: const MarkerId('branch'),
//           position: pos,
//           infoWindow: InfoWindow(title: 'Branch location', snippet: branchName),
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
//         ),
//       );
//     _polylines.clear();
//     _animate(pos, 18);
//     setState(() {});
//   }

//   void _animate(LatLng p, double z) {
//     _initialCam = CameraPosition(target: p, zoom: z);
//     _mapController?.animateCamera(CameraUpdate.newCameraPosition(_initialCam));
//   }

//   void _fitCameraToAll(List<LatLng> pts, {double padding = 48}) {
//     if (_mapController == null || pts.isEmpty) return;
//     double? minLat, maxLat, minLng, maxLng;
//     for (final p in pts) {
//       minLat = (minLat == null) ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
//       maxLat = (maxLat == null) ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
//       minLng = (minLng == null) ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
//       maxLng = (maxLng == null) ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
//     }
//     final bounds = LatLngBounds(
//       southwest: LatLng(minLat!, minLng!),
//       northeast: LatLng(maxLat!, maxLng!),
//     );
//     _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
//   }

//   // ---------------- UI helpers ----------------
//   String _fmt(String? v, {String dash = '-'}) =>
//       (v == null || v.trim().isEmpty) ? dash : v;
//   String _fmtNum(num? v) => (v == null) ? '-' : v.toString();

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: kPrimaryBackgroundTop,
//       appBar: AppBar(
//         backgroundColor: kAppBarColor,
//         foregroundColor: kTextColor,
//         title: Text('Employee ID: $empid'),
//         actions: [
//           if (!_loading && _error == null)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               child: _StatusChip(status: status),
//             ),
//         ],
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//         ),
//         child: _loading
//             ? const Center(child: CircularProgressIndicator())
//             : _error != null
//                 ? Center(
//                     child: Padding(
//                       padding: const EdgeInsets.all(16),
//                       child: Text(_error!,
//                           textAlign: TextAlign.center,
//                           style: const TextStyle(color: Colors.red)),
//                     ),
//                   )
//                 : ListView(
//                     padding: const EdgeInsets.all(16),
//                     children: [
//                       Text(
//                         (name.isEmpty ? '-' : name),
//                         style: const TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.w700,
//                           color: kButtonColor,
//                         ),
//                       ),
//                       const SizedBox(height: 12),

//                       // Details
//                       _DetailRow(label: 'Date', value: dateIso),
//                       _DetailRow(label: 'Shift', value: _fmt(shift)),
//                       _DetailRow(label: 'Location', value: _fmt(branchName)),
//                       _DetailRow(label: 'Check-in', value: _fmt(checkIn)),
//                       _DetailRow(
//                           label: 'Check-out', value: _fmt(checkOut, dash: '—')),
//                       _DetailRow(
//                           label: 'Latitude', value: _fmtNum(checkInLat)),
//                       _DetailRow(
//                           label: 'Longitude', value: _fmtNum(checkInLng)),
//                       _DetailRow(label: 'Status', value: _fmt(status)),

//                       const SizedBox(height: 16),

//                       // Row 1: Check-in Location + Geolocation
//                       Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               onPressed: _showCheckInOnMap,
//                               icon: const Icon(Icons.login),
//                               label: const Text('Check-in Location'),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: kButtonColor,
//                                 foregroundColor: Colors.white,
//                                 padding:
//                                     const EdgeInsets.symmetric(vertical: 12),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Expanded(
//                             child: ElevatedButton.icon(
//                               onPressed: _showLastTrackingPath,
//                               icon: const Icon(Icons.alt_route),
//                               label: const Text('Geolocation'),
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.orange.shade600,
//                                 foregroundColor: Colors.white,
//                                 padding:
//                                     const EdgeInsets.symmetric(vertical: 12),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),

//                       const SizedBox(height: 10),

//                       // Row 2: Branch Location (full width)
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton.icon(
//                           onPressed: _showBranchOnMap,
//                           icon: const Icon(Icons.place),
//                           label: const Text('Branch Location'),
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF8C6EAF),
//                             foregroundColor: Colors.white,
//                             padding: const EdgeInsets.symmetric(vertical: 12),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                           ),
//                         ),
//                       ),

//                       const SizedBox(height: 16),

//                       // Google Map
//                       Container(
//                         height: 260,
//                         decoration: BoxDecoration(
//                           color: Colors.white,
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(color: Colors.black12),
//                           boxShadow: const [
//                             BoxShadow(blurRadius: 4, color: Colors.black12)
//                           ],
//                         ),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(12),
//                           child: GoogleMap(
//                             initialCameraPosition: _initialCam,
//                             myLocationEnabled: false,
//                             myLocationButtonEnabled: false,
//                             zoomControlsEnabled: false,
//                             markers: _markers,
//                             polylines: _polylines,
//                             onMapCreated: (c) {
//                               _mapController = c;
//                               if (checkInLat != null && checkInLng != null) {
//                                 _mapController!.moveCamera(
//                                   CameraUpdate.newLatLngZoom(
//                                       LatLng(checkInLat!, checkInLng!), 18),
//                                 );
//                               }
//                             },
//                           ),
//                         ),
//                       ),

//                       const SizedBox(height: 16),
//                       const Text(
//                         'Open Shift Log',
//                         style:
//                             TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//                       ),
//                       const SizedBox(height: 8),
//                       _ShiftLogRow(
//                         entryLabel: 'Entry',
//                         entryValue: _fmt(checkIn),
//                         exitLabel: 'Exit',
//                         exitValue: _fmt(checkOut, dash: 'null'),
//                       ),
//                     ],
//                   ),
//       ),
//     );
//   }
// }

// class _DetailRow extends StatelessWidget {
//   final String label;
//   final String value;
//   const _DetailRow({required this.label, required this.value});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 110,
//             child: Text(
//               '$label:',
//               style: const TextStyle(
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//           ),
//           Expanded(
//             child: Text(value, style: const TextStyle(color: Colors.black87)),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ShiftLogRow extends StatelessWidget {
//   final String entryLabel;
//   final String entryValue;
//   final String exitLabel;
//   final String exitValue;
//   const _ShiftLogRow({
//     required this.entryLabel,
//     required this.entryValue,
//     required this.exitLabel,
//     required this.exitValue,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       child: Row(
//         children: [
//           Expanded(child: Text('$entryLabel: $entryValue')),
//           Expanded(
//             child: Text('$exitLabel: $exitValue', textAlign: TextAlign.right),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _StatusChip extends StatelessWidget {
//   final String status;
//   const _StatusChip({required this.status});

//   Color _bgFor(String s) {
//     final v = s.toLowerCase();
//     if (v.contains('present')) return Colors.green.shade600;
//     if (v.contains('absent')) return Colors.red.shade600;
//     if (v.contains('leave')) return Colors.orange.shade700;
//     return Colors.grey.shade600;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
//       decoration: BoxDecoration(
//         color: _bgFor(status),
//         borderRadius: BorderRadius.circular(24),
//       ),
//       child: Text(
//         status,
//         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;

// 👇 Added for gesture recognizers so the map can pan/zoom inside ListView
import 'package:flutter/gestures.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_service.dart';
import 'package:serv_app/models/company_data.dart';

// Theme
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

/* ---------- Tracking helpers (match My Track) ---------- */

class _TrackPoint {
  final double lat;
  final double lng;
  final DateTime ts;
  const _TrackPoint(this.lat, this.lng, this.ts);
  LatLng get ll => LatLng(lat, lng);
}

// Haversine (meters)
double _distM(LatLng a, LatLng b) {
  const R = 6371000.0;
  final dLat = (b.latitude - a.latitude) * (math.pi / 180.0);
  final dLng = (b.longitude - a.longitude) * (math.pi / 180.0);
  final aa = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(a.latitude * math.pi / 180.0) *
          math.cos(b.latitude * math.pi / 180.0) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2.0 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
  return R * c;
}

/// Keep first point, then only add if moved >= minMeters
List<_TrackPoint> _simplifyByDistance(List<_TrackPoint> points,
    {double minMeters = 10}) {
  if (points.length <= 1) return points;
  final kept = <_TrackPoint>[points.first];
  for (var i = 1; i < points.length; i++) {
    if (_distM(kept.last.ll, points[i].ll) >= minMeters) {
      kept.add(points[i]);
    }
  }
  return kept;
}

class EmployeeDetailPage extends StatefulWidget {
  final Map<String, dynamic> employee; // at least {'id': empid}, optional {'date': 'YYYY-MM-DD'}
  const EmployeeDetailPage({super.key, required this.employee});

  @override
  State<EmployeeDetailPage> createState() => _EmployeeDetailPageState();
}

class _EmployeeDetailPageState extends State<EmployeeDetailPage> {
  bool _loading = true;
  String? _error;

  // From backend (attendance)
  late String empid;
  late String dateIso;
  String name = '-';
  String shift = '-';
  String branchName = '-'; // attendance.branchName
  String status = '-';
  String? checkIn; // HH:mm:ss
  String? checkOut; // HH:mm:ss

  // Stored check-in coordinates (attendance.checkInLatitude/Longitude)
  double? checkInLat;
  double? checkInLng;

  // Branch (expected) coordinates (attendance.expectedLatitude/Longitude)
  double? expectedLat;
  double? expectedLng;

  // Google Map
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  CameraPosition _initialCam =
      const CameraPosition(target: LatLng(13.0827, 80.2707), zoom: 16); // Chennai

  // Tracking UI parity with My Track
  final DateFormat _timeFmt = DateFormat('hh:mm a');
  bool _sessionEnded = false; // red end pin only if true

  @override
  void initState() {
    super.initState();
    empid = (widget.employee['id'] ?? widget.employee['empid'] ?? '').toString();
    final passedDate = (widget.employee['date'] ?? '').toString();
    dateIso = passedDate.isNotEmpty
        ? passedDate
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadLiveDetails();
  }

  // ----------- Load live details (attendance for the given emp/date) -----------
  Future<void> _loadLiveDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final headers = {
        'Content-Type': 'application/json',
        if ((CompanyData.token ?? '').isNotEmpty)
          'Authorization': 'Bearer ${CompanyData.token}',
      };
      final uri = Uri.parse('$apiBase/liveEmployeeDetails/$empid')
          .replace(queryParameters: {'dateIso': dateIso});
      final resp = await http.get(uri, headers: headers);

      if (resp.statusCode != 200) {
        throw 'HTTP ${resp.statusCode}: ${resp.body}';
      }

      final body = jsonDecode(resp.body);
      final data = (body is Map && body['data'] is Map)
          ? Map<String, dynamic>.from(body['data'])
          : <String, dynamic>{};

      setState(() {
        name = (data['name'] ?? '-') as String;
        shift = (data['shift'] ?? '-') as String;
        branchName =
            (data['location'] ?? '-') as String; // server sends branchName as 'location'
        status = (data['status'] ?? '-') as String;

        final ci = (data['checkIn'] as String?);
        checkIn = (ci == null || ci.trim().isEmpty) ? null : ci;
        final co = (data['checkOut'] as String?);
        checkOut = (co == null || co.trim().isEmpty) ? null : co;

        // Server returns check-in lat/lng in top-level latitude/longitude
        checkInLat = _toDoubleOrNull(data['latitude']);
        checkInLng = _toDoubleOrNull(data['longitude']);

        // If backend provided expected coordinates & branch name, store them
        expectedLat = _toDoubleOrNull(data['expectedLatitude']);
        expectedLng = _toDoubleOrNull(data['expectedLongitude']);
      });

      // Default map to check-in point if present
      if (checkInLat != null && checkInLng != null) {
        _showCheckInOnMap();
      } else {
        setState(() {
          _markers.clear();
          _polylines.clear();
        });
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double? _toDoubleOrNull(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final d = double.tryParse(v);
      return d;
    }
    return null;
  }

  // ---------------- Buttons ----------------

  /// 1) Check-in Location — show stored attendance check-in coords (green pin)
  void _showCheckInOnMap() {
    if (checkInLat == null || checkInLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stored check-in location for this day.')),
      );
    } else {
      final pos = LatLng(checkInLat!, checkInLng!);

      _markers
        ..clear()
        ..add(
          Marker(
            markerId: const MarkerId('checkin'),
            position: pos,
            infoWindow: const InfoWindow(title: 'Check-in location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        );
      _polylines.clear();

      _animate(pos, 18);
    }
    setState(() {});
  }

  /// 2) Geolocation — draw FULL path for the day from tracking collection.
  ///    Start: green default marker (index 0)
  ///    Interior points (1..N-1): orange pins with local time
  ///    End: red pin only if the session ended (endedAt present)
  Future<void> _showLastTrackingPath() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'x-empid': empid,
        if ((CompanyData.token ?? '').isNotEmpty)
          'Authorization': 'Bearer ${CompanyData.token}',
      };
      final uri = Uri.parse('$apiBase/tracking/day')
          .replace(queryParameters: {'dateIso': dateIso});

      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode != 200) {
        throw 'HTTP ${resp.statusCode}: ${resp.body}';
      }
      final json = jsonDecode(resp.body);
      final data = (json is Map && json['data'] is Map)
          ? Map<String, dynamic>.from(json['data'])
          : <String, dynamic>{};

      // endedAt controls whether we show a red final pin
      _sessionEnded = (data['endedAt'] != null && '${data['endedAt']}'.isNotEmpty);

      final raw = (data['pathMap'] is List) ? List.from(data['pathMap']) : [];

      // Normalize to TrackPoints
      final pts = <_TrackPoint>[];
      for (final e in raw) {
        final m = Map<String, dynamic>.from(e as Map);
        final lat = _toDoubleOrNull(m['lat']);
        final lng = _toDoubleOrNull(m['lng']);
        final tsRaw = (m['ts'] ?? '').toString();
        if (lat == null || lng == null) continue;

        DateTime ts;
        final tryIso = DateTime.tryParse(tsRaw);
        if (tryIso != null) {
          ts = tryIso.toLocal();
        } else {
          // if server stored millis
          final millis = int.tryParse(tsRaw);
          ts = millis != null
              ? DateTime.fromMillisecondsSinceEpoch(millis).toLocal()
              : DateTime.now();
        }
        pts.add(_TrackPoint(lat, lng, ts));
      }

      if (pts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tracking points for this day.')),
        );
        return;
      }

      // Client-side clean-up (10 m)
      final points = _simplifyByDistance(pts, minMeters: 10);
      final latLngs = points.map((p) => p.ll).toList(growable: false);

      // Build markers (match My Track)
      final mk = <Marker>{};

      // Start (green)
      final start = points.first;
      mk.add(
        Marker(
          markerId: const MarkerId('start'),
          position: start.ll,
          infoWindow: InfoWindow(title: 'Start • ${_timeFmt.format(start.ts)}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );

      // Interior points (orange with time)
      for (var i = 1; i < points.length - 1; i++) {
        final p = points[i];
        mk.add(
          Marker(
            markerId: MarkerId('p$i'),
            position: p.ll,
            infoWindow: InfoWindow(title: _timeFmt.format(p.ts)),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          ),
        );
      }

      // End (red) only if session ended
      if (_sessionEnded && points.length > 1) {
        final end = points.last;
        mk.add(
          Marker(
            markerId: const MarkerId('end'),
            position: end.ll,
            infoWindow: InfoWindow(title: 'End • ${_timeFmt.format(end.ts)}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
        );
      }

      // Polyline
      final poly = Polyline(
        polylineId: const PolylineId('path'),
        points: latLngs,
        width: 6,
        color: const Color(0xFF7B5CD6),
      );

      setState(() {
        _markers
          ..clear()
          ..addAll(mk);
        _polylines
          ..clear()
          ..add(poly);
      });

      _fitCameraToAll(latLngs, padding: 72.0);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Geo load failed: $e')));
    }
  }

  /// 3) Branch Location — show attendance.expectedLat/Lng (lavender pin)
  void _showBranchOnMap() {
    if (expectedLat == null || expectedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Branch coordinates not available from server.'),
        ),
      );
      return;
    }
    final pos = LatLng(expectedLat!, expectedLng!);
    _markers
      ..clear()
      ..add(
        Marker(
          markerId: const MarkerId('branch'),
          position: pos,
          infoWindow: InfoWindow(title: 'Branch location', snippet: branchName),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
      );
    _polylines.clear();
    _animate(pos, 18);
    setState(() {});
  }

  void _animate(LatLng p, double z) {
    _initialCam = CameraPosition(target: p, zoom: z);
    _mapController?.animateCamera(CameraUpdate.newCameraPosition(_initialCam));
  }

  void _fitCameraToAll(List<LatLng> pts, {double padding = 48}) {
    if (_mapController == null || pts.isEmpty) return;
    double? minLat, maxLat, minLng, maxLng;
    for (final p in pts) {
      minLat = (minLat == null) ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
      maxLat = (maxLat == null) ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
      minLng = (minLng == null) ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = (maxLng == null) ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
  }

  // ---------------- UI helpers ----------------
  String _fmt(String? v, {String dash = '-'}) =>
      (v == null || v.trim().isEmpty) ? dash : v;
  String _fmtNum(num? v) => (v == null) ? '-' : v.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundTop,
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        foregroundColor: kTextColor,
        title: Text('Employee ID: $empid'),
        actions: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _StatusChip(status: status),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        (name.isEmpty ? '-' : name),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: kButtonColor,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Details
                      _DetailRow(label: 'Date', value: dateIso),
                      _DetailRow(label: 'Shift', value: _fmt(shift)),
                      _DetailRow(label: 'Location', value: _fmt(branchName)),
                      _DetailRow(label: 'Check-in', value: _fmt(checkIn)),
                      _DetailRow(
                          label: 'Check-out', value: _fmt(checkOut, dash: '—')),
                      _DetailRow(
                          label: 'Latitude', value: _fmtNum(checkInLat)),
                      _DetailRow(
                          label: 'Longitude', value: _fmtNum(checkInLng)),
                      _DetailRow(label: 'Status', value: _fmt(status)),

                      const SizedBox(height: 16),

                      // Row 1: Check-in Location + Geolocation
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showCheckInOnMap,
                              icon: const Icon(Icons.login),
                              label: const Text('Check-in Location'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kButtonColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showLastTrackingPath,
                              icon: const Icon(Icons.alt_route),
                              label: const Text('Geolocation'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Row 2: Branch Location (full width)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showBranchOnMap,
                          icon: const Icon(Icons.place),
                          label: const Text('Branch Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8C6EAF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Google Map
                      Container(
                        height: 260,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                          boxShadow: const [
                            BoxShadow(blurRadius: 4, color: Colors.black12)
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GoogleMap(
                            initialCameraPosition: _initialCam,
                            // ✨ Enable smooth interactivity
                            zoomControlsEnabled: true,
                            myLocationButtonEnabled: true,
                            mapToolbarEnabled: true,
                            zoomGesturesEnabled: true,
                            scrollGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: true,

                            // 👇 This is the key so gestures win over the ListView
                            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
                            },

                            myLocationEnabled: false,
                            markers: _markers,
                            polylines: _polylines,
                            onMapCreated: (c) {
                              _mapController = c;
                              if (checkInLat != null && checkInLng != null) {
                                _mapController!.moveCamera(
                                  CameraUpdate.newLatLngZoom(
                                      LatLng(checkInLat!, checkInLng!), 18),
                                );
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'Open Shift Log',
                        style:
                            TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      _ShiftLogRow(
                        entryLabel: 'Entry',
                        entryValue: _fmt(checkIn),
                        exitLabel: 'Exit',
                        exitValue: _fmt(checkOut, dash: 'null'),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

class _ShiftLogRow extends StatelessWidget {
  final String entryLabel;
  final String entryValue;
  final String exitLabel;
  final String exitValue;
  const _ShiftLogRow({
    required this.entryLabel,
    required this.entryValue,
    required this.exitLabel,
    required this.exitValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text('$entryLabel: $entryValue')),
          Expanded(
            child: Text('$exitLabel: $exitValue', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  Color _bgFor(String s) {
    final v = s.toLowerCase();
    if (v.contains('present')) return Colors.green.shade600;
    if (v.contains('absent')) return Colors.red.shade600;
    if (v.contains('leave')) return Colors.orange.shade700;
    return Colors.grey.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bgFor(status),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}
