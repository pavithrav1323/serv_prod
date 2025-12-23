import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// Web localStorage (ignored on mobile/desktop builds)
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

import 'create_shift_page.dart';
import 'shift_permission_page.dart';

// Theme Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// ==== API ====
const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class WorkdaysShiftPage extends StatefulWidget {
  const WorkdaysShiftPage({super.key});

  @override
  State<WorkdaysShiftPage> createState() => _WorkdaysShiftPageState();
}

class _WorkdaysShiftPageState extends State<WorkdaysShiftPage> {
  bool _isShiftPermissionClicked = false;
  bool _isCreateShiftClicked = false;

  bool _loading = false;
  String? _error;

  /// Shifts from DB
  List<Map<String, dynamic>> _shifts = [];

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<String?> _getToken() async {
    try {
      final t = html.window.localStorage['token'];
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {}
    final sp = await SharedPreferences.getInstance();
    final t2 = sp.getString('token');
    return (t2 != null && t2.isNotEmpty) ? t2 : null;
  }

  Future<void> _fetchShifts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final res = await http
          .get(Uri.parse('$_apiBase/shifts'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Failed to load shifts (${res.statusCode})';
        });
        return;
      }
      final list = jsonDecode(res.body) as List<dynamic>;
      _shifts = list.cast<Map<String, dynamic>>();
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Network error: $e';
      });
    }
  }

  Future<void> _handleCreateShift() async {
    setState(() {
      _isCreateShiftClicked = true;
      _isShiftPermissionClicked = false;
    });

    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const CreateShiftPage()),
    );

    if (created != null) {
      setState(() => _shifts.insert(0, created));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Shift "${created["name"] ?? created["shiftname"] ?? ""}" created'),
            backgroundColor: kButtonColor),
      );
      await _fetchShifts();
    }
  }

  // Helpers
  String _hm12(String hhmm) {
    try {
      final parts = hhmm.split(':');
      int h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final am = h < 12;
      if (h == 0) h = 12;
      if (h > 12) h -= 12;
      final mm = m.toString().padLeft(2, '0');
      return '$h:$mm ${am ? "AM" : "PM"}';
    } catch (_) {
      return hhmm;
    }
  }

  String _hoursBetween(String startHHMM, String endHHMM) {
    try {
      final s = startHHMM.split(':').map(int.parse).toList();
      final e = endHHMM.split(':').map(int.parse).toList();
      int sm = s[0] * 60 + s[1];
      int em = e[0] * 60 + e[1];
      int diff = em - sm;
      if (diff < 0) diff += 24 * 60; // crosses midnight
      final h = (diff / 60).floor();
      final m = diff % 60;
      return m == 0 ? '$h hrs' : '$h hrs $m mins';
    } catch (_) {
      return '-';
    }
  }

  Future<void> _deleteShift(String id) async {
    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final res = await http
        .delete(Uri.parse('$_apiBase/shifts/$id'), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (!mounted) return;
    if (res.statusCode == 200) {
      setState(() => _shifts.removeWhere((s) => s['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Shift deleted'), backgroundColor: kButtonColor),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Delete failed: ${res.statusCode}'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundTop,
      appBar: AppBar(
        title: const Text("Workdays & Shifts"),
        backgroundColor: kAppBarColor,
        foregroundColor: kTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchShifts,
            tooltip: 'Refresh',
          )
        ],
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true, // remove extra system bottom inset
        child: Container(
          constraints: const BoxConstraints.expand(), // fill the viewport
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            ),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Shift Configuration",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text("Choose your shift",
                              style: TextStyle(
                                  fontSize: 14, color: Colors.black54)),
                          const SizedBox(height: 16),

                          // Live from DB
                          for (int i = 0; i < _shifts.length; i++) ...[
                            _ShiftTemplateCard(
                              title:
                                  " ${_shifts[i]["name"] ?? _shifts[i]["shiftname"] ?? "Shift"}",
                              time:
                                  "${_hm12(_shifts[i]["startTime"] ?? '-')} - ${_hm12(_shifts[i]["endTime"] ?? '-')}",
                            ),
                            const SizedBox(height: 10),
                          ],

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // ---- Shift Permissions button commented out as requested ----
                              // OutlinedButton(
                              //   style: OutlinedButton.styleFrom(
                              //     backgroundColor: _isShiftPermissionClicked
                              //         ? kButtonColor
                              //         : Colors.transparent,
                              //     foregroundColor: _isShiftPermissionClicked
                              //         ? kTextColor
                              //         : Colors.black,
                              //     side: const BorderSide(color: kButtonColor),
                              //     shape: RoundedRectangleBorder(
                              //         borderRadius: BorderRadius.circular(20)),
                              //     padding: const EdgeInsets.symmetric(
                              //         horizontal: 24, vertical: 14),
                              //   ),
                              //   onPressed: () {
                              //     setState(() {
                              //       _isShiftPermissionClicked = true;
                              //       _isCreateShiftClicked = false;
                              //     });
                              //     Navigator.push(
                              //       context,
                              //       MaterialPageRoute(builder: (_) => const ShiftPermissionPage()),
                              //     );
                              //   },
                              //   child: const Text("Shift Permissions"),
                              // ),
                              // --------------------------------------------------------------

                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: _isCreateShiftClicked
                                      ? kButtonColor
                                      : Colors.transparent,
                                  foregroundColor: _isCreateShiftClicked
                                      ? kTextColor
                                      : Colors.black,
                                  side: const BorderSide(color: kButtonColor),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                ),
                                onPressed: _handleCreateShift,
                                child: const Text("Create Shift"),
                              ),
                            ],
                          ),

                          const SizedBox(height: 30),

                          // Table with live DB rows
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTableHeader(),
                                const Divider(),
                                Column(
                                  children: _shifts.map((s) {
                                    final id = (s['id'] ?? '').toString();
                                    final name =
                                        (s['name'] ?? '').toString();
                                    final group = (s['shiftname'] ?? '')
                                        .toString(); // Group Name
                                    final st =
                                        (s['startTime'] ?? '').toString();
                                    final et =
                                        (s['endTime'] ?? '').toString();

                                    return Row(
                                      children: [
                                        _CustomDataCell(name),
                                        _CustomDataCell(_hm12(st)),
                                        _CustomDataCell(_hm12(et)),
                                        _CustomDataCell(
                                            _hoursBetween(st, et)),
                                        _CustomDataCell('0'), // OT (mins)
                                        _CustomDataCell('4 hrs'), // Half Day
                                        _CustomDataCell('15 mins'), // Min PT
                                        _CustomDataCell('60 mins'), // Max PT
                                        _CustomDataCell('—'), // Max OT
                                        _CustomDataCell('—'), // Min OT
                                        _CustomDataCell(group),
                                        _CustomDataCell('—'), // Random count
                                        _CustomDataCell('—'), // End BufferName
                                        _CustomDataCell('—'), // Staff BufferName
                                        _CustomDataCell(group),
                                        _CustomDataCell('—'), // Break Count
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: id.isEmpty
                                              ? null
                                              : () => _deleteShift(id),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          // No extra bottom spacer—keeps the bottom tight
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Row(
      children: const [
        _HeaderCell("Shift Name"),
        _HeaderCell("Start Time"),
        _HeaderCell("End Time"),
        _HeaderCell("No. of hours"),
        _HeaderCell("OT(mins)"),
        _HeaderCell("Half Day Time"),
        _HeaderCell("Min PT"),
        _HeaderCell("Max PT"),
        _HeaderCell("Max OT"),
        _HeaderCell("Min OT"),
        _HeaderCell("Group Name"),
        _HeaderCell("Random count"),
        _HeaderCell("End BufferName"),
        _HeaderCell("Staff BufferName"),
        _HeaderCell("Group Name"),
        _HeaderCell("Break Count"),
        _HeaderCell("Delete"),
      ],
    );
  }
}

class _ShiftTemplateCard extends StatelessWidget {
  final String title;
  final String time;

  const _ShiftTemplateCard({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: kAppBarColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: double.infinity,
        height: 70,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(time,
                  style: const TextStyle(fontSize: 12),
                  textAlign: TextAlign.right),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 12, color: kButtonColor),
      ),
    );
  }
}

class _CustomDataCell extends StatelessWidget {
  final String value;

  const _CustomDataCell(this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: Text(value,
          textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
    );
  }
}
