// lib/auth/auth_guard.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'package:serv_app/Pagesadmin/company_setup_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Web localStorage shim
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

import 'package:serv_app/models/company_data.dart';

// Destinations
import 'package:serv_app/Pagesusers/login_page.dart';
import 'package:serv_app/Pagesusers/home_screen_page.dart';
import 'package:serv_app/Pagesadmin/admin_dashboard_page.dart';
import 'package:serv_app/Pagesadmin/company_details_page.dart';

// Same base URL you use elsewhere
const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

/// Small helper: read from SharedPreferences first, then (if empty) localStorage.
Future<String> _readPersisted(String key) async {
  final sp = await SharedPreferences.getInstance();
  print("USER TOKEN: ${sp.getString('token')}");
  var v = sp.getString(key) ?? '';
  if (v.isEmpty) {
    try {
      v = html.window.localStorage[key] ?? '';
    } catch (_) {}
  }
  return v;
}

/// Normalize admin company profile shape the same way as in login_page.dart
Map<String, dynamic> _normalizeProfile(dynamic body) {
  final m = (body is Map) ? body : <String, dynamic>{};
  final exists =
      (m['exists'] == true) || (m['filled'] == true) || (m['hasProfile'] == true);
  final data = (m['data'] is Map)
      ? (m['data'] as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  return {'exists': exists, 'data': data, 'raw': m};
}

/// Check if an admin company profile exists (same logic as your login page)
Future<Map<String, dynamic>> _checkCompanyProfile({
  required String token,
  required String adminEmail,
}) async {
  Future<Map<String, dynamic>> treat404() async =>
      {'exists': false, 'data': <String, dynamic>{}, 'raw': <String, dynamic>{}};

  final u1 = Uri.parse('$_apiBase/company/profile/check');
  try {
    final r1 = await http.get(
      u1,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (r1.statusCode == 200) return _normalizeProfile(jsonDecode(r1.body));
    if (r1.statusCode == 404) return treat404();
  } catch (_) {
    // fall through to fallback
  }

  final u2 = Uri.parse('$_apiBase/company/profile')
      .replace(queryParameters: {'email': adminEmail.trim().toLowerCase()});
  final r2 = await http.get(
    u2,
    headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
  );
  if (r2.statusCode == 200) return _normalizeProfile(jsonDecode(r2.body));
  if (r2.statusCode == 404) return treat404();

  dynamic err;
  try {
    err = jsonDecode(r2.body);
  } catch (_) {}
  throw Exception('HTTP ${r2.statusCode} ${r2.reasonPhrase} ${err ?? ''}');
}

/// A minimal splash/decider that sends the user to the right place.
class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  Future<void> _decide() async {
    try {
      // Read saved token/role
      final token = await _readPersisted('token');
      final role = await _readPersisted('role');

      // If no token or expired -> Login
      if (token.isEmpty || JwtDecoder.isExpired(token)) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        return;
      }

      // Keep token globally
      CompanyData.token = token;

      // Try to validate on server, but DON'T auto-logout on network hiccups
      http.Response? meRes;
      try {
        meRes = await http
            .get(
              Uri.parse('$_apiBase/auth/me'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        meRes = null; // network/timeout/etc.
      }

      // If the server explicitly says unauthorized -> go to Login
      if (meRes != null && (meRes.statusCode == 401 || meRes.statusCode == 403)) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
        return;
      }

      // We have either a valid response (200) or a network problem / other codes.
      Map<String, dynamic> me = {};
      String email = '';
      if (meRes != null && meRes.statusCode == 200) {
        me = jsonDecode(meRes.body) as Map<String, dynamic>;
        email = (me['email'] ??
                me['user']?['email'] ??
                me['admin']?['email'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
      } else {
        // No response or non-200: continue offline using cached values.
        email = (await _readPersisted('email')).trim().toLowerCase();
      }

      if (role == 'employee') {
        // Display name: prefer stored 'name', else email prefix
        final storedName = await _readPersisted('name');
        final displayName =
            (storedName.trim().isNotEmpty) ? storedName.trim() : (email.isNotEmpty ? email.split('@').first : 'Employee');

        final docId = await _readPersisted('userDocId');

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userName: displayName,
              employeeDocId: docId,
            ),
          ),
        );
        return;
      }

      if (role == 'admin') {
        // If we got a 200 from /auth/me, try to fetch profile; otherwise, use a safe fallback profile.
        if (meRes != null && meRes.statusCode == 200) {
          try {
            final result =
                await _checkCompanyProfile(token: token, adminEmail: email);
            final exists = result['exists'] == true;
            final companyData =
                (result['data'] as Map<String, dynamic>? ?? const {});

            if (!mounted) return;
            if (exists) {
              final profile = CompanyProfile(
                name: (companyData['companyName'] ?? '').toString(),
                adminName: (companyData['adminName'] ?? '').toString(),
                logoUrl: companyData['logoUrl']?.toString(),
              );

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => AdminDashboard(companyProfile: profile),
                ),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const CompanyDetailsFormPage()),
              );
            }
            return;
          } catch (_) {
            // If profile check fails for some reason, fall back to a minimal profile and keep admin signed in
            if (!mounted) return;
            final fallback = CompanyProfile(name: '', adminName: '', logoUrl: null);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => AdminDashboard(companyProfile: fallback),
              ),
            );
            return;
          }
        } else {
          // Offline/other server issue: still keep admin signed in with a minimal profile
          if (!mounted) return;
          final fallback = CompanyProfile(name: '', adminName: '', logoUrl: null);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AdminDashboard(companyProfile: fallback),
            ),
          );
          return;
        }
      }

      // Unknown role -> Login
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (_) {
      // On any unexpected error, fail safe but DO NOT force logout on transient issues.
      // As a last resort, try cached role; if missing, go to Login.
      final cachedRole = await _readPersisted('role');
      if (cachedRole == 'employee') {
        final name = await _readPersisted('name');
        final docId = await _readPersisted('userDocId');
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              userName: name.isNotEmpty ? name : 'Employee',
              employeeDocId: docId,
            ),
          ),
        );
        return;
      }
      if (cachedRole == 'admin') {
        if (!mounted) return;
        final fallback = CompanyProfile(name: '', adminName: '', logoUrl: null);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AdminDashboard(companyProfile: fallback),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simple splash while deciding
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
