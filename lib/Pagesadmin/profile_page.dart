import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// Web-only storage shims (safe on non-web due to conditional import)
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

import 'package:serv_app/models/company_data.dart'; // shared model with static fields

// ===== Theme colors (unchanged) =====
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// Neutral overlays for glass effect
const Color _glassFill = Color(0x26FFFFFF);      // white @ ~15%
const Color _glassBorder = Color(0x33FFFFFF);    // white @ ~20%
const Color _labelColor = Color(0xFF2F2A3B);

// ===== Backend base (same as the rest of the app) =====
const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class CompanyProfilePage extends StatefulWidget {
  const CompanyProfilePage({super.key});

  @override
  State<CompanyProfilePage> createState() => _CompanyProfilePageState();
}

class _CompanyProfilePageState extends State<CompanyProfilePage> {
  bool _isEditing = false;
  bool _loading = false;
  bool _saving = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _adminNameCtrl;
  late final TextEditingController _adminRoleCtrl;

  final ImagePicker _picker = ImagePicker();
  XFile? _logoFile; // persisted via CompanyData too
  Uint8List? _logoBytes; // for avatar preview

  @override
  void initState() {
    super.initState();

    // Seed from CompanyData so the UI has something immediately.
    _logoFile = CompanyData.logoFile;
    _nameCtrl = TextEditingController(text: CompanyData.companyName);
    _emailCtrl = TextEditingController(text: CompanyData.email);
    _phoneCtrl = TextEditingController(text: CompanyData.phone);
    _websiteCtrl = TextEditingController(text: CompanyData.website);
    _adminNameCtrl = TextEditingController(text: CompanyData.adminName);
    _adminRoleCtrl = TextEditingController(text: CompanyData.adminRole);

    _loadInitialLogoBytes();

    // Fetch from API (uses token's email as doc id on the server)
    _fetchProfile();
  }

  // ----- STORAGE / TOKEN HELPERS -----
  String? _readToken() {
    final t = (CompanyData.token).toString();
    if (t.isNotEmpty && t != 'null') return t;

    if (kIsWeb) {
      final t1 = html.window.localStorage['token'];
      if (t1 != null && t1.trim().isNotEmpty) return t1;
      final t2 = html.window.sessionStorage['token'];
      if (t2 != null && t2.trim().isNotEmpty) return t2;
    }
    return null;
  }

  Map<String, String> _authHeaders({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    final tok = _readToken();
    if (tok != null && tok.isNotEmpty) h['Authorization'] = 'Bearer $tok';
    return h;
  }

  // ----- LOGO PREVIEW -----
  Future<void> _loadInitialLogoBytes() async {
    try {
      if (_logoFile != null) {
        final bytes = await _logoFile!.readAsBytes();
        if (mounted) setState(() => _logoBytes = bytes);
      }
    } catch (_) {
      // ignore preview errors
    }
  }

  // ----- API: FETCH PROFILE -----
  Future<void> _fetchProfile() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/company/profile'),
        headers: _authHeaders(json: true),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = (body['data'] ?? {}) as Map<String, dynamic>;

        // Map server -> UI fields
        final companyName = (data['companyName'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        final phone = (data['phone'] ?? '').toString();
        final website = (data['website'] ?? '').toString();
        final adminName = (data['adminName'] ?? '').toString();
        final designation = (data['designation'] ?? '').toString();

        // Optional image: server may store logoBase64 OR logoUrl
        Uint8List? logoBytes;
        final String logoBase64 = (data['logoBase64'] ?? '').toString();
        if (logoBase64.isNotEmpty) {
          // strip any "data:image/*;base64," prefix
          final pure = logoBase64.split('base64,').last;
          try {
            logoBytes = base64Decode(pure);
          } catch (_) {}
        }

        // Update controllers and memory model
        _nameCtrl.text = companyName;
        _emailCtrl.text = email;
        _phoneCtrl.text = phone;
        _websiteCtrl.text = website;
        _adminNameCtrl.text = adminName;
        _adminRoleCtrl.text = designation;

        CompanyData.companyName = companyName;
        CompanyData.email = email;
        CompanyData.phone = phone;
        CompanyData.website = website;
        CompanyData.adminName = adminName;
        CompanyData.adminRole = designation;

        if (logoBytes != null) {
          setState(() => _logoBytes = logoBytes);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile loaded')),
          );
        }
      } else if (res.statusCode == 404) {
        // No profile yet — keep existing seed values
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No profile found.')),
          );
        }
      } else if (res.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Unauthorized. Please sign in again.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Load failed: ${res.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ----- API: SAVE PROFILE -----
  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final uri = Uri.parse('$_apiBase/company/profile');
      final req = http.MultipartRequest('POST', uri);

      // Auth header only; MultipartRequest sets its own content-type
      final tok = _readToken();
      if (tok != null && tok.isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $tok';
      }

      // Fields expected by backend
      req.fields['companyName'] = _nameCtrl.text.trim();
      req.fields['email'] = _emailCtrl.text.trim();
      req.fields['phone'] = _phoneCtrl.text.trim();
      req.fields['website'] = _websiteCtrl.text.trim();
      req.fields['adminName'] = _adminNameCtrl.text.trim();
      req.fields['designation'] = _adminRoleCtrl.text.trim();

      // Optional logo file — multer looks for 'logo'
      if (_logoFile != null) {
        final bytes = await _logoFile!.readAsBytes();
        final filename = _logoFile!.name; // works on web & mobile
        req.files.add(
          http.MultipartFile.fromBytes('logo', bytes, filename: filename),
        );
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        // Persist back to CompanyData so the rest of the app can read it
        CompanyData.logoFile = _logoFile;
        CompanyData.companyName = _nameCtrl.text.trim();
        CompanyData.email = _emailCtrl.text.trim();
        CompanyData.phone = _phoneCtrl.text.trim();
        CompanyData.website = _websiteCtrl.text.trim();
        CompanyData.adminName = _adminNameCtrl.text.trim();
        CompanyData.adminRole = _adminRoleCtrl.text.trim();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved')),
          );
        }
      } else {
        // Surface server error message if any
        String msg = 'Save failed: ${res.statusCode}';
        try {
          final b = jsonDecode(res.body);
          msg = (b['message'] ?? b['error'] ?? msg).toString();
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ----- UI actions -----
  Future<void> _pickLogo() async {
    final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _logoFile = picked;
        _logoBytes = bytes;
      });
    }
  }

  void _toggleEdit() async {
    if (_isEditing) {
      await _saveProfile();
    }
    if (mounted) setState(() => _isEditing = !_isEditing);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminRoleCtrl.dispose();
    super.dispose();
  }

  // ----- BUILD -----
  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width > 820;
    final double spacing = isWide ? 28.0 : 16.0;
    final double maxW = isWide ? 820 : double.infinity;

    final ImageProvider<Object>? avatar =
        (_logoBytes != null) ? MemoryImage(_logoBytes!) : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        title: const Text('Company Profile', style: TextStyle(color: kTextColor)),
        iconTheme: const IconThemeData(color: kTextColor),
        actions: [
          IconButton(
            icon: (_isEditing
                ? (_saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: kTextColor,
                        ),
                      )
                    : const Icon(Icons.check, color: kTextColor))
                : const Icon(Icons.edit, color: kTextColor)),
            onPressed: _saving ? null : _toggleEdit,
            tooltip: _isEditing ? 'Save' : 'Edit',
          ),
        ],
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(spacing),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: SizedBox(
                      width: maxW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Header / Identity ───────────────────────────────
                          _GlassPanel(
                            child: Column(
                              children: [
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    CircleAvatar(
                                      radius: 46,
                                      backgroundImage: avatar,
                                      backgroundColor: Colors.white.withOpacity(0.7),
                                      child: avatar == null
                                          ? const Icon(Icons.apartment,
                                              size: 36, color: Colors.grey)
                                          : null,
                                    ),
                                    if (_isEditing)
                                      InkWell(
                                        onTap: _pickLogo,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: kButtonColor,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white, width: 1),
                                          ),
                                          padding: const EdgeInsets.all(6),
                                          child: const Icon(Icons.camera_alt,
                                              size: 16, color: kTextColor),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _nameCtrl.text.isEmpty ? 'Company Name' : _nameCtrl.text,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _labelColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _adminNameCtrl.text.isEmpty
                                      ? 'Admin'
                                      : '${_adminNameCtrl.text} · ${_adminRoleCtrl.text.isEmpty ? '—' : _adminRoleCtrl.text}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── Content Sections ────────────────────────────────
                          if (_loading)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ))
                          else
                            (_isEditing
                                ? _EditLayout(
                                    spacing: spacing,
                                    nameCtrl: _nameCtrl,
                                    emailCtrl: _emailCtrl,
                                    phoneCtrl: _phoneCtrl,
                                    websiteCtrl: _websiteCtrl,
                                    adminNameCtrl: _adminNameCtrl,
                                    adminRoleCtrl: _adminRoleCtrl,
                                  )
                                : _ViewLayout(
                                    spacing: spacing,
                                    isWide: isWide,
                                    name: _nameCtrl.text,
                                    email: _emailCtrl.text,
                                    phone: _phoneCtrl.text,
                                    website: _websiteCtrl.text,
                                    adminName: _adminNameCtrl.text,
                                    adminRole: _adminRoleCtrl.text,
                                  )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ======= View Mode Layout (professional, never looks empty) =======
class _ViewLayout extends StatelessWidget {
  final double spacing;
  final bool isWide;
  final String name, email, phone, website, adminName, adminRole;

  const _ViewLayout({
    required this.spacing,
    required this.isWide,
    required this.name,
    required this.email,
    required this.phone,
    required this.website,
    required this.adminName,
    required this.adminRole,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(title: 'Organization'),
        _GlassPanel(
          child: _InfoList(items: [
            _InfoRow(icon: Icons.badge, label: 'Company Name', value: _orDash(name)),
            _InfoRow(icon: Icons.alternate_email, label: 'Official Email', value: _orDash(email)),
            _InfoRow(icon: Icons.phone, label: 'Phone Number', value: _orDash(phone)),
            _InfoRow(icon: Icons.public, label: 'Website', value: _orDash(website)),
          ]),
        ),
        SizedBox(height: spacing),

        _SectionHeader(title: 'Administrator'),
        _GlassPanel(
          child: _InfoList(items: [
            _InfoRow(icon: Icons.person, label: 'Admin Full Name', value: _orDash(adminName)),
            _InfoRow(icon: Icons.workspace_premium, label: 'Admin Designation', value: _orDash(adminRole)),
          ]),
        ),
        SizedBox(height: spacing),
      ],
    );
  }

  String _orDash(String v) => v.trim().isEmpty ? '—' : v.trim();
}

// ======= Edit Mode Layout (clean + guided) =======
class _EditLayout extends StatelessWidget {
  final double spacing;
  final TextEditingController nameCtrl,
      emailCtrl,
      phoneCtrl,
      websiteCtrl,
      adminNameCtrl,
      adminRoleCtrl;

  const _EditLayout({
    required this.spacing,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.websiteCtrl,
    required this.adminNameCtrl,
    required this.adminRoleCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(title: 'Organization Details', subtitle: 'Update your company information.'),
        _GlassPanel(
          child: Column(
            children: [
              _EditField(label: 'Company Name', controller: nameCtrl, icon: Icons.badge),
              SizedBox(height: spacing),
              _EditField(label: 'Official Email', controller: emailCtrl, icon: Icons.alternate_email, keyboard: TextInputType.emailAddress),
              SizedBox(height: spacing),
              _EditField(label: 'Phone Number', controller: phoneCtrl, icon: Icons.phone, keyboard: TextInputType.phone),
              SizedBox(height: spacing),
              _EditField(label: 'Website', controller: websiteCtrl, icon: Icons.public, keyboard: TextInputType.url),
            ],
          ),
        ),
        SizedBox(height: spacing),

        _SectionHeader(title: 'Administrator', subtitle: 'Primary admin who manages this workspace.'),
        _GlassPanel(
          child: Column(
            children: [
              _EditField(label: 'Admin Full Name', controller: adminNameCtrl, icon: Icons.person),
              SizedBox(height: spacing),
              _EditField(label: 'Admin Designation', controller: adminRoleCtrl, icon: Icons.workspace_premium),
            ],
          ),
        ),
        SizedBox(height: spacing),
      ],
    );
  }
}

// ======= Reusable Visuals =======
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _labelColor,
              )),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _glassFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _glassBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class _InfoList extends StatelessWidget {
  final List<_InfoRow> items;
  const _InfoList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          items[i],
          if (i != items.length - 1)
            Divider(
              height: 16,
              thickness: 1,
              color: Colors.white.withOpacity(0.35),
            ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: kAppBarColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withOpacity(0.6),
                  )),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _labelColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboard;
  final IconData icon;

  const _EditField({
    required this.label,
    required this.controller,
    this.keyboard = TextInputType.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: kAppBarColor),
        filled: true,
        fillColor: Colors.white.withOpacity(0.85),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: kAppBarColor.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: kAppBarColor, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: const TextStyle(fontSize: 15),
    );
  }
}
