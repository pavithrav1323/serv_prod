import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html; // for Flutter Web localStorage
import 'package:serv_app/models/company_data.dart';

// 🎨 Your Color Constants
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

/// Match your Node server port
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class ApplyHalfDayForm extends StatefulWidget {
  const ApplyHalfDayForm({super.key});

  @override
  State<ApplyHalfDayForm> createState() => _ApplyHalfDayFormState();
}

class _ApplyHalfDayFormState extends State<ApplyHalfDayForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String? selectedShift;
  DateTime? fromDate; // Work Date
  DateTime? replaceWorkDate; // Compensate Date
  final TextEditingController reasonController = TextEditingController();

  // Will be populated from the server with the employee's shift
  List<String> shifts = [];

  // ---- JWT helpers (same pattern as other pages) ----
  bool _looksLikeJwt(String v) => RegExp(
        r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$',
      ).hasMatch(v);

  Future<String?> _getJwt() async {
    // 1) In-memory token from your login flow
    try {
      final t = CompanyData.token;
      if (t != null && t.isNotEmpty) {
        html.window.localStorage.putIfAbsent('token', () => t);
        return t;
      }
    } catch (_) {}

    // 2) Common localStorage keys
    for (final k in ['jwt', 'token', 'access_token', 'auth_token']) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) return v;
    }

    // 3) Any JWT-looking value in localStorage
    for (final k in html.window.localStorage.keys) {
      final v = html.window.localStorage[k];
      if (v != null && _looksLikeJwt(v)) return v;
    }
    return null;
  }

  // NEW: pull employee's current shift from /auth/me and preselect it
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

      // Ensure it's present in the dropdown; insert once if custom.
      if (!shifts.contains(raw)) {
        shifts.insert(0, raw);
      }

      if (!mounted) return;
      setState(() => selectedShift = raw);
    } catch (_) {
      // ignore — keep manual selection if request fails
    }
  }

  Future<void> _pickDate(bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
        } else {
          replaceWorkDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true) return;

    if (fromDate == null || replaceWorkDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please select both dates')),
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

    // NOTE: Endpoint left unchanged per your request – only shift auto-fill added.
    final url = Uri.parse('$apiBase/leaves');

    final body = {
      'type': 'Comp Off',
      'selectShift': selectedShift,
      // Map Work Date -> startDate, Compensate Date -> endDate
      'startDate': fromDate!.toIso8601String(),
      'endDate': replaceWorkDate!.toIso8601String(),
      'reason': reasonController.text.trim(),
      // Force a single-off credit even if dates differ
      'leaveCount': 1,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      // ──────────────── CHANGED: friendly message handling ────────────────
      Map<String, dynamic>? j;
      try {
        j = jsonDecode(response.body) as Map<String, dynamic>?;
      } catch (_) {
        j = null;
      }

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CompOff Request Submitted Successfully'),
          ),
        );
        setState(() {
          selectedShift = selectedShift; // keep default after submit
          fromDate = null;
          replaceWorkDate = null;
          reasonController.clear();
        });
        return;
      }

      // Backend may return 200 with {"message": "..."} for overlap/duplicate.
      if (response.statusCode == 200 && (j?['message'] is String)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(j!['message'] as String)),
        );
        return;
      }

      // Other errors: show clean text only (no status code / raw JSON)
      final msg =
          (j?['error'] ?? j?['message'] ?? 'Something went wrong').toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      // ─────────────────────────────────────────────────────────────────────
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Network error: $e')));
    }
  }

  InputDecoration buildInputDecoration(
    String label, {
    bool isRequired = false,
  }) {
    return InputDecoration(
      label: RichText(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          children: isRequired
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ]
              : [],
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

  @override
  void initState() {
    super.initState();
    _loadDefaultShiftFromProfile(); // <-- NEW: auto-fill shift from employee profile
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundBottom, // Ensure background color fills any white space
      appBar: AppBar(
        title: const Text("Apply CompOff"),
        backgroundColor: kAppBarColor,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                /// 🔽 Shift Dropdown (now prefilled)
                DropdownButtonFormField<String>(
                  decoration: buildInputDecoration("Shift", isRequired: true),
                  initialValue: selectedShift,
                  items: shifts
                      .map((shift) =>
                          DropdownMenuItem(value: shift, child: Text(shift)))
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Please select a shift' : null,
                  onChanged: (value) => setState(() => selectedShift = value),
                ),
                const SizedBox(height: 16),

                /// 📅 Work Date
                TextFormField(
                  readOnly: true,
                  onTap: () => _pickDate(true),
                  controller: TextEditingController(
                    text: fromDate != null
                        ? DateFormat('dd MMM yyyy').format(fromDate!)
                        : '',
                  ),
                  validator: (_) =>
                      fromDate == null ? 'Please select work date' : null,
                  decoration: buildInputDecoration(
                    "Work Date",
                    isRequired: true,
                  ),
                ),
                const SizedBox(height: 16),

                /// 🔁 Compensate Date
                TextFormField(
                  readOnly: true,
                  onTap: () => _pickDate(false),
                  controller: TextEditingController(
                    text: replaceWorkDate != null
                        ? DateFormat('dd MMM yyyy').format(replaceWorkDate!)
                        : '',
                  ),
                  validator: (_) => replaceWorkDate == null
                      ? 'Please select compensate date'
                      : null,
                  decoration: buildInputDecoration(
                    "Compensate Date",
                    isRequired: true,
                  ),
                ),
                const SizedBox(height: 16),

                /// 📝 Reason
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a reason'
                      : null,
                  decoration: buildInputDecoration("Reason", isRequired: true),
                ),
                const SizedBox(height: 32),

                /// ✅ Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kButtonColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Submit",
                      style: TextStyle(color: kTextColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
