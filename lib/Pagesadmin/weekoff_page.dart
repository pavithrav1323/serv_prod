import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:serv_app/Pagesadmin/globals_page.dart';

class WeekOffPage extends StatefulWidget {
  const WeekOffPage({super.key});

  @override
  State<WeekOffPage> createState() => _WeekOffPageState();
}

class _WeekOffPageState extends State<WeekOffPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController fromDateController = TextEditingController();
  final TextEditingController toDateController = TextEditingController();
  final TextEditingController deptController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  DateTime? selectedFromDate; // store selected from date

  Future<void> _selectDate(TextEditingController controller, {bool isFrom = false}) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = isFrom ? DateTime(2020) : (selectedFromDate ?? DateTime(2020));
    DateTime lastDate = DateTime(2030);

    DateTime? picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
    );

    controller.text = DateFormat('dd-MM-yyyy').format(picked!);
    if (isFrom) {
      selectedFromDate = picked;
      // Clear toDate if it is earlier than new fromDate
      DateTime? currentToDate = toDateController.text.isNotEmpty
          ? DateFormat('dd-MM-yyyy').parse(toDateController.text)
          : null;
      if (picked.isAfter(currentToDate!)) {
        toDateController.clear();
      }
    }
    }

  void _addWeekOff() {
    if (_formKey.currentState!.validate()) {
      String name = nameController.text;
      String from = fromDateController.text;
      String to = toDateController.text;
      String location = locationController.text;
      String dept = deptController.text;

      DateTime fromDt = DateFormat('dd-MM-yyyy').parse(from);
      DateTime toDt = DateFormat('dd-MM-yyyy').parse(to);
      int days = toDt.difference(fromDt).inDays + 1;

      leaveList.add({
        'type': "$name (Week Off)",
        'dept': dept,
        'location': location,
        'from': from,
        'to': to,
        'days': days.toString(),
      });

      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      filled: true,
      fillColor: Colors.purpleAccent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Week Off"),
        backgroundColor: Colors.purpleAccent[200],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: inputDecoration.copyWith(hintText: '🔍 Search'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                      onPressed: () {}, child: const Text("Customize Column")),
                  const SizedBox(width: 10),
                  ElevatedButton(
                      onPressed: () {}, child: const Text("Filter")),
                ],
              ),
              const SizedBox(height: 20),
              _buildField("Name", nameController, inputDecoration),
              _buildField("Location", locationController, inputDecoration),
              _buildDateField("From Date", fromDateController, inputDecoration, isFrom: true),
              _buildDateField("To Date", toDateController, inputDecoration, isFrom: false),
              _buildField("Department", deptController, inputDecoration),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _addWeekOff,
                  child: const Text("Add Week Off"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, InputDecoration deco) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            decoration: deco,
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, InputDecoration deco, {required bool isFrom}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            readOnly: true,
            onTap: () => _selectDate(controller, isFrom: isFrom),
            decoration: deco.copyWith(
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            validator: (val) => val == null || val.isEmpty ? 'Select a date' : null,
          ),
        ],
      ),
    );
  }
}