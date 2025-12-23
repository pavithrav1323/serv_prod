import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;
import 'package:serv_app/models/company_data.dart';

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

/// Backend base
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class OverTimePage extends StatefulWidget {
  final bool isPopup;
  const OverTimePage({super.key, this.isPopup = false});

  @override
  State<OverTimePage> createState() => _OverTimePageState();
}

class _OverTimePageState extends State<OverTimePage> {
  final _formKey = GlobalKey<FormState>();

  String? selectedShift;
  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  // Will be populated from the server with the employee's shift
  final List<String> shifts = [];

  // Reason controller
  final TextEditingController reasonController = TextEditingController();

  bool _submitting = false;

  // ---------- JWT helpers ----------
  bool _looksLikeJwt(String v) =>
      RegExp(r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$')
          .hasMatch(v);

  Future<String?> _getJwt() async {
    // 1) CompanyData (in-memory)
    try {
      final t = CompanyData.token;
      if (t != null && t.isNotEmpty) {
        html.window.localStorage.putIfAbsent('token', () => t);
        debugPrint('[Overtime] token from CompanyData (${t.length})');
        return t;
      }
    } catch (_) {}

    // 2) common localStorage keys
    for (final k in ['jwt', 'token', 'access_token', 'auth_token']) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) {
        debugPrint('[Overtime] token from localStorage "$k" (${v.length})');
        return v;
      }
    }

    // 3) scan any key that looks like a JWT
    for (final k in html.window.localStorage.keys) {
      final v = html.window.localStorage[k];
      if (v != null && _looksLikeJwt(v)) {
        debugPrint('[Overtime] token from localStorage "$k" (${v.length})');
        return v;
      }
    }

    debugPrint('[Overtime] No token found');
    return null;
  }

  // ========== NEW: pull employee's default shift from /auth/me ==========
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

      // ensure it's in the dropdown
      if (!shifts.contains(raw)) {
        shifts.insert(0, raw);
      }

      if (!mounted) return;
      setState(() => selectedShift = raw);
    } catch (_) {
      // ignore; keep manual selection if call fails
    }
  }
  // =====================================================================

  Future<void> pickTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (startTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (endTime ?? const TimeOfDay(hour: 17, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
          if (endTime != null && !_isAfter(startTime!, endTime!)) {
            endTime = null;
          }
        } else {
          endTime = picked;
        }
      });
    }
  }

  bool _isAfter(TimeOfDay a, TimeOfDay b) =>
      b.hour > a.hour || (b.hour == a.hour && b.minute > a.minute);

  String _formatTimeDisplay(TimeOfDay? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, t.hour, t.minute);
    return DateFormat.jm().format(dt); // UI only
  }

  String _to24h(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m'; // HH:mm for backend
  }

  InputDecoration inputBoxDecoration(String label) {
    return InputDecoration(
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: Colors.white,
      label: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          children: [
            TextSpan(text: label),
            const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
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

  Future<void> _submitForm() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;

    if (selectedDate == null ||
        selectedShift == null ||
        startTime == null ||
        endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }
    if (!_isAfter(startTime!, endTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End must be after start')),
      );
      return;
    }

    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason')),
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

    final url = Uri.parse('$apiBase/leaves');

    final body = {
      "type": "Overtime",
      "selectDate": DateFormat('yyyy-MM-dd').format(selectedDate!),
      "selectShift": selectedShift!,
      "startTime": _to24h(startTime!), // HH:mm
      "endTime": _to24h(endTime!),     // HH:mm
      "reason": reason,
    };

    setState(() => _submitting = true);
    try {
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      debugPrint('[Overtime] status=${resp.statusCode}');
      debugPrint('[Overtime] body=${resp.body}');

      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Overtime request submitted!"),
            backgroundColor: Colors.green,
          ),
        );
        if (Navigator.canPop(context)) Navigator.of(context).pop();
      } else if (resp.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Forbidden: Employees only")),
        );
      } else {
        final msg = resp.body.isNotEmpty ? resp.body : 'Unexpected error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed (${resp.statusCode}): $msg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDefaultShiftFromProfile(); // NEW: prefill shift from employee profile
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar
              Container(
                color: kAppBarColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text(
                      "Apply Overtime",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Form + Submit button (button placed right after fields)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Date picker
                        GestureDetector(
                          onTap: () async {
                            final now = DateTime.now();
                            final d = await showDatePicker(
                              context: context,
                              firstDate: now,
                              lastDate: now.add(const Duration(days: 30)),
                              initialDate: now,
                            );
                            if (d != null) setState(() => selectedDate = d);
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: TextEditingController(
                                text: selectedDate == null
                                    ? ''
                                    : DateFormat('dd/MM/yyyy')
                                        .format(selectedDate!),
                              ),
                              decoration: inputBoxDecoration("Select Date"),
                              validator: (_) =>
                                  selectedDate == null ? 'Select a date' : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Shift dropdown (prefilled from /auth/me)
                        DropdownButtonFormField<String>(
                          decoration: inputBoxDecoration("Select Shift"),
                          initialValue: selectedShift,
                          items: shifts
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => setState(() => selectedShift = v),
                          validator: (v) => v == null ? 'Select a shift' : null,
                        ),
                        const SizedBox(height: 12),

                        // Start time
                        GestureDetector(
                          onTap: () => pickTime(context, true),
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: TextEditingController(
                                  text: _formatTimeDisplay(startTime)),
                              decoration: inputBoxDecoration("Start Time"),
                              validator: (_) =>
                                  startTime == null ? 'Select start time' : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // End time
                        GestureDetector(
                          onTap: () => pickTime(context, false),
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: TextEditingController(
                                  text: _formatTimeDisplay(endTime)),
                              decoration: inputBoxDecoration("End Time"),
                              validator: (_) {
                                if (endTime == null) return 'Select end time';
                                if (startTime != null &&
                                    !_isAfter(startTime!, endTime!)) {
                                  return 'End must be after start';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Reason (required)
                        TextFormField(
                          controller: reasonController,
                          maxLines: 2,
                          decoration: inputBoxDecoration("Reason")
                              .copyWith(hintText: "Enter reason"),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Enter reason'
                                  : null,
                        ),

                        const SizedBox(height: 24),

                        // ▶️ Submit (now directly under fields)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kButtonColor,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _submitting ? "Submitting..." : "Submit",
                              style: const TextStyle(
                                color: kTextColor,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // (No bottom button here anymore)
            ],
          ),
        ),
      ),
    );
  }
}
