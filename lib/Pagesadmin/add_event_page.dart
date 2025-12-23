import 'dart:convert';
import 'dart:math'; // for UUID generator
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ⬇️ Adjust base URL if needed
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

class EventUploadPage extends StatefulWidget {
  const EventUploadPage({super.key});
  @override
  State<EventUploadPage> createState() => _EventUploadPageState();
}

class _EventUploadPageState extends State<EventUploadPage> {
  final nameCtrl = TextEditingController();
  final fromDateCtrl = TextEditingController();
  final toDateCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  @override
  void dispose() {
    nameCtrl.dispose();
    fromDateCtrl.dispose();
    toDateCtrl.dispose();
    locationCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController c) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (d != null) c.text = DateFormat('yyyy-MM-dd').format(d);
  }

  // Minimal, dependency-free UUID v4
  String _uuidV4() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant
    String h(int b) => b.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(h).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Future<void> _submit() async {
    // Required fields (image/file are NOT required)
    if (nameCtrl.text.trim().isEmpty ||
        fromDateCtrl.text.trim().isEmpty ||
        toDateCtrl.text.trim().isEmpty ||
        locationCtrl.text.trim().isEmpty ||
        descCtrl.text.trim().isEmpty) {
      _toast('Please fill all required fields.');
      return;
    }

    // Date sanity check
    try {
      final from = DateFormat('yyyy-MM-dd').parse(fromDateCtrl.text.trim());
      final to = DateFormat('yyyy-MM-dd').parse(toDateCtrl.text.trim());
      if (from.isAfter(to)) {
        _toast('From Date cannot be after To Date.');
        return;
      }
    } catch (_) {
      _toast('Dates must be in yyyy-MM-dd format.');
      return;
    }

    try {
      final payload = {
        "id": _uuidV4(),
        "title": nameCtrl.text.trim(),
        "description": descCtrl.text.trim(),
        "location": locationCtrl.text.trim(),
        "fromDate": fromDateCtrl.text.trim(),
        "toDate": toDateCtrl.text.trim(),
      };

      final resp = await http.post(
        Uri.parse('$apiBase/events'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 201) {
        _toast('Event created.');
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        _toast('Create failed (${resp.statusCode}): ${resp.body}');
      }
    } catch (e) {
      _toast('Create error: $e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Event Details'),
        backgroundColor: kAppBarColor,
        foregroundColor: kTextColor,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tf(nameCtrl, label: 'Event Name *'),
              const SizedBox(height: 10),
              _tf(fromDateCtrl,
                  label: 'From Date *',
                  readOnly: true,
                  onTap: () => _pickDate(fromDateCtrl)),
              const SizedBox(height: 10),
              _tf(toDateCtrl,
                  label: 'To Date *',
                  readOnly: true,
                  onTap: () => _pickDate(toDateCtrl)),
              const SizedBox(height: 10),
              _tf(locationCtrl, label: 'Location *'),
              const SizedBox(height: 10),
              _tf(descCtrl, label: 'Description *', maxLines: 3),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kButtonColor,
                      foregroundColor: Colors.white),
                  child: const Text('Submit',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tf(
    TextEditingController c, {
    required String label,
    bool readOnly = false,
    int maxLines = 1,
    VoidCallback? onTap,
  }) {
    final hasStar = label.contains('*');
    final plain = label.replaceAll('*', '').trim();
    return TextFormField(
      controller: c,
      readOnly: readOnly,
      maxLines: maxLines,
      onTap: onTap,
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: plain,
                style: const TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              if (hasStar)
                const TextSpan(
                  text: ' *',
                  style:
                      TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _LabelWithStar extends StatelessWidget {
  final String text;
  const _LabelWithStar(this.text);
  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: text,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
}
