import 'dart:convert';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart'
    as html; // for Flutter Web localStorage
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ✅ Use the same model you use in the rest of the app
import 'package:serv_app/models/company_data.dart';

// Match your Node server base
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class UserRewardsPage extends StatefulWidget {
  const UserRewardsPage({super.key});

  @override
  State<UserRewardsPage> createState() => _UserRewardsPageState();
}

class _UserRewardsPageState extends State<UserRewardsPage> {
  late Future<List<Map<String, dynamic>>> _rewardsFuture;

  @override
  void initState() {
    super.initState();
    _rewardsFuture = _fetchRewards();
  }

  // -------------------- JWT helpers --------------------

  bool _looksLikeJwt(String v) => RegExp(
        r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$',
      ).hasMatch(v);

  Future<String?> _getJwt() async {
    // 1) From CompanyData (in-memory)
    try {
      final t = CompanyData.token; // adjust if field differs
      if (t != null && t.isNotEmpty) {
        // persist it for later web tabs
        final existing = html.window.localStorage['token'];
        if (existing == null || existing.isEmpty) {
          html.window.localStorage['token'] = t;
        }
        debugPrint('[Rewards] token from CompanyData (${t.length})');
        return t;
      }
    } catch (_) {}

    // 2) From common localStorage keys
    const keys = ['token', 'jwt', 'access_token', 'auth_token'];
    for (final k in keys) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) {
        debugPrint('[Rewards] token from localStorage["$k"] (${v.length})');
        return v;
      }
    }

    // 3) Scan localStorage values; pick first JWT-looking string
    try {
      for (int i = 0; i < html.window.localStorage.length; i++) {
        final key = html.window.localStorage.keys.elementAt(i);
        final val = html.window.localStorage[key];
        if (val != null && _looksLikeJwt(val)) {
          debugPrint(
            '[Rewards] token from localStorage "$key" (${val.length})',
          );
          return val;
        }
      }
    } catch (_) {}

    debugPrint('[Rewards] No token found.');
    return null;
  }

  // -------------------- empid helpers --------------------

  Future<String?> _getEmpId() async {
    // 1) Prefer CompanyData (set during login)
    try {
      final p = CompanyData.employeeProfile;
      if (p != null) {
        if (p is Map &&
            p['empid'] != null &&
            p['empid'].toString().isNotEmpty) {
          final v = p['empid'].toString();
          debugPrint(
            '[Rewards] empid from CompanyData.employeeProfile Map: $v',
          );
          return v;
        }
        try {
          final v = (p as dynamic).empid?.toString();
          if (v != null && v.isNotEmpty) {
            debugPrint(
              '[Rewards] empid from CompanyData.employeeProfile model: $v',
            );
            return v;
          }
        } catch (_) {}
      }
      // Some apps also stash it on CompanyData directly
      final direct = (CompanyData as dynamic)?.empid?.toString();
      if (direct != null && direct.isNotEmpty) {
        debugPrint('[Rewards] empid from CompanyData.empid: $direct');
        return direct;
      }
    } catch (_) {}

    // 2) localStorage common keys
    const keys = ['empid', 'employeeId', 'employee_id', 'empId'];
    for (final k in keys) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) {
        debugPrint('[Rewards] empid from localStorage["$k"]: $v');
        return v;
      }
    }

    // 3) localStorage["me"] (many apps store the auth/me response)
    final meRaw = html.window.localStorage['me'];
    if (meRaw != null && meRaw.isNotEmpty) {
      try {
        final me = jsonDecode(meRaw);
        if (me is Map) {
          if (me['empid'] != null && me['empid'].toString().isNotEmpty) {
            final v = me['empid'].toString();
            debugPrint('[Rewards] empid from localStorage["me"].empid: $v');
            return v;
          }
          final ep = me['employeeProfile'];
          if (ep is Map &&
              ep['empid'] != null &&
              ep['empid'].toString().isNotEmpty) {
            final v = ep['empid'].toString();
            debugPrint(
              '[Rewards] empid from localStorage["me"].employeeProfile.empid: $v',
            );
            return v;
          }
        }
      } catch (_) {}
    }

    // 4) Fallback: call /auth/me with JWT
    final token = await _getJwt();
    if (token != null && token.isNotEmpty) {
      try {
        final uri = Uri.parse('$apiBase/auth/me');
        final resp = await http.get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
        debugPrint('[Rewards] GET /auth/me status=${resp.statusCode}');
        if (resp.statusCode == 200 && resp.body.isNotEmpty) {
          final me = jsonDecode(resp.body);
          if (me is Map) {
            // cache it for future
            html.window.localStorage['me'] = jsonEncode(me);

            if (me['empid'] != null && me['empid'].toString().isNotEmpty) {
              final v = me['empid'].toString();
              debugPrint('[Rewards] empid from /auth/me.empid: $v');
              return v;
            }
            final ep = me['employeeProfile'];
            if (ep is Map &&
                ep['empid'] != null &&
                ep['empid'].toString().isNotEmpty) {
              final v = ep['empid'].toString();
              debugPrint(
                '[Rewards] empid from /auth/me.employeeProfile.empid: $v',
              );
              return v;
            }
          }
        }
      } catch (e) {
        debugPrint('[Rewards] /auth/me error: $e');
      }
    }

    debugPrint('[Rewards] No empid found.');
    return null;
  }

  // -------------------- API: rewards list --------------------

  Future<List<Map<String, dynamic>>> _fetchRewards() async {
    final empId = await _getEmpId();
    if (empId == null || empId.isEmpty) {
      debugPrint('[Rewards] Missing empid -> returning []');
      return [];
    }

    final uri = Uri.parse(
      '$apiBase/rewards',
    ).replace(queryParameters: {'empid': empId});
    debugPrint('[Rewards] GET $uri');

    try {
      final resp = await http.get(
        uri,
        headers: const {'Content-Type': 'application/json'},
      );
      debugPrint('[Rewards] status=${resp.statusCode}');
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        if (decoded is List) {
          final out = decoded
              .whereType<Map>()
              .map<Map<String, dynamic>>((m) => m.cast<String, dynamic>())
              .toList();
          debugPrint('[Rewards] items=${out.length}');
          return out;
        }
        debugPrint('[Rewards] Unexpected body: ${resp.body}');
        return [];
      } else {
        debugPrint('[Rewards] Failed ${resp.statusCode}: ${resp.body}');
        return [];
      }
    } catch (e) {
      debugPrint('[Rewards] Network error: $e');
      return [];
    }
  }

  // -------------------- UI (unchanged) --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Rewards"),
        backgroundColor: const Color(0xFF8C6EAF),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD1C4E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _rewardsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final rewards = snapshot.data ?? const [];
            if (rewards.isEmpty) {
              return const Center(child: Text('No rewards found.'));
            }

            return ListView.builder(
              itemCount: rewards.length,
              itemBuilder: (context, index) {
                final r = rewards[index];
                final name = (r['name'] ?? '').toString();
                final emp = (r['empid'] ?? '').toString();
                final dept = (r['department'] ?? '').toString();
                final desc = (r['description'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "👩‍💼 Name: $name",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "🆔 Employee ID: $emp",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "🏢 Department: $dept",
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "📝 Description: $desc",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
