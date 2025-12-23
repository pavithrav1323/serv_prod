import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/* ===========================
   CONFIG
   =========================== */
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api'; // adjust if needed
const String kDefaultTypeName = 'General'; // hidden default type

// Theme
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

/* ===========================
   MODELS (minimal)
   =========================== */
class ReasonType {
  final String id;
  final String name;
  ReasonType({required this.id, required this.name});
  factory ReasonType.fromJson(Map<String, dynamic> j) =>
      ReasonType(id: '${j["id"] ?? j["_id"] ?? ""}', name: '${j["name"] ?? ""}');
}

class ReasonItem {
  final String id;
  final String reason;
  final DateTime? createdAt;
  final String status;

  ReasonItem({
    required this.id,
    required this.reason,
    required this.createdAt,
    required this.status,
  });

  factory ReasonItem.fromJson(Map<String, dynamic> j) {
    DateTime? ts;
    final c = j['createdAt'];
    if (c is String) ts = DateTime.tryParse(c);
    if (c is Map && c['_seconds'] != null) {
      ts = DateTime.fromMillisecondsSinceEpoch((c['_seconds'] as int) * 1000);
    }
    return ReasonItem(
      id: '${j["id"] ?? j["_id"] ?? ""}',
      reason: '${j["reason"] ?? ""}',
      createdAt: ts,
      status: '${j["status"] ?? (j["deleted"] == true ? "Deleted" : "Active")}',
    );
  }
}

/* ===========================
   PAGE
   =========================== */
class ReasonMasterPage extends StatefulWidget {
  const ReasonMasterPage({super.key});
  @override
  State<ReasonMasterPage> createState() => _ReasonMasterPageState();
}

class _ReasonMasterPageState extends State<ReasonMasterPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _reasonInputController = TextEditingController();

  List<ReasonItem> _all = [];
  List<ReasonItem> _filtered = [];

  bool _loading = true;
  bool _booting = true; // while we ensure default type
  String? _defaultTypeId; // hidden typeId used for POST

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Ensure we have a default "General" typeId to use when creating reasons
    await _ensureDefaultType();
    // Then load reasons
    await _loadReasons();
    setState(() => _booting = false);
  }

  /* ===========================
     TYPES (hidden default)
     =========================== */
  Future<void> _ensureDefaultType() async {
    try {
      // 1) List types
      final r = await http.get(Uri.parse('$apiBase/reasons/types'));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        final types = data.map((e) => ReasonType.fromJson(e)).toList().cast<ReasonType>();
        final existing = types.firstWhere(
          (t) => t.name.trim().toLowerCase() == kDefaultTypeName.toLowerCase(),
          orElse: () => ReasonType(id: '', name: ''),
        );
        if (existing.id.isNotEmpty) {
          _defaultTypeId = existing.id;
          return;
        }
      }

      // 2) If not found, create it
      final c = await http.post(
        Uri.parse('$apiBase/reasons/types'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': kDefaultTypeName}),
      );

      if (c.statusCode == 200 || c.statusCode == 201) {
        final m = jsonDecode(c.body) as Map<String, dynamic>;
        _defaultTypeId = '${m["id"] ?? m["_id"] ?? ""}';
      } else {
        // If creation failed, we still have a usable UI, but POSTs will fail.
        _toast('Could not ensure default type (${c.statusCode})');
      }
    } catch (e) {
      _toast('Default type setup failed: $e');
    }
  }

  /* ===========================
     REASONS
     =========================== */
  Future<void> _loadReasons() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(Uri.parse('$apiBase/reasons'));
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body);
        final List items = (body is List) ? body : (body['items'] as List? ?? []);
        _all = items.map((e) => ReasonItem.fromJson(e)).toList();
      } else {
        _toast('Failed to load reasons (${r.statusCode})');
      }
    } catch (e) {
      _toast('Failed to load reasons: $e');
    } finally {
      _applyFilter();
      setState(() => _loading = false);
    }
  }

  Future<void> _createReason(String reason) async {
    if (_defaultTypeId == null || _defaultTypeId!.isEmpty) {
      _toast('No default type available; cannot create reason.');
      return;
    }
    try {
      final r = await http.post(
        Uri.parse('$apiBase/reasons'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'typeId': _defaultTypeId, // <-- hidden typeId
          'reason': reason,
        }),
      );
      if (r.statusCode == 200 || r.statusCode == 201) {
        _toast('Reason created');

        // Insert immediately if backend returned the created item
        try {
          final m = jsonDecode(r.body);
          if (m is Map<String, dynamic>) {
            final created = ReasonItem.fromJson(m);
            if (created.id.isNotEmpty) {
              setState(() {
                _all.insert(0, created);
                _applyFilter();
              });
              return;
            }
          }
        } catch (_) {}
        // Otherwise just refresh
        await _loadReasons();
      } else {
        // Show server error (400 “Field `typeId` is required”, etc.)
        String serverMsg = '';
        try {
          serverMsg = (jsonDecode(r.body)['message'] ?? '').toString();
        } catch (_) {}
        _toast('Create failed (${r.statusCode}) ${serverMsg.isNotEmpty ? "- $serverMsg" : ""}');
      }
    } catch (e) {
      _toast('Create failed: $e');
    }
  }

  Future<void> _deleteReason(String id) async {
    try {
      final r = await http.delete(Uri.parse('$apiBase/reasons/$id'));
      if (r.statusCode == 200) {
        setState(() {
          _all.removeWhere((x) => x.id == id);
          _applyFilter();
        });
        _toast('Deleted');
      } else {
        _toast('Delete failed (${r.statusCode})');
      }
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  /* ===========================
     UI helpers
     =========================== */
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _all.where((r) {
        final d = _formatDate(r.createdAt);
        return r.reason.toLowerCase().contains(q) ||
            d.toLowerCase().contains(q) ||
            r.status.toLowerCase().contains(q);
      }).toList();
    });
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}-'
           '${d.month.toString().padLeft(2, '0')}-'
           '${d.year}';
  }

  /* ===========================
     DIALOGS
     =========================== */
  Future<void> _openAddReasonDialog() async {
    _reasonInputController.clear();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add New Reason', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _reasonInputController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter Reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = _reasonInputController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context);
              await _createReason(text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(ReasonItem r) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete this reason?\n\n${r.reason}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReason(r.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /* ===========================
     BUILD
     =========================== */
  @override
  Widget build(BuildContext context) {
    final booting = _booting;
    final loading = _loading;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        title: const Text('Reason Master', style: TextStyle(fontSize: 16, color: kTextColor)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadReasons,
            icon: const Icon(Icons.refresh, color: kTextColor),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Search + Create
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: booting ? null : _openAddReasonDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kButtonColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  child: const Text('Create', style: TextStyle(color: kTextColor)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Header (no Type column)
            Container(
              color: const Color(0xFF655193),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                  Expanded(child: Text('Date',   style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                  Expanded(child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                  Expanded(child: Center(child: Text('Delete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)))),
                ],
              ),
            ),

            // List
            Expanded(
              child: booting || loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('No results found', style: TextStyle(fontSize: 16, color: Colors.black)),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadReasons,
                          child: ListView.builder(
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final r = _filtered[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 3, child: Text(r.reason, style: const TextStyle(fontSize: 13))),
                                    Expanded(child: Text(_formatDate(r.createdAt), style: const TextStyle(fontSize: 13))),
                                    Expanded(child: Text(r.status, style: const TextStyle(fontSize: 13))),
                                    Expanded(
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18),
                                          onPressed: () => _confirmDelete(r),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _reasonInputController.dispose();
    super.dispose();
  }
}
