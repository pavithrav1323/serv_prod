import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Auth token you already use elsewhere (e.g., LiveAttendancePage)
import 'package:serv_app/models/company_data.dart';

class MyTasksPage extends StatefulWidget {
  const MyTasksPage({super.key});

  @override
  State<MyTasksPage> createState() => _MyTasksPageState();
}

class _MyTasksPageState extends State<MyTasksPage> {
  // API base
  static const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

  // Daily updates (from API)
  List<Map<String, dynamic>> dailyUpdates = [];
  bool isLoadingUpdates = false;

  // My assigned tasks (audience='employee')
  List<Map<String, dynamic>> myAssigned = [];
  bool isLoadingAssigned = false;

  // Simple "broadcast task" form (TEXT ONLY now)
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _empIdCtrl = TextEditingController(); // NEW: for one-employee assignment
  DateTime? _dueDate; // optional

  // NEW: dropdown state -> 'all' or 'employee'
  String _audience = 'all';

  @override
  void initState() {
    super.initState();
    fetchDailyUpdates();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _empIdCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Fetch daily updates (unchanged logic, still reads from /api/tasks?audience=all)
  Future<void> fetchDailyUpdates() async {
    setState(() => isLoadingUpdates = true);
    try {
      final uri = Uri.parse('$_apiBase/tasks?audience=all');
      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = CompanyData.token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        final daily = list.where((e) {
          final kind = (e['kind'] ?? '').toString();
          return kind.toLowerCase() == 'dailyupdate';
        }).toList();

        daily.sort((a, b) {
          final ad = DateTime.tryParse((a['createdAt'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = DateTime.tryParse((b['createdAt'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });

        final mapped = daily.map<Map<String, dynamic>>((e) {
          final title = (e['title'] ?? 'Daily update').toString();
          final createdAt = (e['createdAt'] ?? '').toString();
          final date =
              createdAt.contains('T') ? createdAt.split('T').first : createdAt;

          return {
            "date": date,
            "update": title,
            "updatedBy": (e['createdBy'] ?? e['assignedTo'] ?? '').toString(),
          };
        }).toList();

        setState(() {
          dailyUpdates = mapped;
          isLoadingUpdates = false;
        });
      } else {
        setState(() => isLoadingUpdates = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch updates: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => isLoadingUpdates = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch updates: $e')),
      );
    }
  }

  /// Create a task:
  /// - If _audience == 'all': broadcast to everyone
  /// - If _audience == 'employee': assign only to the given empid
  Future<void> _createBroadcastTask() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate empid only when assigning to a single employee
    if (_audience == 'employee' && _empIdCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the employee empid.')),
      );
      return;
    }

    final uri = Uri.parse('$_apiBase/tasks/broadcast');
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = CompanyData.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final body = {
      "title": _titleCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "dueDate": _dueDate == null ? null : _fmtDate(_dueDate!),
      "kind": "Task",
      // NEW: audience + (optional) assignedTo
      "audience": _audience, // 'all' or 'employee'
      if (_audience == 'employee') "assignedTo": _empIdCtrl.text.trim(),
    };

    try {
      final resp =
          await http.post(uri, headers: headers, body: jsonEncode(body));
      if (resp.statusCode == 201) {
        _titleCtrl.clear();
        _descCtrl.clear();
        _empIdCtrl.clear();
        setState(() => _dueDate = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void showDailyUpdateDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Daily Updates",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: isLoadingUpdates
              ? const Center(child: CircularProgressIndicator())
              : dailyUpdates.isEmpty
                  ? const Text("No daily updates yet.")
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: dailyUpdates.length,
                      itemBuilder: (ctx, i) {
                        final u = dailyUpdates[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text("📅 ${u['date']}"),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("📝 ${u['update']}"),
                                if ((u['updatedBy'] as String).isNotEmpty)
                                  Text("👩‍💻 ${u['updatedBy']}"),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close",
                style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }

  /// Fetch tasks assigned to this employee (audience='employee')
  Future<void> fetchMyAssignedTasks() async {
    setState(() => isLoadingAssigned = true);
    try {
      // ✅ Always call /tasks/employee; include empid if available
      final empid = (CompanyData.empid ?? '').trim();
      final uri = Uri.parse(empid.isNotEmpty
          ? '$_apiBase/tasks/employee?empid=${Uri.encodeQueryComponent(empid)}'
          : '$_apiBase/tasks/employee');

      final headers = <String, String>{'Content-Type': 'application/json'};
      final token = CompanyData.token;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final resp = await http.get(uri, headers: headers);
      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);

        // Ensure only personal tasks (server already filters, this is a safety net)
        final personal = list.where((e) {
          final audience = (e['audience'] ?? '').toString().toLowerCase();
          if (audience != 'employee') return false;
          if (empid.isEmpty) return true;
          return (e['assignedTo'] ?? '').toString().trim() == empid;
        }).toList();

        personal.sort((a, b) {
          final ad = DateTime.tryParse((a['createdAt'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd = DateTime.tryParse((b['createdAt'] ?? '').toString()) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });

        final mapped = personal.map<Map<String, dynamic>>((e) {
          final createdAt = (e['createdAt'] ?? '').toString();
          final date =
              createdAt.contains('T') ? createdAt.split('T').first : createdAt;
          return {
            "title": (e['title'] ?? 'Task').toString(),
            "description": (e['description'] ?? '').toString(),
            "dueDate": (e['dueDate'] ?? '').toString(),
            "createdAt": date,
            "kind": (e['kind'] ?? '').toString(),
          };
        }).toList();

        setState(() {
          myAssigned = mapped;
          isLoadingAssigned = false;
        });
      } else {
        setState(() => isLoadingAssigned = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to fetch assigned tasks: ${resp.statusCode}')),
        );
      }
    } catch (e) {
      setState(() => isLoadingAssigned = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch assigned tasks: $e')),
      );
    }
  }

  // Dialog to show assigned tasks
  void showAssignedTasksDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "My Assigned Tasks",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: isLoadingAssigned
              ? const Center(child: CircularProgressIndicator())
              : myAssigned.isEmpty
                  ? const Text("No assigned tasks yet.")
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: myAssigned.length,
                      itemBuilder: (ctx, i) {
                        final t = myAssigned[i];
                        final hasDue =
                            (t['dueDate'] as String).trim().isNotEmpty;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(t['title'] as String),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((t['description'] as String).isNotEmpty)
                                  Text(t['description'] as String),
                                Text("Assigned on: ${t['createdAt']}"),
                                if (hasDue) Text("Due: ${t['dueDate']}"),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close",
                style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF8E71B7),
        centerTitle: false,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Tasks",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFD1C4E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ======= Task assigned (Broadcast / One-employee) =======
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E71B7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Task assigned",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // NEW: Audience dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _audience,
                      items: const [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text('All employees'),
                        ),
                        DropdownMenuItem(
                          value: 'employee',
                          child: Text('One employee'),
                        ),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Assign to',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _audience = v;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // NEW: Show empid field only if 'One employee'
                    if (_audience == 'employee') ...[
                      TextFormField(
                        controller: _empIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Enter empid',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (_audience == 'employee' &&
                              (v == null || v.trim().isEmpty)) {
                            return 'empid is required for single employee assignment';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Description (requested single description box)
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),

                    // Optional due date + Submit
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDueDate,
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _dueDate == null
                                  ? 'Pick due date (optional)'
                                  : 'Due: ${_fmtDate(_dueDate!)}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _createBroadcastTask,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B5E94),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: const Text("Submit",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ======= Daily Update header (kept) + View button shows assigned tasks =======
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E71B7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Daily Update",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                // On click: fetch personal tasks and show them
                onPressed: () async {
                  await fetchMyAssignedTasks();
                  if (!mounted) return;
                  showAssignedTasksDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B5E94),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child:
                    const Text("View", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
