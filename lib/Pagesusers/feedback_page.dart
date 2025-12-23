import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Theme Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);

// 👉 Adjust if your backend origin/port is different
const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _feedbackController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _empId; // e.g. EMP001
  String? _empName; // e.g. John Doe
  String? _userDocId; // optional users/<id>
  String? _jwt; // stored auth token if present

  @override
  void initState() {
    super.initState();
    _loadUserMeta();
  }

  Future<void> _loadUserMeta() async {
    final sp = await SharedPreferences.getInstance();

    // Common token keys your app may already use
    _jwt = sp.getString('token') ?? sp.getString('authToken');

    // 1) Direct simple keys (most common)
    _empId = sp.getString('empid') ?? sp.getString('employeeId');
    _empName = sp.getString('name') ?? sp.getString('employeeName');
    _userDocId = sp.getString('userDocId') ?? sp.getString('userId');

    // 2) Try to parse a cached profile json if present
    if ((_empId == null || _empId!.isEmpty) ||
        (_empName == null || _empName!.isEmpty)) {
      final profileJson =
          sp.getString('employeeProfile') ?? sp.getString('profile');
      if (profileJson != null && profileJson.isNotEmpty) {
        try {
          final p = jsonDecode(profileJson);
          if (p is Map) {
            _empId ??= (p['empid'] ?? p['employeeId'] ?? p['id'])?.toString();
            _empName ??=
                (p['name'] ?? p['employeeName'] ?? p['fullName'])?.toString();
          }
        } catch (_) {}
      }
    }

    // 3) Final fallback: call /auth/me if token is available
    if (((_empId ?? '').isEmpty || (_empName ?? '').isEmpty) &&
        (_jwt != null && _jwt!.isNotEmpty)) {
      try {
        final meRes = await http.get(
          Uri.parse('$_apiBase/auth/me'),
          headers: {'Authorization': 'Bearer $_jwt'},
        );
        if (meRes.statusCode == 200) {
          final m = jsonDecode(meRes.body);
          if (m is Map) {
            // Try common locations for id/name in your API
            final profile =
                (m['employeeProfile'] is Map) ? m['employeeProfile'] as Map : m;

            _empId ??= (profile['empid'] ??
                    profile['employeeId'] ??
                    profile['id'] ??
                    m['empid'] ??
                    m['employeeId'] ??
                    m['id'])
                ?.toString();

            _empName ??= (profile['name'] ?? m['name'])?.toString();

            // Cache for next time
            if (_empId != null) await sp.setString('empid', _empId!);
            if (_empName != null) await sp.setString('name', _empName!);
            await sp.setString('employeeProfile', jsonEncode(profile));
          }
        }
      } catch (_) {
        // ignore network errors here; UI will show tip if still missing
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    final message = _feedbackController.text.trim();
    if (message.isEmpty) return;

    // Require at least empid+name OR userDocId
    final hasIdentity =
        (((_empId ?? '').isNotEmpty && (_empName ?? '').isNotEmpty) ||
            ((_userDocId ?? '').isNotEmpty));

    if (!hasIdentity) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'User id not found. Save "empid" & "name" in SharedPreferences during login, '
            'or save Firestore users doc id as "userDocId".',
          ),
        ),
      );
      return;
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    // Pass token if we have one (helps if your route is protected)
    if ((_jwt ?? '').isNotEmpty) headers['Authorization'] = 'Bearer $_jwt';

    // Also include header shortcuts if your backend supports them
    if ((_empId ?? '').isNotEmpty) headers['x-empid'] = _empId!;
    if ((_empName ?? '').isNotEmpty) headers['x-name'] = _empName!;
    if ((_userDocId ?? '').isNotEmpty) headers['x-user-id'] = _userDocId!;

    // Send a consistent body your backend can store directly
    final payload = {
      'message': message,
      'empid': _empId,
      'name': _empName,
      // Client timestamp (server can override with serverTime if desired)
      'date': DateTime.now().toIso8601String(),
    };

    try {
      final res = await http.post(
        Uri.parse('$_apiBase/feedback'),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Feedback submitted successfully!')),
        );
        _feedbackController.clear();
      } else {
        String err = 'Submit failed: ${res.statusCode}';
        try {
          final m = jsonDecode(res.body);
          if (m is Map && m['error'] != null) {
            err = 'Submit failed: ${m['error']}';
          }
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        centerTitle: false,
        backgroundColor: kAppBarColor,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                "Give us your valuable feedback",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _feedbackController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: "Type your feedback here...",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter some feedback';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitFeedback,
                child: const Text('Submit'),
              ),
              const SizedBox(height: 12),
              if (((_empId ?? '').isEmpty && (_userDocId ?? '').isEmpty))
                const Text(
                  'Tip: store "empid" & "name" OR "userDocId" in SharedPreferences during login.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
