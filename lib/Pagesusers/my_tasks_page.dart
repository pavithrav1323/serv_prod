// lib/Pagesusers/my_tasks_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:serv_app/models/company_data.dart';

const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// Dialog theme
const Color kLavenderBg = Color(0xFFF3E8FF);
const Color kRoyalPurple = Color(0xFF6B4EA2);

/* ---------- SIMPLE TASK MODEL (no files) ---------- */
class _TaskItem {
  final String id;
  final String title;
  final String description;
  final String audience;     // "all" | "employee"
  final String? assignedTo;  // empid when audience='employee'
  final String? dueDate;     // ISO or yyyy-MM-dd
  final String? createdAt;   // ISO string
  final String? createdBy;   // uid/userId
  final String? kind;        // "Task" | "DailyUpdate" | etc.

  _TaskItem({
    required this.id,
    required this.title,
    required this.description,
    required this.audience,
    this.assignedTo,
    this.dueDate,
    this.createdAt,
    this.createdBy,
    this.kind,
  });

  factory _TaskItem.fromJson(Map<String, dynamic> j) => _TaskItem(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? 'Task').toString(),
        description: (j['description'] ?? '').toString(),
        audience: (j['audience'] ?? 'all').toString(),
        assignedTo: j['assignedTo']?.toString(),
        dueDate: j['dueDate']?.toString(),
        createdAt: j['createdAt']?.toString(),
        createdBy: j['createdBy']?.toString(),
        kind: j['kind']?.toString(),
      );
}

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});
  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  bool _loading = false;
  String? _error;
  List<_TaskItem> _tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    // merged view (broadcast + personal)
    final uri = Uri.parse('$_apiBase/tasks/user');

    try {
      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if ((CompanyData.token ?? '').isNotEmpty)
            'Authorization': 'Bearer ${CompanyData.token}',
        },
      );

      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        final out = list
            .map((e) => _TaskItem.fromJson(e as Map<String, dynamic>))
            .toList();

        out.sort((a, b) {
          final ad = DateTime.tryParse(a.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = DateTime.tryParse(b.createdAt ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });

        setState(() => _tasks = out);
      } else {
        setState(() => _error = 'Error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      setState(() => _error = 'Failed to fetch tasks: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- helpers for dialog ----------

  String _formatISTDateTime(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '-';
    DateTime parsed;
    try {
      parsed = DateTime.parse(iso);
    } catch (_) {
      return iso;
    }
    final ist = parsed.toUtc().add(const Duration(hours: 5, minutes: 30));
    String two(int n) => n.toString().padLeft(2, '0');
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final hour12 = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final ampm = ist.hour >= 12 ? 'PM' : 'AM';
    return '${two(ist.day)} ${months[ist.month - 1]} ${ist.year}, '
           '${two(hour12)}:${two(ist.minute)} $ampm';
  }

  // Label bold, value normal, consistent left alignment
  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5A4B81),
                letterSpacing: 0.2,
              )),
          const SizedBox(height: 6),
          Text(
            value.isEmpty ? '-' : value,
            textAlign: TextAlign.left,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Upload (DailyUpdate) flow ----

  Future<void> _postDailyUpdate(String description) async {
    // server derives empid from JWT; no client empid needed
    final uri = Uri.parse('$_apiBase/tasks/daily-update');
    final body = jsonEncode({
      'title': 'Daily Update',
      'description': description,
      'dueDate': null,
    });

    try {
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if ((CompanyData.token ?? '').isNotEmpty)
            'Authorization': 'Bearer ${CompanyData.token}',
        },
        body: body,
      );

      if (!mounted) return;

      if (resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Daily update posted')),
        );
        await _fetchTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post failed (${resp.statusCode}): ${resp.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post error: $e')),
      );
    }
  }

  Future<void> _showUploadBox() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: kLavenderBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kRoyalPurple, width: 1.2),
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Daily Update',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kRoyalPurple,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF5A4B81),
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200, minHeight: 120),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Type your update...',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: kRoyalPurple)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRoyalPurple,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a description')),
                        );
                        return;
                      }
                      Navigator.pop(context); // close input dialog
                      await _postDailyUpdate(text);
                    },
                    child: const Text('Post'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTaskDetails(_TaskItem t) {
    // Only show Upload for admin tasks; hide for DailyUpdate items.
    final canUpload = (t.kind ?? '').toLowerCase() != 'dailyupdate';

    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kLavenderBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kRoyalPurple, width: 1.4),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 14, offset: Offset(0, 6)),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, minHeight: 220),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Task Details',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: kRoyalPurple,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (canUpload)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kRoyalPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          icon: const Icon(Icons.upload),
                          label: const Text('Upload'),
                          onPressed: _showUploadBox,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: Color(0x226B4EA2)),
                  const SizedBox(height: 8),

                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _kvRow('Title', t.title),
                          _kvRow('Description', t.description.isNotEmpty ? t.description : '-'),
                          if ((t.dueDate ?? '').isNotEmpty) _kvRow('Due Date', t.dueDate!),
                          _kvRow('Created By', 'Admin'),
                          _kvRow('Created At', _formatISTDateTime(t.createdAt)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: kRoyalPurple,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks'), backgroundColor: kAppBarColor),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _tasks.isEmpty
                    ? const Center(child: Text('No tasks available'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (_, i) {
                          final t = _tasks[i];
                          return ListTile(
                            leading: Icon(
                              t.audience == 'all'
                                  ? Icons.campaign
                                  : Icons.assignment_ind,
                              color: Colors.deepPurple,
                            ),
                            title: Text(
                              t.title.isNotEmpty ? t.title : 'Task',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (t.description.isNotEmpty)
                                  Text(
                                    t.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if ((t.createdAt ?? '').trim().isNotEmpty)
                                  Text(_formatISTDateTime(t.createdAt)),
                              ],
                            ),
                            onTap: () => _openTaskDetails(t),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            tileColor: Colors.white,
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemCount: _tasks.length,
                      ),
      ),
    );
  }
}
