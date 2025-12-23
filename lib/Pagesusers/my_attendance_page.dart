import 'dart:convert';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart'
    as html; // Flutter Web storage
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:serv_app/Pagesusers/attendance_model_page.dart';
import 'package:serv_app/models/company_data.dart'; // to read in-memory token if present
import 'package:table_calendar/table_calendar.dart';

// >>> NEW: navigate to detail page
import 'package:serv_app/Pagesusers/my_attendance_detail_page.dart';

// ================= THEME =================
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

const Color kPresentColor = Color.fromARGB(255, 173, 235, 148);
const Color kAbsentColor = Color.fromARGB(255, 236, 148, 142);
const Color kLeaveColor = Colors.orange;
const Color kHolidayColor = Colors.blue;
const Color kWeekOffColor = Colors.purple;
const Color kHalfDayColor = Color.fromARGB(169, 220, 233, 30);

// ============== API BASE =================
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

// ====== helpers (top-level so they’re easy to reuse) ======
bool _looksLikeJwt(String v) =>
    RegExp(r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$').hasMatch(v);

// ============== PAGE =====================
class MyAttendancePage extends StatefulWidget {
  final AttendanceData data; // kept for compatibility with your routes

  const MyAttendancePage({super.key, required this.data});

  @override
  State<MyAttendancePage> createState() => _MyAttendancePageState();
}

class _MyAttendancePageState extends State<MyAttendancePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // ---- state filled from API ----
  String? _empid;
  Map<String, String> _dayStatusByDate = {}; // 'YYYY-MM-DD' -> status
  int _present = 0,
      _absent = 0,
      _leave = 0,
      // _holiday = 0,  // Unused variable
      _halfDay = 0;
  int _late = 0, _early = 0, _permission = 0;

  @override
  void initState() {
    super.initState();
    _persistTokenIfPresent(); // ensure JWT is available in localStorage
    _bootstrap().then((_) => _loadMonth(_focusedDay));
  }

  /// Copy token from in-memory CompanyData (if any) to localStorage.
  void _persistTokenIfPresent() {
    try {
      final t = CompanyData.token;
      if (t != null && t.isNotEmpty) {
        html.window.localStorage['token'] = t; // primary key this page reads
        html.window.localStorage['jwt'] = t; // backup key
      }
    } catch (_) {}
  }

  // ---------- bootstrap helpers ----------
  Future<void> _bootstrap() async {
    _empid = _tryEmpIdFromModel(widget.data) ??
        _tryEmpIdFromLocalStorage() ??
        await _fetchEmpIdFromAuthMe();

    // Temporary hard fallback (remove once verified end-to-end)
    _empid ??= 'emp014';
  }

  String? _tryEmpIdFromModel(AttendanceData d) {
    try {
      final dyn = d as dynamic;
      final v = (dyn.empId ?? dyn.empid)?.toString();
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    return null;
  }

  String? _tryEmpIdFromLocalStorage() {
    final meRaw = html.window.localStorage['me'];
    if (meRaw != null && meRaw.isNotEmpty) {
      try {
        final me = jsonDecode(meRaw);
        if (me is Map) {
          final ep = me['employeeProfile'];
          if ((me['empid'] ?? '').toString().isNotEmpty) {
            return me['empid'].toString();
          }
          if (ep is Map && (ep['empid'] ?? '').toString().isNotEmpty) {
            return ep['empid'].toString();
          }
        }
      } catch (_) {}
    }
    const keys = ['empid', 'employeeId', 'employee_id', 'empId'];
    for (final k in keys) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  Future<String?> _fetchEmpIdFromAuthMe() async {
    final token = _getToken();
    if (token == null) return null;
    try {
      final uri = Uri.parse('$apiBase/auth/me');
      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      if (resp.statusCode == 200) {
        final me = jsonDecode(resp.body);
        html.window.localStorage['me'] = jsonEncode(me);
        final ep = me['employeeProfile'];
        if ((me['empid'] ?? '').toString().isNotEmpty) {
          return me['empid'].toString();
        }
        if (ep is Map && (ep['empid'] ?? '').toString().isNotEmpty) {
          return ep['empid'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  String? _getToken() {
    const keys = ['token', 'jwt', 'auth_token', 'access_token'];
    for (final k in keys) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) return v;
    }
    try {
      for (final k in html.window.localStorage.keys) {
        final v = html.window.localStorage[k];
        if (v != null && _looksLikeJwt(v)) return v;
      }
    } catch (_) {}
    try {
      for (final k in html.window.sessionStorage.keys) {
        final v = html.window.sessionStorage[k];
        if (v != null && _looksLikeJwt(v)) return v;
      }
    } catch (_) {}
    return null;
  }

  // ---------- API: month view ----------
  Future<void> _loadMonth(DateTime anchor) async {
    if (_empid == null || _empid!.isEmpty) {
      setState(() {
        _present = widget.data.presentCount;
        _absent = widget.data.absentCount;
        _leave = widget.data.leaveCount;
        _late = widget.data.lateCheckIn;
        _early = widget.data.earlyCheckOut;
        _permission = widget.data.permissionCount;
        _dayStatusByDate = {};
      });
      return;
    }

    final y = anchor.year;
    final m = anchor.month.toString().padLeft(2, '0');
    final token = _getToken();
    final uri = Uri.parse('$apiBase/attendance/month-view/$_empid/$y/$m');

    try {
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (resp.statusCode == 200) {
        final j = jsonDecode(resp.body) as Map<String, dynamic>;
        final ds = (j['dayStatuses'] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
        final totals = (j['totals'] as Map).map(
          (k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0),
        );
        final extras = (j['extras'] as Map).map(
          (k, v) => MapEntry(k.toString(), int.tryParse(v.toString()) ?? 0),
        );

        // --------- MERGE WITH RAW ATTENDANCE (force Present if checkIn exists) ----------
        try {
          final detUri = Uri.parse('$apiBase/attendance/employee/$_empid');
          final detResp = await http.get(
            detUri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          );
          if (detResp.statusCode == 200) {
            final list = jsonDecode(detResp.body);
            if (list is List) {
              // for the same year-month, if checkIn is non-empty and not '-' and not Holiday/WeekOff, mark Present
              for (final r in list) {
                final date = (r['date'] ?? '').toString();
                if (date.startsWith('$y-$m')) {
                  final checkIn = (r['checkIn'] ?? '').toString();
                  final isHoliday = (ds[date] == 'Holiday');
                  final isWeekOff = (ds[date] == 'WeekOff');
                  if (checkIn.isNotEmpty &&
                      checkIn != '-' &&
                      !isHoliday &&
                      !isWeekOff) {
                    ds[date] = 'Present';
                  }
                }
              }
            }
          }
        } catch (_) {}
        // -------------------------------------------------------------------------------

        setState(() {
          _dayStatusByDate = ds;
          _present = totals['present'] ?? 0;
          _absent = totals['absent'] ?? 0;
          _leave = totals['leave'] ?? 0;
          // _holiday = totals['holiday'] ?? 0;  // Unused variable
          _halfDay = totals['halfDay'] ?? 0;
          _late = extras['lateCheckin'] ?? 0;
          _early = extras['earlyCheckout'] ?? 0;
          _permission = extras['permissionCount'] ?? 0;
        });
      } else {
        setState(() {
          _present = widget.data.presentCount;
          _absent = widget.data.absentCount;
          _leave = widget.data.leaveCount;
          _late = widget.data.lateCheckIn;
          _early = widget.data.earlyCheckOut;
          _permission = widget.data.permissionCount;
        });
      }
    } catch (_) {
      setState(() {
        _present = widget.data.presentCount;
        _absent = widget.data.absentCount;
        _leave = widget.data.leaveCount;
        _late = widget.data.lateCheckIn;
        _early = widget.data.earlyCheckOut;
        _permission = widget.data.permissionCount;
      });
    }
  }

  // ---------- utils ----------
  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Color? _colorForDay(DateTime day) {
    final status = _dayStatusByDate[_ymd(day)];
    final now = DateTime.now();

    // === Rule: For FUTURE dates, only show Sundays (WeekOff) and Holidays. ===
    if (day.isAfter(DateTime(now.year, now.month, now.day))) {
      if (day.weekday == DateTime.sunday) return kWeekOffColor;
      if (status == 'Holiday') return kHolidayColor;
      return null;
    }

    switch (status) {
      case 'Present':
        return kPresentColor;
      case 'Absent':
        return kAbsentColor;
      case 'Leave':
        return kLeaveColor;
      case 'Holiday':
        return kHolidayColor;
      case 'WeekOff':
        return kWeekOffColor;
      case 'HalfDay':
        return kHalfDayColor;
      default:
        if (widget.data.presentDates.any((d) => isSameDay(d, day))) {
          return kPresentColor;
        }
        if (widget.data.absentDates.any((d) => isSameDay(d, day))) {
          return kAbsentColor;
        }
        return null;
    }
  }

  // ---------- NEW: open detail page ----------
  void _openDetail(DateTime day) async {
    // Do not open detail for future dates
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final dayOnly = DateTime(day.year, day.month, day.day);
    if (dayOnly.isAfter(todayOnly)) return;

    if (_empid == null || _empid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee id not available')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyAttendanceDetailPage(
          empId: _empid!,
          date: day,
          baseUrl: apiBase,
          bearerToken: _getToken(),
        ),
      ),
    );

    // refresh after returning from detail
    _loadMonth(_focusedDay);
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final totalDays = _present + _absent + _leave;
    final totalDaysInMonth = DateUtils.getDaysInMonth(
      _focusedDay.year,
      _focusedDay.month,
    );
    final remainingDays =
        (today.year == _focusedDay.year && today.month == _focusedDay.month)
            ? (totalDaysInMonth - today.day)
            : (today.isBefore(DateTime(_focusedDay.year, _focusedDay.month))
                ? totalDaysInMonth
                : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: kAppBarColor,
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TotalDaysCard(
                  totalDays: totalDays,
                  remainingDays: remainingDays,
                ),
                const SizedBox(height: 20),
                SizedBox(height: 400, child: _buildCalendar()),
                const SizedBox(height: 20),
                const Text(
                  "Legend",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const _LegendRow(),
                const SizedBox(height: 20),
                _buildStatusSummary(),
                const SizedBox(height: 20),
                _buildBottomStats(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: kPrimaryBackgroundTop,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TableCalendar(
        focusedDay: _focusedDay,
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        rowHeight: 44,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _openDetail(selectedDay);
        },
        onPageChanged: (focusedDay) {
          setState(() => _focusedDay = focusedDay);
          _loadMonth(focusedDay);
        },
        calendarStyle: const CalendarStyle(
          weekendTextStyle: TextStyle(color: Colors.red),
          outsideDaysVisible: false,
          isTodayHighlighted: false,
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, _) =>
              _dayCell(day, color: _colorForDay(day)),
          selectedBuilder: (context, day, _) =>
              _dayCell(day, isSelected: true, color: _colorForDay(day)),
          todayBuilder: (context, day, _) =>
              _dayCell(day, isToday: true, color: _colorForDay(day)),
          outsideBuilder: (context, day, _) =>
              _dayCell(day, color: null, dim: true),
        ),
      ),
    );
  }

  /// Status color has priority over today/selected styling.
  Widget _dayCell(
    DateTime day, {
    Color? color,
    bool isSelected = false,
    bool isToday = false,
    bool dim = false,
  }) {
    final Color bg = (color != null)
        ? color
        : (isSelected
            ? kAppBarColor
            : (isToday ? kButtonColor : Colors.transparent));

    final hasBg = bg != Colors.transparent;
    final textColor = hasBg ? kTextColor : (dim ? Colors.grey : Colors.black87);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        final double pad = 6;
        final double dia = (size - pad * 2).clamp(18.0, 999.0);

        return Center(
          child: Container(
            width: dia,
            height: dia,
            decoration: BoxDecoration(
              color: bg.withOpacity(hasBg ? 0.90 : 0.0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: hasBg ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusSummary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        StatusCard("Present", _present.toString(), kPresentColor),
        StatusCard("Absent", _absent.toString(), kAbsentColor),
        StatusCard("Leave", _leave.toString(), kLeaveColor),
      ],
    );
  }

  Widget _buildBottomStats() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          BottomStatBox("Late Check-in", _late.toString()),
          const SizedBox(width: 12),
          BottomStatBox("Early Check-out", _early.toString()),
          const SizedBox(width: 12),
          BottomStatBox("Permission Count", _permission.toString()),
        ],
      ),
    );
  }
}

// ================== WIDGETS (unchanged) ==================
class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 12,
      runSpacing: 10,
      children: [
        LegendCircle(color: kPresentColor, label: "Present"),
        LegendCircle(color: kAbsentColor, label: "Absent"),
        LegendCircle(color: kLeaveColor, label: "Leave"),
        LegendCircle(color: kHolidayColor, label: "Holiday"),
        LegendCircle(color: kWeekOffColor, label: "Week Off"),
        LegendCircle(color: kHalfDayColor, label: "Half Day"),
      ],
    );
  }
}

class LegendCircle extends StatelessWidget {
  final Color color;
  final String label;

  const LegendCircle({required this.color, required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class TotalDaysCard extends StatelessWidget {
  final int totalDays;
  final int remainingDays;

  const TotalDaysCard({
    super.key,
    required this.totalDays,
    required this.remainingDays,
  });

  @override
  Widget build(BuildContext context) {
    final todayFormatted = DateFormat('d MMMM yyyy').format(DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: kPrimaryBackgroundBottom,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(Icons.calendar_month, size: 40, color: kAppBarColor),
          const SizedBox(height: 10),
          Text(
            "Today: $todayFormatted",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Remaining: $remainingDays Days",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const StatusCard(this.label, this.value, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class BottomStatBox extends StatelessWidget {
  final String title;
  final String count;

  const BottomStatBox(this.title, this.count, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: kPrimaryBackgroundBottom,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kAppBarColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 9),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
