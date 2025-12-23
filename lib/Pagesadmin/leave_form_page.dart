import 'dart:convert';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart'
    as html; // token from localStorage on web
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// You keep a local list in globals_page.dart; we leave it untouched
import 'package:serv_app/Pagesadmin/globals_page.dart';

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class LeaveFormPage extends StatefulWidget {
  const LeaveFormPage({super.key});

  @override
  State<LeaveFormPage> createState() => _LeaveFormPageState();
}

class _LeaveFormPageState extends State<LeaveFormPage> {
  final _formKey = GlobalKey<FormState>();

  final typeCtrl = TextEditingController();
  final fromCtrl = TextEditingController();
  final toCtrl = TextEditingController();
  final daysCtrl = TextEditingController();

  DateTime? fromDate;
  DateTime? toDate;

  String? _getToken() {
    final keys = ['jwt', 'token', 'access_token', 'auth_token'];
    for (final k in keys) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  Future<void> _selectDate(TextEditingController ctrl,
      {DateTime? minDate, bool isFrom = false}) async {
    DateTime initialDate = DateTime.now();
    if (ctrl.text.isNotEmpty) {
      initialDate = DateFormat('dd-MM-yyyy').parse(ctrl.text);
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate ?? DateTime(2022),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        ctrl.text = DateFormat('dd-MM-yyyy').format(picked);
        if (isFrom) {
          fromDate = picked;
          if (toDate != null && toDate!.isBefore(fromDate!)) {
            toDate = null;
            toCtrl.clear();
          }
        } else {
          toDate = picked;
        }
      });
    }
  }

  Future<void> _saveLeave() async {
    if (!_formKey.currentState!.validate()) return;

    if (fromDate != null && toDate != null && toDate!.isBefore(fromDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('To Date cannot be before From Date'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final token = _getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Not logged in'), backgroundColor: Colors.red),
      );
      return;
    }

    final body = {
      'type': typeCtrl.text.trim(),
      // backend expects ISO-like dates; use yyyy-MM-dd
      'fromDate': DateFormat('yyyy-MM-dd').format(fromDate!),
      'toDate': DateFormat('yyyy-MM-dd').format(toDate!),
      'days': int.tryParse(daysCtrl.text.trim()) ?? 1,
    };

    try {
      final resp = await http.post(
        Uri.parse('$apiBase/leave-types'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (resp.statusCode == 201) {
        // Keep your existing local list if you still use it anywhere
        leaveList.add({
          'type': typeCtrl.text,
          'from': fromCtrl.text,
          'to': toCtrl.text,
          'days': daysCtrl.text,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave type saved')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${resp.statusCode} ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Add Leave Type'), backgroundColor: kAppBarColor),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _buildField('Type', typeCtrl),
                _buildDateField('From Date', fromCtrl, isFrom: true),
                _buildDateField('To Date', toCtrl, minDate: fromDate),
                _buildField('Number of Days', daysCtrl, TextInputType.number),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kButtonColor,
                        side: const BorderSide(color: kButtonColor),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saveLeave,
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      [TextInputType? inputType]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: inputType,
        style: const TextStyle(color: kAppBarColor),
        decoration: _getDecor(label),
        validator: (value) =>
            value == null || value.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController ctrl,
      {DateTime? minDate, bool isFrom = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        readOnly: true,
        style: const TextStyle(color: kAppBarColor),
        decoration: _getDecor(label).copyWith(
          suffixIcon: IconButton(
            icon: const Icon(Icons.calendar_today, color: kAppBarColor),
            onPressed: () =>
                _selectDate(ctrl, minDate: minDate, isFrom: isFrom),
          ),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Select date' : null,
      ),
    );
  }

  InputDecoration _getDecor(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: kAppBarColor),
      filled: true,
      fillColor: Colors.white,
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: kAppBarColor, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: kAppBarColor, width: 1),
        borderRadius: BorderRadius.circular(6),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    );
  }
}
