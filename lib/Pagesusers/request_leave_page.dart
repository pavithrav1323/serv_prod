import 'dart:convert';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:serv_app/models/company_data.dart';

// Theme Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// Backend base
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

bool _looksLikeJwt(String v) =>
    RegExp(r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$').hasMatch(v);

// Accepts ISO or Firestore {_seconds,_nanoseconds}
DateTime? _ts(dynamic v) {
  try {
    if (v == null) return null;
    if (v is String) return DateTime.parse(v);
    if (v is Map) {
      final s = (v['_seconds'] ?? v['seconds']);
      final ns = (v['_nanoseconds'] ?? v['nanoseconds']) ?? 0;
      if (s is int) {
        final ms = s * 1000 + (ns is int ? ns ~/ 1000000 : 0);
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
      }
    }
  } catch (_) {}
  return null;
}

// ---------- Model ----------
class LeaveTypeRule {
  final String id;
  final String type;
  final int allowedDays;
  final DateTime? fromDate;
  final DateTime? toDate;
  final DateTime? createdAt;
  final bool active;
  final String? shift;

  LeaveTypeRule({
    required this.id,
    required this.type,
    required this.allowedDays,
    required this.fromDate,
    required this.toDate,
    required this.createdAt,
    required this.active,
    required this.shift,
  });

  factory LeaveTypeRule.fromJson(Map<String, dynamic> j) {
    return LeaveTypeRule(
      id: (j['id'] ?? '').toString(),
      type: (j['type'] ?? '').toString(),
      allowedDays: (j['allowedDays'] is num)
          ? (j['allowedDays'] as num).toInt()
          : int.tryParse('${j['allowedDays'] ?? 0}') ?? 0,
      fromDate: _ts(j['fromDate']),
      toDate: _ts(j['toDate']),
      createdAt: _ts(j['createdAt']),
      active: j['active'] != false,
      shift: j['shift']?.toString(),
    );
  }
}

class RequestLeavePage extends StatefulWidget {
  final String? token;
  const RequestLeavePage({super.key, this.token});

  @override
  State<RequestLeavePage> createState() => _RequestLeavePageState();
}

class _RequestLeavePageState extends State<RequestLeavePage> {
  final _formKey = GlobalKey<FormState>();

  String? selectedLeaveType;
  String? selectedShift;
  String? selectedLeaveDuration;
  DateTime? fromDate;
  DateTime? toDate;
  String? errorMessage;

  final TextEditingController reasonController = TextEditingController();

  // Dynamic list of shifts that will be populated from the server
  List<String> shifts = [];

  List<LeaveTypeRule> _rules = [];
  List<String> _typeNames = [];
  LeaveTypeRule? _currentRule;
  bool _loadingTypes = false;

  LeaveTypeRule? _latestRuleForType(String type) {
    final list = _rules.where((r) => r.active && r.type == type).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) {
      final ca =
          a.createdAt ?? a.fromDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cb =
          b.createdAt ?? b.fromDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return cb.compareTo(ca);
    });
    return list.first;
  }

  Future<String?> _getJwt() async {
    if (widget.token != null && widget.token!.isNotEmpty) return widget.token;

    try {
      final t = CompanyData.token;
      if (t != null && t.isNotEmpty) {
        final exists = html.window.localStorage['token'];
        if (exists == null || exists.isEmpty) {
          html.window.localStorage['token'] = t;
        }
        return t;
      }
    } catch (_) {}

    for (final k in ['jwt', 'token', 'access_token', 'auth_token']) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) return v;
    }
    for (int i = 0; i < html.window.localStorage.length; i++) {
      final key = html.window.localStorage.keys.elementAt(i);
      final val = html.window.localStorage[key];
      if (val != null && _looksLikeJwt(val)) return val;
    }
    return null;
  }

  Future<void> _fetchLeaveTypes() async {
    setState(() => _loadingTypes = true);
    final token = await _getJwt();
    if (token == null) {
      setState(() => _loadingTypes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in: missing token')),
      );
      return;
    }

    // cache-bust so we never hit 304 + empty body
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse('$apiBase/leave-types?_ts=$ts');

    try {
      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
        },
      );

      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body) as List;
        final rules = data.map((e) => LeaveTypeRule.fromJson(e)).toList();
        final names =
            rules.where((r) => r.active).map((r) => r.type).toSet().toList();

        setState(() {
          _rules = rules;
          _typeNames = names;
          selectedLeaveType = null;
          selectedLeaveDuration = null;
          fromDate = null;
          toDate = null;
          errorMessage = null;
          _currentRule = null;
          _loadingTypes = false;
        });
      } else {
        setState(() => _loadingTypes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'No leave types available (status: ${resp.statusCode})')),
        );
      }
    } catch (e) {
      setState(() => _loadingTypes = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  // ========== default Shift pulled from /auth/me ==========
  Future<void> _loadDefaultShiftFromProfile() async {
    final token = CompanyData.token.isNotEmpty
        ? CompanyData.token
        : (await _getJwt()) ?? '';
    if (token.isEmpty) return;

    try {
      final res = await http.get(
        Uri.parse('$apiBase/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final profile = (data['employeeProfile'] is Map<String, dynamic>)
          ? data['employeeProfile'] as Map<String, dynamic>
          : const <String, dynamic>{};

      final raw =
          (profile['shiftGroup'] ?? data['shiftGroup'] ?? '').toString().trim();

      if (raw.isEmpty) return;

      if (!shifts.contains(raw)) {
        shifts.insert(0, raw);
      }

      if (!mounted) return;
      setState(() => selectedShift = raw);
    } catch (_) {}
  }
  // =======================================================

  List<String> _durationOptionsFromRule() {
    if (_currentRule == null) return const [];
    final n = _currentRule!.allowedDays;
    if (n <= 0) return const [];
    return List.generate(n, (i) => '${i + 1} day${i == 0 ? '' : 's'}');
  }

  int? _getAllowedDaysFromSelection() {
    if (selectedLeaveDuration == null) return null;
    return int.tryParse(selectedLeaveDuration!.split(' ').first);
  }

  Future<void> pickDate(BuildContext context, bool isFrom) async {
    if (_currentRule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select leave type first')),
      );
      return;
    }
    final rule = _currentRule!;
    final int? allowed = _getAllowedDaysFromSelection();

    final DateTime startClamp = rule.fromDate ?? DateTime.now();
    final DateTime endClamp = rule.toDate ?? DateTime(2100);

    DateTime firstDate = isFrom ? startClamp : (fromDate ?? startClamp);
    DateTime lastDate;
    if (isFrom) {
      lastDate = endClamp;
    } else {
      final start = fromDate ?? startClamp;
      lastDate = endClamp;
      if (allowed != null && allowed > 0) {
        final maxByAllowed = start.add(Duration(days: allowed - 1));
        if (maxByAllowed.isBefore(lastDate)) {
          lastDate = maxByAllowed;
        }
      }
    }

    final DateTime initialDate =
        isFrom ? (fromDate ?? firstDate) : (toDate ?? fromDate ?? firstDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kAppBarColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFrom) {
          fromDate = picked;
          if (allowed != null && allowed > 0) {
            toDate = fromDate!.add(Duration(days: allowed - 1));
            if (rule.toDate != null && toDate!.isAfter(rule.toDate!)) {
              toDate = rule.toDate;
            }
          } else {
            toDate = null;
          }
          errorMessage = null;
        } else {
          if (fromDate != null && picked.isBefore(fromDate!)) {
            errorMessage = "To Date cannot be before From Date";
          } else {
            toDate = picked;
            errorMessage = null;
          }
        }
      });
    }
  }

  String _fmt(DateTime? date) =>
      (date == null) ? '' : DateFormat('yyyy-MM-dd').format(date);

  String _toTitleCase(String s) {
    return s
        .trim()
        .split(RegExp(r'\s+'))
        .map((w) =>
            w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String _canonicalTypeForSubmit(String? t) {
    if (t == null || t.trim().isEmpty) return '';
    final norm = t.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    switch (norm) {
      case 'casualleave':
      case 'casual':
        return 'Casual Leave';
      case 'sickleave':
      case 'sick':
        return 'Sick Leave';
      case 'plannedleave':
      case 'planned':
        return 'Planned Leave';
      case 'emergencyleave':
      case 'emergency':
        return 'Planned Leave';
      case 'halfday':
        return 'Half-Day';
      case 'permissiontime':
      case 'permission':
        return 'Permission Time';
      case 'compoff':
      case 'compoffleave':
        return 'Comp Off';
      default:
        return _toTitleCase(t);
    }
  }

  // Extract a clean, user-friendly error message from backend response
  String _extractErrorMessage(http.Response resp) {
    try {
      if (resp.body.isEmpty) {
        return 'Something went wrong';
      }
      final dynamic body = jsonDecode(resp.body);
      if (body is Map<String, dynamic>) {
        // common fields from typical APIs
        final List<String> candidates = [
          body['message']?.toString() ?? '',
          body['error']?.toString() ?? '',
          body['detail']?.toString() ?? '',
          body['errors'] is List && (body['errors'] as List).isNotEmpty
              ? ((body['errors'] as List).first is Map &&
                      ((body['errors'] as List).first)['message'] != null)
                  ? ((body['errors'] as List).first)['message'].toString()
                  : (body['errors'] as List).first.toString()
              : '',
        ].where((s) => s.trim().isNotEmpty).toList();

        if (candidates.isNotEmpty) return candidates.first;
      } else if (body is String && body.trim().isNotEmpty) {
        return body.trim();
      }
    } catch (_) {
      // body not JSON — show trimmed text
      if (resp.body.trim().isNotEmpty) return resp.body.trim();
    }

    // Fallbacks based on status
    switch (resp.statusCode) {
      case 400:
        return 'Invalid request';
      case 401:
        return 'Authentication required';
      case 403:
        return 'Not permitted';
      case 404:
        return 'Not found';
      case 409:
        return 'Conflict';
      case 500:
        return 'Server error';
      default:
        return 'Something went wrong';
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix the highlighted fields')),
      );
      return;
    }
    if (fromDate == null || toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick both From Date and To Date')),
      );
      return;
    }
    if (toDate!.isBefore(fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('To Date cannot be before From Date')),
      );
      return;
    }

    final token = await _getJwt();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in: missing token')),
      );
      return;
    }

    final typeForSubmit = _canonicalTypeForSubmit(selectedLeaveType);
    if (typeForSubmit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid leave type')),
      );
      return;
    }

    final days = (toDate!.difference(fromDate!).inMilliseconds ~/ 86400000) + 1;

    final payload = {
      'type': typeForSubmit,
      'startDate': fromDate!.toIso8601String(),
      'endDate': toDate!.toIso8601String(),
      'reason': reasonController.text.trim(),
      'shift': selectedShift,
      'days': days,
    };

    final uri = Uri.parse('$apiBase/leaves');
    try {
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Leave request submitted")),
        );
        _formKey.currentState!.reset();
        setState(() {
          selectedLeaveType = null;
          selectedShift = selectedShift; // keep default shift
          selectedLeaveDuration = null;
          fromDate = null;
          toDate = null;
          errorMessage = null;
          reasonController.clear();
          _currentRule = null;
        });
      } else {
        // ⬇️ Show only the clean server message, no "400 {json...}"
        final clean = _extractErrorMessage(resp);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(clean)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchLeaveTypes();
    _loadDefaultShiftFromProfile(); // default shift
  }

  @override
  Widget build(BuildContext context) {
    final durationOptions = _durationOptionsFromRule();

    return Scaffold(
      // ✅ Full-width native AppBar so the title expands to screen width
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        centerTitle: false,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          "Apply Leave",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: kPrimaryBackgroundBottom,
      body: Container(
        constraints: const BoxConstraints.expand(),
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedLeaveType,
                    decoration: _inputDecorationWithLabel("Leave Type"),
                    items: _typeNames
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        selectedLeaveType = val;
                        _currentRule =
                            (val == null) ? null : _latestRuleForType(val);
                        selectedLeaveDuration = null;
                        fromDate = null;
                        toDate = null;
                        errorMessage = null;
                      });
                    },
                    validator: (val) =>
                        val == null ? "Please select leave type" : null,
                  ),
                  if (_loadingTypes)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Loading leave types...'),
                    ),
                  const SizedBox(height: 16),
                  if (selectedLeaveType != null && _currentRule != null)
                    DropdownButtonFormField<String>(
                      initialValue: selectedLeaveDuration,
                      decoration: _inputDecorationWithLabel("Leave Duration"),
                      items: durationOptions
                          .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedLeaveDuration = val;
                          fromDate = null;
                          toDate = null;
                          errorMessage = null;
                        });
                      },
                      validator: (val) =>
                          val == null ? "Select duration" : null,
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedShift, // filled from /auth/me
                    decoration: _inputDecorationWithLabel("Shift"),
                    items: shifts
                        .map((shift) =>
                            DropdownMenuItem(value: shift, child: Text(shift)))
                        .toList(),
                    onChanged: (val) => setState(() => selectedShift = val),
                    validator: (val) => val == null ? "Select shift" : null,
                  ),
                  if (selectedShift != null && selectedShift!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        "Selected Shift: $selectedShift",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => pickDate(context, true),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: _inputDecorationWithLabel("From Date"),
                        controller: TextEditingController(text: _fmt(fromDate)),
                        validator: (val) => val == null || val.isEmpty
                            ? "Select From Date"
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => pickDate(context, false),
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: _inputDecorationWithLabel("To Date"),
                        controller: TextEditingController(text: _fmt(toDate)),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return "Select To Date";
                          }
                          if (errorMessage != null) return errorMessage!;
                          return null;
                        },
                      ),
                    ),
                  ),
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: _inputDecorationWithLabel("Reason")
                        .copyWith(hintText: "Enter your reason"),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Enter reason" : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text("Submit",
                          style: TextStyle(color: kTextColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecorationWithLabel(String labelText) {
    return InputDecoration(
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      label: RichText(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: const [
            TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAppBarColor, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kButtonColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
