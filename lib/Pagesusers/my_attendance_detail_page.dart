import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// === Brand Colors (as per your purple/lavender theme) ===
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF); // Purple app bar
const Color kButtonColor = Color(0xFF655193); // Darker purple for action bars
const Color kTextOnDark = Colors.white;

// Point to your backend
const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class MyAttendanceDetailPage extends StatefulWidget {
  const MyAttendanceDetailPage({
    super.key,
    required this.empId,
    required this.date, // date for which to show detail
    this.baseUrl = _apiBase,
    this.bearerToken, // optional: if you want to pass token explicitly
  });

  final String empId;
  final DateTime date;
  final String baseUrl;
  final String? bearerToken;

  @override
  State<MyAttendanceDetailPage> createState() => _MyAttendanceDetailPageState();
}

class _MyAttendanceDetailPageState extends State<MyAttendanceDetailPage> {
  // ---- Loaded values (bound to the static UI) ----
  late String _displayDateText;
  String _shiftName = ''; // keep field but default empty so it's hidden
  String _checkInTime = '-';
  String _checkOutTime = '-';
  String _permissionTime = '-';
  String _overTime = '-';
  String _statusText = '-';
  String _shiftGroup = '-'; // fetched from backend (employees/me)
  String _totalHoursText = '-';

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _displayDateText = _formatDateLong(widget.date);
    _load();
  }

  // ---------- Networking ----------
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = widget.bearerToken;
    final y = widget.date.year;
    final m2 = widget.date.month.toString().padLeft(2, '0');
    final d2 = widget.date.day.toString().padLeft(2, '0');
    final ymd = '$y-$m2-$d2';

    Map<String, dynamic>? dayRecord;

    try {
      // 0) Fetch current user info -> shiftGroup (no admin required)
      final meUri = Uri.parse('${widget.baseUrl}/attendance/me');
      final meRes = await http.get(
        meUri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );
      if (meRes.statusCode == 200 && meRes.body.isNotEmpty) {
        final me = jsonDecode(meRes.body) as Map<String, dynamic>;
        _shiftGroup = (me['shiftGroup'] ?? '-').toString();
        _shiftName = ''; // keep empty so the header bar hides
      }

      // 1) summary (month) → pick the selected day
      final sumUri =
          Uri.parse('${widget.baseUrl}/attendance/summary/${widget.empId}/$y/$m2');
      final sumRes = await http.get(
        sumUri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      if (sumRes.statusCode == 200 && sumRes.body.isNotEmpty) {
        final list = jsonDecode(sumRes.body);
        if (list is List) {
          for (final it in list) {
            final m = Map<String, dynamic>.from(it as Map);
            if ('${m['date']}'.trim().startsWith(ymd)) {
              dayRecord = m;
              break;
            }
          }
        }
      }

      if (dayRecord == null) {
        // No record for that date → Absent
        _applyValues(
          status: 'Absent',
          checkIn: null,
          checkOut: null,
          totalMins: null, // show "-" for total
        );
      } else {
        _applyFromJson(dayRecord);
      }
    } catch (e) {
      _error = 'Failed to load: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Parsing & mapping ----------
  void _applyFromJson(Map<String, dynamic> j) {
    // Flexible getters (handles snakeCase / different keys)
    T? get<T>(List<String> keys) {
      for (final k in keys) {
        if (j[k] != null) {
          try {
            return j[k] as T;
          } catch (_) {
            if (T == int) {
              final v = int.tryParse(j[k].toString());
              if (v != null) return v as T;
            } else if (T == String) {
              return j[k].toString() as T;
            }
          }
        }
      }
      return null;
    }

    // Times may be ISO strings or "HH:mm" / "HH:mm:ss"
    DateTime? parseDT(dynamic v) {
      if (v == null) return null;
      try {
        if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
        final s = v.toString().trim();

        if (s.contains('T')) return DateTime.parse(s).toLocal();

        // Accept HH:mm and HH:mm:ss (assume the selected date)
        final hhmm = RegExp(r'^\d{1,2}:\d{2}$');
        final hhmmss = RegExp(r'^\d{1,2}:\d{2}:\d{2}$');
        if (hhmm.hasMatch(s) || hhmmss.hasMatch(s)) {
          final parts = s.split(':').map(int.parse).toList();
          final hh = parts[0], mm = parts[1], ss = parts.length > 2 ? parts[2] : 0;
          return DateTime(widget.date.year, widget.date.month, widget.date.day, hh, mm, ss);
        }

        return DateTime.parse(s).toLocal();
      } catch (_) {
        return null;
      }
    }

    // Optional names (we don't show the shift title bar unless non-empty)
    final shiftName = get<String>(['shiftName', 'shift_name']) ?? '';
    final shiftGroup = _shiftGroup; // from /api/attendance/me

    // Check-in/out (NO fallback to shift end)
    final checkIn = parseDT(get(['checkIn', 'check_in', 'inTime', 'firstCheckIn']));
    final checkOut = parseDT(get(['checkOut', 'check_out', 'outTime', 'lastCheckOut']));

    // Status determination
    String status;
    if (checkIn != null) {
      // If there's a check-in, it's always Present
      status = 'Present';
    } else {
      // If no check-in, check the status from server
      status = get<String>(['status', 'attendanceStatus']) ?? 'Absent';
    }

    // Permission / OT minutes (optional)
    final permMins =
        get<int>(['permissionMinutes', 'permission_minutes', 'permissionMins']) ?? 0;
    final otMins = get<int>(['overtimeMinutes', 'overtime_minutes', 'ot_minutes']) ?? 0;

    // Total only if we have both checkIn and checkOut
    final totalMins = (checkIn != null && checkOut != null)
        ? _computeTotalMinutes(
            checkIn: checkIn,
            checkOut: checkOut,
            permissionMins: permMins,
            overtimeMins: otMins,
          )
        : null; // show "-" in UI

    _applyValues(
      shiftName: shiftName,
      shiftGroup: shiftGroup,
      status: status,
      checkIn: checkIn,
      checkOut: checkOut, // remains null → "-" in UI
      permissionMins: permMins,
      overtimeMins: otMins,
      totalMins: totalMins,
    );
  }

  void _applyValues({
    String? shiftName,
    String? shiftGroup,
    String? status,
    DateTime? checkIn,
    DateTime? checkOut,
    int? permissionMins,
    int? overtimeMins,
    int? totalMins,
  }) {
    setState(() {
      _shiftName = shiftName ?? _shiftName;
      _shiftGroup = shiftGroup ?? _shiftGroup;
      _statusText = status ?? _statusText;

      _checkInTime = _fmtTime(checkIn);
      _checkOutTime = _fmtTime(checkOut); // if null → "-"
      _permissionTime =
          (permissionMins == null || permissionMins == 0) ? '-' : '$permissionMins mins';
      _overTime = (overtimeMins == null || overtimeMins == 0) ? '-' : '$overtimeMins mins';

      _totalHoursText = (totalMins == null) ? '-' : _formatMinutes(totalMins);
    });
  }

  // ---------- Helpers ----------
  static String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h Hrs ${m.toString().padLeft(2, '0')} Mins';
  }

  static int _computeTotalMinutes({
    required DateTime checkIn,
    required DateTime checkOut,
    int permissionMins = 0,
    int overtimeMins = 0,
  }) {
    int base = checkOut.difference(checkIn).inMinutes;
    if (base < 0) base = 0;
    return (base + overtimeMins - permissionMins).clamp(0, 1000000);
  }

  static String _fmtTime(DateTime? t) {
    if (t == null) return '-';
    final dt = t.toLocal();
    final am = dt.hour < 12;
    int h12 = dt.hour % 12;
    if (h12 == 0) h12 = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '${h12.toString().padLeft(2, '0')}:$m ${am ? 'AM' : 'PM'}';
  }

  static String _formatDateLong(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final dd = d.day.toString().padLeft(2, '0');
    return '$dd ${months[d.month - 1]} ${d.year}';
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: kAppBarColor,
          foregroundColor: Colors.white,
          title: Text(
            _displayDateText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: _ShiftCard(
                    title: _shiftName,
                    checkInTime: _checkInTime,
                    checkOutTime: _checkOutTime,
                    permissionTime: _permissionTime,
                    overTime: _overTime,
                    statusText: _statusText,
                    shiftGroup: _shiftGroup,
                    totalHoursText: _totalHoursText,
                  ),
                ),
              ),
        bottomNavigationBar: _BottomNavBarShadow(),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.title,
    required this.checkInTime,
    required this.checkOutTime,
    required this.permissionTime,
    required this.overTime,
    required this.statusText,
    required this.shiftGroup,
    required this.totalHoursText,
  });

  final String title;
  final String checkInTime;
  final String checkOutTime;
  final String permissionTime;
  final String overTime;
  final String statusText;
  final String shiftGroup;
  final String totalHoursText;

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('present')) {
      return Colors.green.shade700; // Green for present
    } else if (statusLower.contains('absent')) {
      return Colors.pink.shade200; // Light pink for absent
    } else if (statusLower.contains('leave')) {
      return Colors.orange.shade700; // Orange for leave
    } else if (statusLower.contains('week off') || statusLower.contains('holiday')) {
      return Colors.blue.shade700; // Blue for week off/holiday
    } else if (statusLower.contains('half') && statusLower.contains('day')) {
      return Colors.amber.shade700; // Amber for half day
    }
    return Colors.grey.shade700; // Default grey for unknown status
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.trim().isNotEmpty)
                  Text(title, style: textTheme.titleLarge),
                if (title.trim().isNotEmpty) const SizedBox(height: 16),

                // First row: Check In / Check Out
                Row(
                  children: [
                    Expanded(
                      child: _LabelValue(
                        label: 'Check In Time',
                        value: checkInTime,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _LabelValue(
                        label: 'Check Out Time',
                        value: checkOutTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Second row: Permission / Status
                Row(
                  children: [
                    Expanded(
                      child: _LabelValue(
                        label: 'Permission Time',
                        value: permissionTime,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _LabelValue(
                        label: 'Status',
                        value: statusText,
                        valueStyle: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _getStatusColor(statusText),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Third row: Over Time / Shift Group
                Row(
                  children: [
                    Expanded(
                      child: _LabelValue(
                        label: 'Over Time',
                        value: overTime,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _LabelValue(
                        label: 'Shift Group',
                        value: shiftGroup,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Total hours banner (purple)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: kButtonColor,
              alignment: Alignment.center,
              child: Text(
                'Total hours: $totalHoursText',
                style: const TextStyle(
                  color: kTextOnDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: valueStyle ??
              t.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
        ),
      ],
    );
  }
}

/// Small visual lift for bottom gesture area on phones (optional).
class _BottomNavBarShadow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.06),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
