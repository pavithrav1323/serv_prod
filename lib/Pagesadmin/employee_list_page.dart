// import 'package:flutter/material.dart';
// import 'employee_detail_page.dart'; // Import your detail page

// // App Theme Colors
// const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
// const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
// const Color kAppBarColor = Color(0xFF8C6EAF);
// const Color kButtonColor = Color(0xFF655193);
// const Color kTextColor = Colors.white;

// class EmployeeListPage extends StatefulWidget {
//   const EmployeeListPage({super.key});

//   @override
//   State<EmployeeListPage> createState() => _EmployeeListPageState();
// }

// class _EmployeeListPageState extends State<EmployeeListPage> {
//   // Empty list, will be filled dynamically later
//   List<Map<String, dynamic>> employeeData = [];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: kPrimaryBackgroundTop,
//       appBar: AppBar(
//         title: const Text('Employee List'),
//         backgroundColor: kAppBarColor,
//         foregroundColor: kTextColor,
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//           ),
//         ),
//         padding: const EdgeInsets.all(16.0),
//         child: employeeData.isNotEmpty
//             ? ListView.builder(
//                 itemCount: employeeData.length,
//                 itemBuilder: (context, index) {
//                   final emp = employeeData[index];
//                   return EmployeeCard(emp: emp);
//                 },
//               )
//             : const Center(
//                 child: Text(
//                   "No Employee Data Found!",
//                   style: TextStyle(fontSize: 16, color: Colors.grey),
//                 ),
//               ),
//       ),
//     );
//   }
// }

// class EmployeeCard extends StatelessWidget {
//   final Map<String, dynamic> emp;

//   const EmployeeCard({super.key, required this.emp});

//   @override
//   Widget build(BuildContext context) {
//     return InkWell(
//       onTap: () {
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => EmployeeDetailPage(employee: emp)),
//         );
//       },
//       child: Card(
//         elevation: 4,
//         margin: const EdgeInsets.symmetric(vertical: 8),
//         color: Colors.white,
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//         child: Padding(
//           padding: const EdgeInsets.all(12.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 emp['name'] ?? '',
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                   color: kButtonColor,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text("ID: ${emp['id']} | Date: ${emp['date']}"),
//               Text("Check-in: ${emp['checkIn']}"),
//               const Divider(),
//               Text("Department: ${emp['department']}"),
//               Text("Shift: ${emp['shift']}"),
//               Text("Location: ${emp['location']}"),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
// lib/employee_list_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'employee_detail_page.dart'; // make sure path is correct

// App Theme Colors (unchanged)
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// ✅ Your deployed API base
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';
// List endpoint
String get _listEndpoint => '$apiBase/livedetails';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  // Filled dynamically from backend
  List<Map<String, dynamic>> employeeData = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final resp = await http.get(Uri.parse(_listEndpoint));
      if (resp.statusCode != 200) {
        // Leave empty state
        return;
      }

      final dynamic body = jsonDecode(resp.body);

      // Accept either { data: [...] } or [...] directly
      final List<dynamic> rows = (body is Map && body['data'] is List)
          ? (body['data'] as List<dynamic>)
          : (body is List ? body : const <dynamic>[]);

      final List<Map<String, dynamic>> mapped = rows
          .whereType<Map>() // keep only map-like
          .map<Map<String, dynamic>>((raw) {
        final m = Map<String, dynamic>.from(raw);

        final double? lat = _asDouble(
          m['latitude'] ?? m['checkInLatitude'] ?? m['expectedLatitude'],
        );
        final double? lng = _asDouble(
          m['longitude'] ?? m['checkInLongitude'] ?? m['expectedLongitude'],
        );

        final String loc = _asString(m['location'] ?? m['branchName']);

        return {
          'name': _asString(m['name']),
          'id': _asString(m['id'] ?? m['empid']),
          'date': _asString(m['date']),
          'checkIn': _asString(m['checkIn']),
          'checkOut': _asNullableString(m['checkOut']),
          'department': _asString(m['department']),
          'shift': _asString(m['shift']),
          'location': loc,
          'latitude': lat,
          'longitude': lng,
          'status': _asString(m['status']),
          'geofence': _asString(m['geofence'], fallback: '-'),
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        employeeData = mapped;
      });
    } catch (_) {
      // Keep default empty state on error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundTop,
      appBar: AppBar(
        title: const Text('Employee List'),
        backgroundColor: kAppBarColor,
        foregroundColor: kTextColor,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: employeeData.isNotEmpty
            ? ListView.builder(
                itemCount: employeeData.length,
                itemBuilder: (context, index) {
                  final emp = employeeData[index];
                  return EmployeeCard(emp: emp);
                },
              )
            : const Center(
                child: Text(
                  "No Employee Data Found!",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
      ),
    );
  }
}

class EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> emp;

  const EmployeeCard({super.key, required this.emp});

  String _s(dynamic v) => v == null ? '' : v.toString();

  @override
  Widget build(BuildContext context) {
    return Material( // ensure a Material ancestor for InkWell ripple
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          debugPrint('[EmployeeCard] tap -> navigating to details for id=${_s(emp['id'])}');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmployeeDetailPage(employee: emp),
              settings: const RouteSettings(name: 'EmployeeDetailPage'),
            ),
          );
        },
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _s(emp['name']),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kButtonColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text("ID: ${_s(emp['id'])} | Date: ${_s(emp['date'])}"),
                Text("Check-in: ${_s(emp['checkIn'])}"),
                const Divider(),
                Text("Department: ${_s(emp['department'])}"),
                Text("Shift: ${_s(emp['shift'])}"),
                Text("Location: ${_s(emp['location'])}"),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// -------- Helpers (no UI impact) --------

String _asString(dynamic v, {String fallback = ''}) {
  if (v == null) return fallback;
  return v.toString();
}

String? _asNullableString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

double? _asDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) {
    final s = v.trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }
  return null;
}
