import 'package:flutter/material.dart';

// Theme Colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

class ShiftPermissionPage extends StatefulWidget {
  const ShiftPermissionPage({super.key});

  @override
  State<ShiftPermissionPage> createState() => _ShiftPermissionPageState();
}

class _ShiftPermissionPageState extends State<ShiftPermissionPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _hourController = TextEditingController();

  String? _selectedEligibility;
  final List<Map<String, String>> _permissionsList = [];

  void _addPermission() {
    final name = _nameController.text.trim();
    final hours = _hourController.text.trim();
    final eligibility = _selectedEligibility;

    if (name.isNotEmpty && hours.isNotEmpty && eligibility != null) {
      setState(() {
        _permissionsList.add({
          'name': name,
          'hours': hours,
          'eligibility': eligibility,
        });
        _nameController.clear();
        _hourController.clear();
        _selectedEligibility = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundTop,
      appBar: AppBar(
        title: const Text("Shift Permissions"),
        backgroundColor: kAppBarColor,
        foregroundColor: kTextColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true, // <-- remove extra bottom system padding
        child: Container(
          // <-- ensure the gradient fills the entire viewport height
          constraints: const BoxConstraints.expand(),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Add Shift Permission",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmallScreen = constraints.maxWidth < 400;
                    return isSmallScreen
                        ? Column(children: _buildFormFields())
                        : Row(
                            children: _buildFormFields()
                                .map((widget) => Expanded(child: widget))
                                .toList(),
                          );
                  },
                ),
                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _addPermission,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Permission"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kButtonColor,
                      foregroundColor: kTextColor,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                const Text(
                  "Permissions List",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(),

                Row(
                  children: const [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "Permission Name",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "No of Hours",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "Eligibility",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(thickness: 1),

                _permissionsList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Center(child: Text("No permissions added.")),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _permissionsList.length,
                        itemBuilder: (context, index) {
                          final permission = _permissionsList[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(permission['name'] ?? ""),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(permission['hours'] ?? ""),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(permission['eligibility'] ?? ""),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                // No extra Spacer/SizedBox below—keeps bottom tight
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    return [
      TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: "Permission Name",
          hintText: "Enter Name",
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),

      GestureDetector(
        onTap: () async {
          final TimeOfDay? pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.now(),
          );
          if (pickedTime != null) {
            final String formattedTime = pickedTime.format(context);
            setState(() {
              _hourController.text = formattedTime;
            });
          }
        },
        child: AbsorbPointer(
          child: TextField(
            controller: _hourController,
            decoration: const InputDecoration(
              labelText: "No of Hours",
              hintText: "HH:MM",
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.access_time),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),

      DropdownButtonFormField<String>(
        initialValue: _selectedEligibility,
        decoration: const InputDecoration(
          labelText: "Eligibility",
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: "Weekly", child: Text("Weekly")),
          DropdownMenuItem(value: "Monthly", child: Text("Monthly")),
        ],
        onChanged: (value) {
          setState(() {
            _selectedEligibility = value!;
          });
        },
      ),
    ];
  }
}
