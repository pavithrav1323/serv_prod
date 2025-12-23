import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html; // Web: localStorage/sessionStorage
import 'package:serv_app/Pagesadmin/globals_page.dart';

// ✅ Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8c6eaf);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// ✅ Backend base (already ends with /api)
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

// ---------- helpers ----------
Future<String?> _getToken() async {
  if (kIsWeb) {
    final t1 = html.window.localStorage['token'];
    if (t1 != null && t1.trim().isNotEmpty) return t1;
    final t2 = html.window.sessionStorage['token'];
    if (t2 != null && t2.trim().isNotEmpty) return t2;
    return null;
  } else {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('token');
    return (t != null && t.trim().isNotEmpty) ? t : null;
  }
}

Map<String, String> _headers(String? token, {bool includeJson = true}) {
  final h = <String, String>{};
  if (includeJson) h['Content-Type'] = 'application/json';
  if (token != null && token.isNotEmpty) {
    h['Authorization'] = 'Bearer $token';
  }
  return h;
}

DateTime? _parseAnyDate(dynamic v) {
  try {
    if (v == null) return null;
    if (v is Map && v.containsKey('_seconds')) {
      final sec = v['_seconds'];
      if (sec is num) {
        return DateTime.fromMillisecondsSinceEpoch((sec * 1000).round(), isUtc: true)
            .toLocal();
      }
    }
    if (v is String && v.trim().isNotEmpty) {
      return DateTime.parse(v).toLocal();
    }
  } catch (_) {}
  return null;
}

String _fmtDDMMYYYY(DateTime? d) =>
    d == null ? '' : DateFormat('dd-MM-yyyy').format(d);

// ===================================================================

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final fromDateController = TextEditingController();
  final toDateController = TextEditingController();
  final deptController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool showWeekOffForm = false;

  bool _loading = false;

  DateTime? fromDate;
  DateTime? toDate;

  @override
  void initState() {
    super.initState();
    _fetchLeaveTypes(); // load from backend
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    fromDateController.dispose();
    toDateController.dispose();
    deptController.dispose();
    super.dispose();
  }

  /// 🔁 Fetch from backend's leave_types endpoint and map fields exactly
  /// to what the list UI uses: 'type', 'shift', 'fromDate', 'toDate', 'allowedDays'
  Future<void> _fetchLeaveTypes() async {
    if (!mounted) return;

    setState(() => _loading = true);

    try {
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Authentication required. Please login again.'),
            ),
          );
        }
        return;
      }

      final res = await http
          .get(Uri.parse('$apiBase/leave-types'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final dynamic body = jsonDecode(res.body);
        final List<Map<String, String>> fresh = [];

        if (body is List) {
          for (final item in body) {
            if (item is Map<String, dynamic>) {
              final String type = (item['type'] ?? '').toString();
              final String shift =
                  (item['shift'] ?? item['dept'] ?? '').toString();

              final DateTime? fromDt =
                  _parseAnyDate(item['fromDate'] ?? item['from']);
              final DateTime? toDt =
                  _parseAnyDate(item['toDate'] ?? item['to']);

              int? allowedDays;
              final dynamic ad = item['allowedDays'] ?? item['days'];
              if (ad is num) {
                allowedDays = ad.toInt();
              } else if (ad is String) {
                allowedDays = int.tryParse(ad);
              }
              if (allowedDays == null && fromDt != null && toDt != null) {
                allowedDays = toDt.difference(fromDt).inDays + 1;
              }

              fresh.add({
                'type': type,
                'shift': shift,
                'fromDate': _fmtDDMMYYYY(fromDt),
                'toDate': _fmtDDMMYYYY(toDt),
                'allowedDays': (allowedDays ?? 0).toString(),
                'id': (item['id'] ?? '').toString(),
              });
            }
          }
        }

        leaveList
          ..clear()
          ..addAll(fresh);
        if (mounted) setState(() {});
      } else if (res.statusCode == 204) {
        // No content
        leaveList.clear();
        if (mounted) setState(() {});
      } else if (res.statusCode == 401) {
        // Clear invalid token (web only)
        if (kIsWeb) {
          try {
            html.window.localStorage['token'] = '';
            html.window.sessionStorage['token'] = '';
          } catch (_) {}
        }
        if (!mounted) return;
        final errorBody = res.body.isNotEmpty ? jsonDecode(res.body) : null;
        final errorMessage = errorBody?['message'] ?? 'Authentication failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Authentication required: $errorMessage'),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        if (!mounted) return;
        String errorMessage = 'Failed to load leave types: ${res.statusCode}';
        if (res.body.isNotEmpty) {
          try {
            final errorBody = jsonDecode(res.body);
            errorMessage = errorBody['message'] ?? errorMessage;
          } catch (_) {
            errorMessage = '${res.statusCode}: ${res.body}';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text('Request timed out. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: Colors.red,
              content: Text('Error fetching leave types: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate(TextEditingController controller,
      {DateTime? minDate, bool isFrom = false}) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initialDate = DateFormat('dd-MM-yyyy').parse(controller.text);
      } catch (_) {}
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate ?? DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;

    setState(() {
      controller.text = DateFormat('dd-MM-yyyy').format(picked);
      if (isFrom) {
        fromDate = picked;
        if (toDate != null && toDate!.isBefore(fromDate!)) {
          toDate = null;
          toDateController.clear();
        }
      } else {
        toDate = picked;
      }
    });
  }

  // Show confirmation dialog before deleting
  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: const Text(
                'Are you sure you want to delete this leave type? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false; // Return false if dismissed with back button
  }

  // Delete a leave entry from both UI and backend
  Future<void> _deleteLeaveItem(int index) async {
    if (index < 0 || index >= leaveList.length) return;

    final shouldDelete = await _showDeleteConfirmation();
    if (!shouldDelete) return;

    final leaveToDelete = leaveList[index];
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      setState(() => _loading = true);

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get token
      final token = await _getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop(); // hide dialog
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get the document ID from the leave item or find it by querying
      String? docId = leaveToDelete['id'];

      if (docId!.isEmpty) {
        final queryResponse = await http.get(
          Uri.parse(
              '$apiBase/leave-types?type=${Uri.encodeComponent(leaveToDelete['type'] ?? '')}'
              '&shift=${Uri.encodeComponent(leaveToDelete['shift'] ?? '')}'
              '&fromDate=${Uri.encodeComponent(leaveToDelete['fromDate'] ?? '')}'
              '&toDate=${Uri.encodeComponent(leaveToDelete['toDate'] ?? '')}'),
          headers: _headers(token),
        );

        if (queryResponse.statusCode == 200) {
          final List<dynamic> items = jsonDecode(queryResponse.body);
          if (items.isNotEmpty) {
            docId = items.first['id']?.toString();
          }
        }

        if (docId == null || docId.isEmpty) {
          throw 'Could not find leave type to delete';
        }
      }

      // Now delete using the document ID
      final response = await http
          .delete(
            Uri.parse('$apiBase/leave-types/$docId'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));

      // Hide loading dialog
      if (mounted) Navigator.of(context).pop();

      final Map<String, dynamic>? responseData =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => leaveList.removeAt(index));
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(responseData?['message'] ??
                  'Leave type deleted successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(10),
          ),
        );
      } else {
        throw responseData?['error'] ??
            responseData?['message'] ??
            'Failed to delete leave type';
      }
    } on TimeoutException {
      if (mounted) {
        Navigator.of(context).pop(); // Hide loading dialog
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Request timed out. Please try again.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(10),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Hide loading dialog
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
                'Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _addWeekOff() {
    if (!_formKey.currentState!.validate()) return;

    if (fromDate == null || toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please select both From Date and To Date"),
            backgroundColor: Colors.red),
      );
      return;
    }
    if (toDate!.isBefore(fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("To Date cannot be before From Date"),
            backgroundColor: Colors.red),
      );
      return;
    }

    final days = toDate!.difference(fromDate!).inDays + 1;

    setState(() {
      leaveList.add({
        'type': "${nameController.text} (Week Off)",
        'shift': deptController.text,
        'fromDate': fromDateController.text,
        'toDate': toDateController.text,
        'allowedDays': days.toString(),
      });

      showWeekOffForm = false;
      nameController.clear();
      locationController.clear();
      fromDateController.clear();
      toDateController.clear();
      deptController.clear();
      fromDate = null;
      toDate = null;
    });
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leave & Holiday"),
        backgroundColor: kAppBarColor,
      ),
      // Ensure the gradient shows everywhere (no plain scaffold color bleed)
      backgroundColor: Colors.transparent,

      body: Container(
        // Make the gradient container fill the viewport
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        // Use LayoutBuilder to get viewport height to eliminate bottom gap
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RefreshIndicator(
              onRefresh: _fetchLeaveTypes,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Force content to be at least as tall as the viewport
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Week Off Form Toggle Button — REMOVED AS REQUESTED
                              // (No other UI changes)

                              // Week Off Form
                              if (showWeekOffForm) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.purpleAccent.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        const Text(
                                          "Add Week Off",
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField("Name", nameController),
                                        const SizedBox(height: 12),
                                        _buildTextField("Location", locationController),
                                        const SizedBox(height: 12),
                                        _buildDateField("From Date", fromDateController, isFrom: true),
                                        const SizedBox(height: 12),
                                        _buildDateField("To Date", toDateController, minDate: fromDate),
                                        const SizedBox(height: 12),
                                        _buildTextField("Department", deptController),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  showWeekOffForm = false;
                                                  _formKey.currentState?.reset();
                                                });
                                              },
                                              child: const Text("CANCEL"),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton(
                                              onPressed: _addWeekOff,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: kButtonColor,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text("SUBMIT"),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Leave List Header
                              const Text(
                                "Leave",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Leave List
                              leaveList.isEmpty
                                  ? Container(
                                      height: MediaQuery.of(context).size.height * 0.4,
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "No leave data available",
                                        style: TextStyle(
                                          color: Colors.black54,
                                          fontSize: 16,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: leaveList.length,
                                      itemBuilder: (context, index) {
                                        final leave = leaveList[index];
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 15),
                                          padding: const EdgeInsets.all(15),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(15),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.purpleAccent.withOpacity(0.2),
                                                spreadRadius: 2,
                                                blurRadius: 5,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                            border: Border.all(color: Colors.deepPurple.shade100),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      leave['type'] ?? '',
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.deepPurple,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: _loading
                                                        ? const SizedBox(
                                                            width: 20,
                                                            height: 20,
                                                            child: CircularProgressIndicator(
                                                                strokeWidth: 2),
                                                          )
                                                        : const Icon(
                                                            Icons.delete_outline,
                                                            color: Colors.red,
                                                          ),
                                                    onPressed: _loading
                                                        ? null
                                                        : () => _deleteLeaveItem(index),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 5),
                                              Text("Shift: ${leave['shift']}",
                                                  style: const TextStyle(color: Colors.black87)),
                                              const SizedBox(height: 5),
                                              Text(
                                                  "From: ${leave['fromDate']}   To: ${leave['toDate']}",
                                                  style: const TextStyle(color: Colors.black54)),
                                              const SizedBox(height: 5),
                                              Text("No of Days: ${leave['allowedDays']}",
                                                  style: const TextStyle(
                                                      color: Colors.redAccent,
                                                      fontWeight: FontWeight.w500)),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                              // The Column naturally expands due to ConstrainedBox minHeight,
                              // ensuring the gradient fills the remainder.
                            ],
                          ),
                        ),
                      ),
                    ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kButtonColor,
        onPressed: () async {
          final updated = await Navigator.pushNamed(context, '/add-leave');
          if (updated == true && mounted) {
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text("Add Leave"),
      ),
    );
  }

  // Text Field
  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        decoration: _buildInputDecoration(label),
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  // Date Field with optional minDate
  Widget _buildDateField(String label, TextEditingController controller,
      {DateTime? minDate, bool isFrom = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () => _selectDate(controller, minDate: minDate, isFrom: isFrom),
        decoration: _buildInputDecoration(label)
            .copyWith(suffixIcon: const Icon(Icons.calendar_today)),
        validator: (val) => val == null || val.isEmpty ? 'Select a date' : null,
      ),
    );
  }
}
