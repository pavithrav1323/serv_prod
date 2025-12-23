// import 'package:flutter/material.dart';

// class AddGroupNameDialog extends StatefulWidget {
//   const AddGroupNameDialog({super.key});

//   @override
//   State<AddGroupNameDialog> createState() => _AddGroupNameDialogState();
// }

// class _AddGroupNameDialogState extends State<AddGroupNameDialog> {
//   final TextEditingController _groupNameController = TextEditingController();
//   final List<String> _groupList = [
//     "PY Shift 2",
//     "GDC Shift 1",
//     "General Shift 2",
//     "Shift",
//     "General Shift",
//   ];

//   void _deleteGroup(int index) {
//     setState(() {
//       _groupList.removeAt(index);
//     });
//   }

//   void _editGroup(int index) {
//     _groupNameController.text = _groupList[index];
//     _deleteGroup(index);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       child: ConstrainedBox(
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.85,
//         ),
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     "Add Group Name",
//                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.close),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 10),
//               const Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text(
//                   "Group Name ",
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ),
//               const SizedBox(height: 6),
//               TextField(
//                 controller: _groupNameController,
//                 decoration: const InputDecoration(
//                   hintText: "Group name",
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 14),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.grey.shade300,
//                     ),
//                     onPressed: () => Navigator.pop(context),
//                     child: const Text(
//                       "Cancel",
//                       style: TextStyle(color: Colors.black),
//                     ),
//                   ),
//                   ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.teal,
//                     ),
//                     onPressed: () {
//                       final selected = _groupNameController.text.trim();
//                       if (selected.isNotEmpty) {
//                         Navigator.pop(context, selected);
//                       }
//                     },
//                     child: const Text("ADD"),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 20),
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade200,
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: const Text(
//                   "Group Name",
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Column(
//                 children: List.generate(_groupList.length, (index) {
//                   final name = _groupList[index];
//                   return ListTile(
//                     dense: true,
//                     title: Text(name),
//                     leading: const Icon(Icons.edit, size: 18),
//                     trailing: IconButton(
//                       icon: const Icon(Icons.delete, size: 18),
//                       onPressed: () => _deleteGroup(index),
//                     ),
//                     onTap: () => _editGroup(index),
//                   );
//                 }),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';

// App-wide theme colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

class AddGroupNameDialog extends StatefulWidget {
  const AddGroupNameDialog({super.key});

  @override
  State<AddGroupNameDialog> createState() => _AddGroupNameDialogState();
}

class _AddGroupNameDialogState extends State<AddGroupNameDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<String> _groupList = [
    "PY Shift 2",
    "GDC Shift 1",
    "General Shift 2",
    "Shift",
    "General Shift",
  ];

  void _deleteGroup(int index) {
    setState(() {
      _groupList.removeAt(index);
    });
  }

  void _editGroup(int index) {
    _groupNameController.text = _groupList[index];
    _deleteGroup(index);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Add Group Name",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Group Name Label with red asterisk

              const SizedBox(height: 6),

              // Floating label input with app theme
              TextField(
                controller: _groupNameController,
                decoration: const InputDecoration(
                  labelText: "Group Name",
                 
                  hintText: "Group name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Cancel",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kButtonColor,
                    ),
                    onPressed: () {
                      final selected = _groupNameController.text.trim();
                      if (selected.isNotEmpty) {
                        Navigator.pop(context, selected);
                      }
                    },
                    child: const Text(
                      "ADD",
                      style: TextStyle(color: kTextColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section Header with app theme color
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kAppBarColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  "Group Name",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),

              // Group List
              Column(
                children: List.generate(_groupList.length, (index) {
                  final name = _groupList[index];
                  return ListTile(
                    dense: true,
                    title: Text(name),
                    leading: const Icon(Icons.edit, size: 18),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, size: 18),
                      onPressed: () => _deleteGroup(index),
                    ),
                    onTap: () => _editGroup(index),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}