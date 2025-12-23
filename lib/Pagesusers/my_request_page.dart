import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

class MyRequestPage extends StatefulWidget {
  const MyRequestPage({super.key});

  @override
  State<MyRequestPage> createState() => _MyRequestPageState();
}

class _MyRequestPageState extends State<MyRequestPage> {
  DateTime selectedDate = DateTime.now();

  // Status filter
  String selectedStatus = 'All'; // default shows all statuses for that day
  final List<String> statusOptions = const ['All', 'Pending', 'Approved', 'Rejected'];

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // single day window: start = end = selectedDate
      final day = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

      final data = await ApiService.fetchMyRequests(
        from: day,
        to: day,
        status: selectedStatus, // "All" → API will omit status param
      );

      if (!mounted) return;
      setState(() => _items = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load: $e');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
      await _load(); // reload for the newly picked day
    }
  }

  String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final fromText = _fmtDate(selectedDate);

    return Scaffold(
      // ✅ Use a real AppBar so it matches the global theme everywhere
      appBar: AppBar(
        title: const Text('My Request'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false, // AppBar already handles the top inset
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + Status filters
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: _selectDate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor.withOpacity(0.9),
                        foregroundColor: kTextColor,
                        elevation: 0,
                      ),
                      child: Text(fromText),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedStatus,
                        items: statusOptions
                            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => selectedStatus = v);
                          await _load(); // reload for this status on the same day
                        },
                        underline: const SizedBox(),
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Text("Total (${_items.length})", style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),

                // Body
                if (_loading)
                  const Expanded(child: Center(child: CircularProgressIndicator()))
                else if (_error != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  )
                else if (_items.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.insert_drive_file_outlined, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("NO data Available", style: TextStyle(fontSize: 16, color: Colors.black54)),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _RequestCard(item: _items[i]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _RequestCard({required this.item});

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange; // Pending/others
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] ?? '').toString();
    final date = (item['requestDate'] ?? '').toString();
    final time = (item['requestTime'] ?? '').toString();
    final status = (item['status'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    type,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _statusColor(status)),
                  ),
                  child: Text(status),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Date: $date'),
            if (time.isNotEmpty) Text('Time: $time'),
            if ((item['reason'] ?? '').toString().isNotEmpty) Text('Reason: ${item['reason']}'),
          ],
        ),
      ),
    );
  }
}
