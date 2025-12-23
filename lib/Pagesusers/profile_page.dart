import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Web localStorage (ignored on mobile/desktop)
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;
    // ---------- import your destination pages (so taps push correctly) ----------
import 'change_password_page.dart';
import 'multi_language_page.dart';
import 'privacy_policy_page.dart';
import 'terms_and_conditions_page.dart';
import 'permissions_page.dart';
import 'feedback_page.dart';
import 'log_out_page.dart';

/// ===== Service root (do NOT include trailing /api) =====
const String _host = 'https://api-zmj7dqloiq-el.a.run.app';
Uri _u(String path) => Uri.parse('$_host$path'); // use like /api/auth/me



class ProfilePage extends StatefulWidget {
  /// Kept for backward compatibility; not used.
  /// Do not remove unless you have updated all callers.
  const ProfilePage({super.key, required Map userData});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = false;
  String? _error;

  /// Render data for the header; starts with placeholders only (no hard-coded user).
  Map<String, String> _userData = const {
    "name": "-",
    "id": "-",
    "role": "-",
    "email": "-",
    "phone": "-",
  };

  final List<Map<String, dynamic>> settings = const [
    {"icon": Icons.lock, "label": "Change Password"},
    {"icon": Icons.language, "label": "Language"},
    {"icon": Icons.privacy_tip, "label": "Privacy Policy"},
    {"icon": Icons.article, "label": "Terms & Conditions"},
    {"icon": Icons.settings, "label": "Permissions"},
    {"icon": Icons.feedback, "label": "Feedback"},
    {"icon": Icons.logout, "label": "Log Out", "color": Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<String?> _getToken() async {
    // Web localStorage first
    try {
      final t = html.window.localStorage['token'];
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {}
    // Mobile/desktop
    final sp = await SharedPreferences.getInstance();
    final t2 = sp.getString('token');
    return (t2 != null && t2.isNotEmpty) ? t2 : null;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No token found. Please log in.';
        });
        return;
      }

      final res = await http.get(
        _u('/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = res.statusCode == 401 || res.statusCode == 403
              ? 'Unauthorized. Please log in again.'
              : 'Could not load profile (status ${res.statusCode}).';
        });
        return;
      }

      final payload = jsonDecode(res.body) as Map<String, dynamic>;

      // Normalize keys coming from different backends
      String name = (payload['name'] ?? payload['fullName'] ?? '').toString();
      String empid =
          (payload['empid'] ?? payload['empId'] ?? payload['employeeId'] ?? '')
              .toString();
      String role = (payload['role'] ?? '').toString();
      String email = (payload['email'] ?? '').toString();
      String phone = (payload['phone'] ?? payload['mobile'] ?? '').toString();

      if ((name.isEmpty || email.isEmpty) && payload.containsKey('employeeProfile')) {
        final u = (payload['employeeProfile'] as Map).cast<String, dynamic>();
        name = (u['name'] ?? u['fullName'] ?? name).toString();
        empid = (u['empid'] ?? u['empId'] ?? u['employeeId'] ?? empid).toString();
        role = (payload['role'] ?? role).toString();
        email = (u['email'] ?? email).toString();
        phone = (u['phone'] ?? u['mobile'] ?? phone).toString();
      }

      // Cache email for Change Password page
      final sp = await SharedPreferences.getInstance();
      if (email.isNotEmpty) {
        await sp.setString('email', email.toLowerCase());
      }

      final normalized = <String, String>{
        "name": name.isNotEmpty ? name : '-',
        "id": empid.isNotEmpty ? empid : '-',
        "role": role.isNotEmpty ? role : '-',
        "email": email.isNotEmpty ? email : '-',
        "phone": phone.isNotEmpty ? phone : '-',
      };

      setState(() {
        _userData = normalized;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Network error: $e';
      });
    }
  }

  void _openSetting(String label) {
    if (label == "Change Password") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
      );
    } else if (label == "Language") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MultiLanguagePage()),
      );
    } else if (label == "Privacy Policy") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
      );
    } else if (label == "Terms & Conditions") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TermsAndConditionsPage()),
      );
    } else if (label == "Permissions") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PermissionsPage()),
      );
    } else if (label == "Feedback") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FeedbackPage()),
      );
    } else if (label == "Log Out") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LogOutPage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label tapped')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 🔙 Back Button
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // 🧑‍🎓 Profile Header (UI unchanged)
            Container(
              color: const Color.fromARGB(255, 140, 110, 175),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.pink[100],
                    child: Text(
                      _userData['name'] != null &&
                              _userData['name']!.isNotEmpty &&
                              _userData['name'] != '-'
                          ? _userData['name']![0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _userData['name'] ?? '-',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_loading)
                              const SizedBox(
                                height: 16,
                                width: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        // ID | Role
                        Text(
                          '${_userData['id'] ?? '-'} | ${_userData['role'] ?? '-'}',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Email
                        Text(
                          _userData['email'] ?? '-',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Phone
                        Text(
                          _userData['phone'] ?? '-',
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ⚙️ Settings List
            Expanded(
              child: ListView.builder(
                itemCount: settings.length,
                itemBuilder: (context, index) {
                  final item = settings[index];
                  final String label = item['label'];
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Material( // ensures ripple + tap works over decorated Container
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openSetting(label),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(item['icon'],
                                color: item['color'] ?? Colors.black),
                            title: Text(
                              label,
                              style: TextStyle(
                                color: item['color'] ?? Colors.black,
                                fontWeight: label == "Log Out"
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 14),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
