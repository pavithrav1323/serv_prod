import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ADDED: http + json + localStorage for API calls
import 'package:http/http.dart' as http;
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// ==== API base (same as the rest of your app) ====
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

// ==== Small helpers (token + headers) ====
String? _readToken() {
  final t1 = html.window.localStorage['token'];
  if (t1 != null && t1.isNotEmpty) return t1;
  final t2 = html.window.localStorage['jwt'];
  if (t2 != null && t2.isNotEmpty) return t2;
  final t3 = html.window.localStorage['authToken'];
  if (t3 != null && t3.isNotEmpty) return t3;
  return null;
}

Map<String, String> _headers() {
  final token = _readToken();
  final h = <String, String>{'Content-Type': 'application/json'};
  if (token != null && token.isNotEmpty) {
    h['Authorization'] = 'Bearer $token';
    h['x-auth-token'] = token;
  }
  return h;
}

// Time format helpers (UI shows 07:00 PM; API gets "19:00")
String _to24h(String ui) {
  try {
    final parts = ui.split(' ');
    if (parts.length != 2) return ui;
    final time = parts[0];
    final ampm = parts[1].toUpperCase();
    final hhmm = time.split(':');
    int hh = int.tryParse(hhmm[0]) ?? 0;
    final mm = hhmm.length > 1 ? int.tryParse(hhmm[1]) ?? 0 : 0;
    if (ampm == 'PM' && hh != 12) hh += 12;
    if (ampm == 'AM' && hh == 12) hh = 0;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  } catch (_) {
    return ui;
  }
}

String _toDisplay(String hhmm24) {
  try {
    final parts = hhmm24.split(':');
    int hh = int.parse(parts[0]);
    final mm = int.parse(parts[1]);
    final ampm = hh >= 12 ? 'PM' : 'AM';
    if (hh == 0) hh = 12;
    if (hh > 12) hh -= 12;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')} $ampm';
  } catch (_) {
    return hhmm24;
  }
}

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _parseCreatedAt(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is String) {
    final t = DateTime.tryParse(v);
    if (t != null) return t;
  }
  return DateTime.now();
}

// Map UI report names to API enum
String _mapReportTypeToApi(String uiValue) {
  final v = uiValue.trim().toLowerCase();
  if (v == 'check-in' || v == 'checkin') return 'Check-In';
  if (v == 'check-out' || v == 'checkout') return 'Check-Out';
  if (v == 'late check-in' || v == 'late checkin') return 'Late Check-In';
  if (v == 'absent') return 'Absent';
  if (v == 'on leave' || v == 'leave') return 'Absent';
  return 'Check-In';
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Report Scheduler',
      debugShowCheckedModeBanner: false,
      home: ReportSchedulerPage(),
    );
  }
}

class ScheduledReport {
  final String id;
  final String scheduleName;
  final String createdDate;
  final String schedulerTime;

  ScheduledReport({
    required this.id,
    required this.scheduleName,
    required this.createdDate,
    required this.schedulerTime,
  });

  factory ScheduledReport.fromServer(Map<String, dynamic> j) {
    final created = _parseCreatedAt(j['createdAt']);
    final rawTime = (j['scheduleTime'] ?? '').toString();
    return ScheduledReport(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      scheduleName: (j['name'] ?? j['scheduleName'] ?? '').toString(),
      createdDate: _formatDate(created),
      schedulerTime: rawTime.isEmpty ? '' : _toDisplay(rawTime),
    );
  }

  static Map<String, dynamic> toCreateBody({
    required String name,
    required String reportType,
    required String uiTime,
    required String email,
    String? mobile,
  }) {
    final hhmm24 = _to24h(uiTime);
    return {
      'name': name,
      'reportType': reportType,
      'scheduleTime': hhmm24,
      'recipient': email, // REQUIRED by backend
      'recipientEmail': email, // extra tolerance
      if (mobile != null && mobile.trim().isNotEmpty)
        'recipientMobile': mobile.trim(),
      'templateId': 'default-template',
    };
  }
}

class ReportSchedulerPage extends StatefulWidget {
  const ReportSchedulerPage({super.key});

  @override
  State<ReportSchedulerPage> createState() => _ReportSchedulerPageState();
}

class _ReportSchedulerPageState extends State<ReportSchedulerPage> {
  List<ScheduledReport> scheduledReports = [];

  // === API: load, create, delete ===
  Future<void> _fetchSchedules() async {
    try {
      // FIX: no double /api
      final res =
          await http.get(Uri.parse('$apiBase/reports'), headers: _headers());
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List list = body is List
            ? body
            : (body is Map && body['data'] is List
                ? body['data']
                : <dynamic>[]);
        final items = list
            .map((e) => ScheduledReport.fromServer(e as Map<String, dynamic>))
            .toList();
        setState(() => scheduledReports = items);
      }
    } catch (_) {}
  }

  Future<bool> _createOnServer({
    required String name,
    required String reportType,
    required String uiTime,
    required String email,
    String? mobile,
  }) async {
    try {
      final body = jsonEncode(
        ScheduledReport.toCreateBody(
          name: name,
          reportType: reportType,
          uiTime: uiTime,
          email: email,
          mobile: mobile,
        ),
      );
      // FIX: no double /api
      final res = await http.post(Uri.parse('$apiBase/reports'),
          headers: _headers(), body: body);
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _deleteOnServer(String id) async {
    try {
      // FIX: no double /api
      final res = await http.delete(Uri.parse('$apiBase/reports/$id'),
          headers: _headers());
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSchedules();
  }

  void _deleteReport(String id) async {
    final ok = await _deleteOnServer(id);
    if (ok) {
      setState(() => scheduledReports.removeWhere((r) => r.id == id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Schedule deleted')));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Delete failed')));
      }
    }
  }

  Future<void> _addReportAndRefresh(ScheduledReport _) async {
    await _fetchSchedules();
  }

  void _showCreateScheduleModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: FractionallySizedBox(
          alignment: Alignment.center,
          widthFactor: 0.85,
          heightFactor: 0.8,
          child:
              CreateScheduledReportModal(onReportCreated: _addReportAndRefresh),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        title:
            const Text('Report Scheduler', style: TextStyle(color: kTextColor)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor,
                        foregroundColor: kTextColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text("Create Report Scheduler"),
                      onPressed: _showCreateScheduleModal,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          flex: 3,
                          child: Text('Report Schedule Name',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(
                          flex: 2,
                          child: Text('Created Date',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(
                          flex: 2,
                          child: Text('Scheduled Time',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(
                          flex: 1,
                          child: Text('Delete',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (scheduledReports.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                          child: Text('No scheduled reports yet',
                              style: TextStyle(color: Colors.black54))),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: scheduledReports.length,
                      itemBuilder: (context, index) {
                        final report = scheduledReports[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Expanded(
                                  flex: 3,
                                  child: Text(report.scheduleName,
                                      style: const TextStyle(fontSize: 12))),
                              Expanded(
                                  flex: 2,
                                  child: Text(report.createdDate,
                                      style: const TextStyle(fontSize: 12))),
                              Expanded(
                                  flex: 2,
                                  child: Text(report.schedulerTime,
                                      style: const TextStyle(fontSize: 12))),
                              Expanded(
                                flex: 1,
                                child: IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: Colors.red[400]),
                                  onPressed: () => _deleteReport(report.id),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CreateScheduledReportModal extends StatefulWidget {
  final Future<void> Function(ScheduledReport) onReportCreated;

  const CreateScheduledReportModal({super.key, required this.onReportCreated});

  @override
  State<CreateScheduledReportModal> createState() =>
      _CreateScheduledReportModalState();
}

class _CreateScheduledReportModalState
    extends State<CreateScheduledReportModal> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  String? selectedReportType;
  String? selectedTime;

  bool isValidEmail(String email) =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}\$').hasMatch(email);

  Future<bool> _createOnServer({
    required String name,
    required String reportType,
    required String uiTime,
    required String email,
    String? mobile,
  }) async {
    try {
      final body = jsonEncode(
        ScheduledReport.toCreateBody(
          name: name,
          reportType: reportType,
          uiTime: uiTime,
          email: email,
          mobile: mobile,
        ),
      );
      // FIX: no double /api
      final res = await http.post(Uri.parse('$apiBase/reports'),
          headers: _headers(), body: body);
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<void> _createSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select schedule time")));
      return;
    }
    if (selectedReportType == null || selectedReportType!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please select report type")));
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty || !isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter a valid recipient email")));
      return;
    }

    final ok = await _createOnServer(
      name: _nameController.text.trim(),
      reportType: _mapReportTypeToApi(selectedReportType!),
      uiTime: selectedTime!,
      email: email,
      mobile: _mobileController.text.trim().isEmpty
          ? null
          : _mobileController.text.trim(),
    );

    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Create failed')));
      }
      return;
    }

    final display = ScheduledReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      scheduleName: _nameController.text.trim(),
      createdDate: _formatDate(DateTime.now()),
      schedulerTime: selectedTime!,
    );

    await widget.onReportCreated(display);
    if (mounted) Navigator.pop(context);
  }


  InputDecoration denseInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
              decoration: const BoxDecoration(
                color: kAppBarColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: kTextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Report Scheduler',
                      style: TextStyle(
                          color: kTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(fontSize: 12),
                        decoration: denseInputDecoration('Schedule Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter schedule name'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: denseInputDecoration('Choose Report List'),
                        style: const TextStyle(fontSize: 12),
                        items: [
                          'Check-in',
                          'Check-out',
                          'Late check-in',
                          'On leave',
                          'Absent'
                        ]
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => selectedReportType = val),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        style: const TextStyle(fontSize: 12),
                        decoration: denseInputDecoration('Email (Optional)'),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final ok =
                                RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$')
                                    .hasMatch(value.trim());
                            if (!ok) return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _mobileController,
                        style: const TextStyle(fontSize: 12),
                        decoration: denseInputDecoration('Mobile (Optional)'),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final ok =
                                RegExp(r'^[0-9]{10}$').hasMatch(value.trim());
                            if (!ok) {
                              return 'Please enter a valid 10 digit mobile number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: denseInputDecoration('Schedule Time'),
                        style: const TextStyle(fontSize: 12),
                        items: ['07:00 PM', '08:00 PM', '09:00 PM', '10:00 PM']
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setState(() => selectedTime = val),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          SizedBox(
                            width: 70,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: kButtonColor,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                              onPressed: _createSchedule,
                              child: const Text('Create',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
