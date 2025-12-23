import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

// If you keep the JWT centrally after login, import it.
// Adjust the path if your project structure differs.
import 'package:serv_app/models/company_data.dart';

// ---- THEME ----
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kTextColor = Colors.white;
const Color kHighlightBoxColor = Color(0xFF655193);

// ---- API ----
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController employeeIdController = TextEditingController();
  final TextEditingController emailController =
      TextEditingController(); // used for Department
  final TextEditingController descriptionController = TextEditingController();

  // ---------------- JWT helpers ----------------
  bool _looksLikeJwt(String v) =>
      RegExp(r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$')
          .hasMatch(v);

  Future<String?> _getJwt() async {
    // 1) From a central holder if your login sets it (recommended for Flutter Web)
    try {
      if (CompanyData.token != null && CompanyData.token!.isNotEmpty) {
        // also persist so other pages can pick it up
        html.window.localStorage['token'] = CompanyData.token!;
        return CompanyData.token!;
      }
    } catch (_) {
      // ignore if not available
    }

    // 2) From localStorage under common keys
    const keys = ['token', 'jwt', 'access_token', 'auth_token'];
    for (final k in keys) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) return v;
    }

    // 3) Scan all keys for something JWT-shaped
    for (final k in html.window.localStorage.keys) {
      final v = html.window.localStorage[k];
      if (v != null && _looksLikeJwt(v)) return v;
    }
    return null;
  }

  // ---------------- submit ----------------
  Future<void> _handleSubmit() async {
    final name = nameController.text.trim();
    final empid = employeeIdController.text.trim();
    final department =
        emailController.text.trim(); // field labeled "Department"
    final description = descriptionController.text.trim();

    if (name.isEmpty ||
        empid.isEmpty ||
        department.isEmpty ||
        description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all fields."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final token = await _getJwt();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Not logged in: No token provided"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Build payload expected by backend
    String adminName = 'Admin';
    try {
      adminName = (CompanyData.userName ??
              CompanyData.name ??
              CompanyData.email ??
              'Admin')
          .toString();
    } catch (_) {}

    final body = {
      "empid": empid,
      "name": name,
      "department": department,
      "description": description,
      "adminname": adminName,
      "date": DateTime.now().toIso8601String(),
    };

    final uri = Uri.parse('$apiBase/rewards');

    try {
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reward entry submitted successfully!"),
            backgroundColor: Color.fromARGB(255, 56, 58, 56),
          ),
        );
        nameController.clear();
        employeeIdController.clear();
        emailController.clear();
        descriptionController.clear();
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Unauthorized (${resp.statusCode}): ${resp.body}"),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Submission failed (${resp.statusCode}): ${resp.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Network error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // ensure no scaffold color peeks through
      extendBody: true, // let body extend to bottom
      appBar: AppBar(
        backgroundColor: kHighlightBoxColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Rewards',
          style: TextStyle(
            color: kTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        elevation: 0,
      ),
      body: Container(
        // 🔑 make the gradient fill the whole screen
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: SafeArea(
          bottom: false, // 🔑 allow the gradient to cover the bottom area
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const SizedBox(height: 20),

                  // 🔽 Form (UI unchanged)
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: employeeIdController,
                    decoration: const InputDecoration(
                      labelText: 'Employee ID',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController, // used as Department
                    decoration: const InputDecoration(
                      labelText: 'Department',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      onPressed: _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kHighlightBoxColor,
                        foregroundColor: kTextColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Submit",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
