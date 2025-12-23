import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;
import 'package:serv_app/models/company_data.dart';

// 🎨 Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class ApplyCompOffForm extends StatefulWidget {
  const ApplyCompOffForm({super.key});

  @override
  State<ApplyCompOffForm> createState() => _ApplyCompOffFormState();
}

class _ApplyCompOffFormState extends State<ApplyCompOffForm> {
  final _formKey = GlobalKey<FormState>();

  String? selectedShift;
  DateTime? workedDate; // 👈 day actually worked (reference only)
  DateTime? compensateDate; // 👈 day to take off (the leave day)
  final reasonController = TextEditingController();

  // Will be populated from the server with the employee's shift
  List<String> shifts = [];

  bool _looksLikeJwt(String v) =>
      RegExp(r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$')
          .hasMatch(v);

  Future<String?> _getJwt() async {
    try {
      final t = CompanyData.token;
      if (t.isNotEmpty) {
        html.window.localStorage.putIfAbsent('token', () => t);
        return t;
      }
    } catch (_) {}
    for (final k in ['jwt', 'token', 'access_token', 'auth_token']) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) return v;
    }
    for (final k in html.window.localStorage.keys) {
      final v = html.window.localStorage[k];
      if (v != null && _looksLikeJwt(v)) return v;
    }
    return null;
  }

  // 🔹 NEW: pull default shift from /auth/me (same approach as Attendance)
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
        shifts = [raw, ...shifts]; // put user's shift at top if custom
      }

      if (!mounted) return;
      setState(() => selectedShift = raw);
    } catch (_) {
      // silent fail; keep defaults
    }
  }

  Future<void> _pickDate({required bool isWorked}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isWorked ? now.subtract(const Duration(days: 1)) : now,
      // Worked date can be back a few months; adjust as you need
      firstDate: isWorked ? now.subtract(const Duration(days: 120)) : now,
      // Compensate date today or future (business rule; tweak if needed)
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isWorked) {
          workedDate = picked;
        } else {
          compensateDate = picked;
        }
      });
    }
  }

  String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() != true) return;

    if (workedDate == null || compensateDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both dates')),
      );
      return;
    }
    // Optional validations:
    if (workedDate!.isAfter(compensateDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Work Date must be before Compensate Date')),
      );
      return;
    }
    if (_ymd(workedDate!) == _ymd(compensateDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Work Date and Compensate Date cannot be the same')),
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

    // Send CompOff as a single-day leave on the compensateDate; include workedDate for reference.
    final url = Uri.parse('$apiBase/leaves');
    final body = {
      'leaveType': 'Comp Off',
      'selectShift': selectedShift,
      'startDate': _ymd(compensateDate!),
      'endDate': _ymd(compensateDate!),
      'workedDate': _ymd(workedDate!),
      'reason': reasonController.text.trim(),
      'leaveCount': 1,
    };

    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comp-Off request submitted')),
        );
        setState(() {
          // Keep selectedShift as-is (user’s default) after submit
          workedDate = null;
          compensateDate = null;
          reasonController.clear();
        });
      } else {
        final msg = res.body.isNotEmpty ? res.body : 'Bad Request';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission Failed: ${res.statusCode} $msg')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  InputDecoration _dec(String label, {bool req = false}) => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        label: RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.black, fontSize: 16),
            children: req
                ? const [
                    TextSpan(text: ' *', style: TextStyle(color: Colors.red))
                  ]
                : [],
          ),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      );

  @override
  void initState() {
    super.initState();
    _loadDefaultShiftFromProfile(); // 🔹 auto-select user's shift
  }

  @override
  Widget build(BuildContext context) {
    final form = Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: _dec('Shift', req: true),
          initialValue: selectedShift,
          items: shifts
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          validator: (v) => v == null ? 'Please select a shift' : null,
          onChanged: (v) => setState(() => selectedShift = v),
        ),
        const SizedBox(height: 16),

        // Work Date (past)
        TextFormField(
          readOnly: true,
          onTap: () => _pickDate(isWorked: true),
          controller: TextEditingController(
            text: workedDate == null
                ? ''
                : DateFormat('dd MMM yyyy').format(workedDate!),
          ),
          validator: (_) =>
              workedDate == null ? 'Please select work date' : null,
          decoration: _dec('Work Date', req: true),
        ),
        const SizedBox(height: 16),

        // Compensate Date (day off)
        TextFormField(
          readOnly: true,
          onTap: () => _pickDate(isWorked: false),
          controller: TextEditingController(
            text: compensateDate == null
                ? ''
                : DateFormat('dd MMM yyyy').format(compensateDate!),
          ),
          validator: (_) => compensateDate == null
              ? 'Please select compensate date'
              : null,
          decoration: _dec('Compensate Date', req: true),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: reasonController,
          maxLines: 3,
          validator: (v) => v == null || v.trim().isEmpty
              ? 'Please enter a reason'
              : null,
          decoration: _dec('Reason', req: true),
        ),
        const SizedBox(height: 32),

        // Submit Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: kButtonColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Submit',
              style: TextStyle(color: kTextColor, fontSize: 16),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Apply CompOff'),
        backgroundColor: kAppBarColor,
        foregroundColor: Colors.white,
      ),
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
              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: form,
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
