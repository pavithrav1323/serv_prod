// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';
// // Web localStorage (ignored on mobile/desktop)
// import 'package:serv_app/html_stub.dart'
//     if (dart.library.html) 'package:serv_app/html_web.dart' as html;

// import 'package:serv_app/Pagesadmin/add_group_name_dialog.dart';

// // App-wide theme colors
// const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF); // White
// const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9); // Light purple
// const Color kAppBarColor = Color(0xFF8C6EAF);
// const Color kButtonColor = Color(0xFF655193);
// const Color kTextColor = Colors.white;

// // ==== API ====
// const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

// class CreateShiftPage extends StatefulWidget {
//   const CreateShiftPage({super.key});

//   @override
//   State<CreateShiftPage> createState() => _CreateShiftPageState();
// }

// class _CreateShiftPageState extends State<CreateShiftPage> {
//   final TextEditingController _shiftNameController = TextEditingController();
//   final TextEditingController _groupNameController = TextEditingController();

//   TimeOfDay? _startTime;
//   TimeOfDay? _endTime;

//   bool _extraTimeManagement = false;
//   String? _breakConfig;

//   bool _saving = false;

//   Future<void> _pickTime(bool isStart) async {
//     final picked = await showTimePicker(
//       context: context,
//       initialTime: TimeOfDay.now(),
//     );
//     if (picked != null) {
//       setState(() {
//         if (isStart) {
//           _startTime = picked;
//         } else {
//           _endTime = picked;
//         }
//       });
//     }
//   }

//   String _toHHmm(TimeOfDay t) {
//     final h = t.hour.toString().padLeft(2, '0');
//     final m = t.minute.toString().padLeft(2, '0');
//     return '$h:$m';
//   }

//   Future<String?> _getToken() async {
//     try {
//       final t = html.window.localStorage['token'];
//       if (t != null && t.isNotEmpty) return t;
//     } catch (_) {}
//     final sp = await SharedPreferences.getInstance();
//     final t2 = sp.getString('token');
//     return (t2 != null && t2.isNotEmpty) ? t2 : null;
//   }

//   Future<void> _submitForm() async {
//     if (_shiftNameController.text.trim().isEmpty ||
//         _groupNameController.text.trim().isEmpty ||
//         _startTime == null ||
//         _endTime == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Please fill all required fields")),
//       );
//       return;
//     }

//     setState(() => _saving = true);

//     try {
//       final token = await _getToken();
//       final headers = <String, String>{'Content-Type': 'application/json'};
//       if (token != null) headers['Authorization'] = 'Bearer $token';

//       final body = {
//         "name": _shiftNameController.text.trim(),
//         "startTime": _toHHmm(_startTime!),
//         "endTime": _toHHmm(_endTime!),
//         "shiftname": _groupNameController.text.trim(),
//       };

//       final res = await http.post(
//         Uri.parse('$_apiBase/shifts'),
//         headers: headers,
//         body: jsonEncode(body),
//       );

//       if (!mounted) return;

//       if (res.statusCode == 201) {
//         final created = jsonDecode(res.body) as Map<String, dynamic>;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text("Shift created successfully"),
//               backgroundColor: kButtonColor),
//         );
//         Navigator.pop(context, created);
//       } else if (res.statusCode == 403) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text("Forbidden: admin only"),
//               backgroundColor: Colors.red),
//         );
//       } else if (res.statusCode == 401) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text("Unauthorized: missing/invalid token"),
//               backgroundColor: Colors.red),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content: Text("Failed (${res.statusCode}): ${res.body}"),
//               backgroundColor: Colors.red),
//         );
//       }
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text("Network error: $e"), backgroundColor: Colors.red),
//       );
//     } finally {
//       if (mounted) setState(() => _saving = false);
//     }
//   }

//   void _openGroupNameDialog() async {
//     final selectedGroupName = await showDialog<String>(
//       context: context,
//       builder: (context) => const AddGroupNameDialog(),
//     );

//     if (selectedGroupName != null) {
//       setState(() {
//         _groupNameController.text = selectedGroupName;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       resizeToAvoidBottomInset: false, // keep your setting
//       appBar: AppBar(
//         backgroundColor: kAppBarColor,
//         title: const Text("Create Shift"),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: MediaQuery.removePadding(
//         context: context,
//         removeBottom: true, // strip extra bottom inset
//         child: SafeArea(
//           child: GestureDetector(
//             onTap: () => FocusScope.of(context).unfocus(),
//             child: Container(
//               constraints: const BoxConstraints.expand(), // fill viewport
//               decoration: const BoxDecoration(
//                 gradient: LinearGradient(
//                   begin: Alignment.topCenter,
//                   end: Alignment.bottomCenter,
//                   colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
//                 ),
//               ),
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(16),
//                 physics: const ClampingScrollPhysics(),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const SizedBox(height: 6),
//                     TextField(
//                       controller: _shiftNameController,
//                       decoration: const InputDecoration(
//                         labelText: "Shift Name",
//                         hintText: "Shift Name",
//                         border: OutlineInputBorder(),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text("Start Time",
//                                   style: TextStyle(fontWeight: FontWeight.bold)),
//                               const SizedBox(height: 6),
//                               ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                     backgroundColor: kButtonColor),
//                                 onPressed:
//                                     _saving ? null : () => _pickTime(true),
//                                 child: Text(
//                                   _startTime == null
//                                       ? "Start Time"
//                                       : _startTime!.format(context),
//                                   style: const TextStyle(color: kTextColor),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text("End Time",
//                                   style: TextStyle(fontWeight: FontWeight.bold)),
//                               const SizedBox(height: 6),
//                               ElevatedButton(
//                                 style: ElevatedButton.styleFrom(
//                                     backgroundColor: kButtonColor),
//                                 onPressed:
//                                     _saving ? null : () => _pickTime(false),
//                                 child: Text(
//                                   _endTime == null
//                                       ? "End Time"
//                                       : _endTime!.format(context),
//                                   style: const TextStyle(color: kTextColor),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 16),
//                     GestureDetector(
//                       onTap: _saving ? null : _openGroupNameDialog,
//                       child: AbsorbPointer(
//                         child: TextField(
//                           controller: _groupNameController,
//                           decoration: const InputDecoration(
//                             labelText: "Group Name",
//                             hintText: "Shift Group Name",
//                             border: OutlineInputBorder(),
//                             suffixIcon: Icon(Icons.arrow_drop_down),
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     CheckboxListTile(
//                       contentPadding: EdgeInsets.zero,
//                       title: const Text("Extra Time Management",
//                           style: TextStyle(fontWeight: FontWeight.bold)),
//                       value: _extraTimeManagement,
//                       onChanged: _saving
//                           ? null
//                           : (value) {
//                               setState(() {
//                                 _extraTimeManagement = value ?? false;
//                               });
//                             },
//                     ),
//                     const SizedBox(height: 10),
//                     const Text("Break Configuration",
//                         style: TextStyle(fontWeight: FontWeight.bold)),
//                     const SizedBox(height: 6),
//                     Wrap(
//                       crossAxisAlignment: WrapCrossAlignment.center,
//                       spacing: 10,
//                       runSpacing: 8,
//                       children: [
//                         Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Radio<String>(
//                               value: "Define",
//                               groupValue: _breakConfig,
//                               onChanged: _saving
//                                   ? null
//                                   : (value) =>
//                                       setState(() => _breakConfig = value),
//                             ),
//                             const Text("Define Break"),
//                           ],
//                         ),
//                         Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Radio<String>(
//                               value: "Flexible",
//                               groupValue: _breakConfig,
//                               onChanged: _saving
//                                   ? null
//                                   : (value) =>
//                                       setState(() => _breakConfig = value),
//                             ),
//                             const Text("Flexible Break"),
//                           ],
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 24),
//                     Center(
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: kButtonColor,
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 32, vertical: 12),
//                         ),
//                         onPressed: _saving ? null : _submitForm,
//                         child: _saving
//                             ? const SizedBox(
//                                 height: 18,
//                                 width: 18,
//                                 child: CircularProgressIndicator(
//                                     strokeWidth: 2, color: Colors.white))
//                             : const Text("Submit",
//                                 style: TextStyle(color: kTextColor)),
//                       ),
//                     ),
//                     // No extra bottom spacer here
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// Web localStorage (ignored on mobile/desktop)
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

import 'package:serv_app/Pagesadmin/add_group_name_dialog.dart';

// App-wide theme colors
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF); // White
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9); // Light purple
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// ==== API ====
const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class CreateShiftPage extends StatefulWidget {
  const CreateShiftPage({super.key});

  @override
  State<CreateShiftPage> createState() => _CreateShiftPageState();
}

class _CreateShiftPageState extends State<CreateShiftPage> {
  final TextEditingController _shiftNameController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // bool _extraTimeManagement = false; // commented out
  // String? _breakConfig;              // commented out

  bool _saving = false;

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  String _toHHmm(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<String?> _getToken() async {
    try {
      final t = html.window.localStorage['token'];
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {}
    final sp = await SharedPreferences.getInstance();
    final t2 = sp.getString('token');
    return (t2 != null && t2.isNotEmpty) ? t2 : null;
  }

  Future<void> _submitForm() async {
    if (_shiftNameController.text.trim().isEmpty ||
        _groupNameController.text.trim().isEmpty ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final token = await _getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final body = {
        "name": _shiftNameController.text.trim(),
        "startTime": _toHHmm(_startTime!),
        "endTime": _toHHmm(_endTime!),
        "shiftname": _groupNameController.text.trim(),
      };

      final res = await http.post(
        Uri.parse('$_apiBase/shifts'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (res.statusCode == 201) {
        final created = jsonDecode(res.body) as Map<String, dynamic>;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Shift created successfully"),
              backgroundColor: kButtonColor),
        );
        Navigator.pop(context, created);
      } else if (res.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Forbidden: admin only"),
              backgroundColor: Colors.red),
        );
      } else if (res.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Unauthorized: missing/invalid token"),
              backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Failed (${res.statusCode}): ${res.body}"),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Network error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openGroupNameDialog() async {
    final selectedGroupName = await showDialog<String>(
      context: context,
      builder: (context) => const AddGroupNameDialog(),
    );

    if (selectedGroupName != null) {
      setState(() {
        _groupNameController.text = selectedGroupName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        title: const Text("Create Shift"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Container(
              constraints: const BoxConstraints.expand(),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    TextField(
                      controller: _shiftNameController,
                      decoration: const InputDecoration(
                        labelText: "Shift Name",
                        hintText: "Shift Name",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Start & End Time row remains unchanged
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Start Time",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: kButtonColor),
                                onPressed:
                                    _saving ? null : () => _pickTime(true),
                                child: Text(
                                  _startTime == null
                                      ? "Start Time"
                                      : _startTime!.format(context),
                                  style: const TextStyle(color: kTextColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("End Time",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: kButtonColor),
                                onPressed:
                                    _saving ? null : () => _pickTime(false),
                                child: Text(
                                  _endTime == null
                                      ? "End Time"
                                      : _endTime!.format(context),
                                  style: const TextStyle(color: kTextColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    GestureDetector(
                      onTap: _saving ? null : _openGroupNameDialog,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _groupNameController,
                          decoration: const InputDecoration(
                            labelText: "Group Name",
                            hintText: "Shift Group Name",
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // --- Commented Out ---
                    // CheckboxListTile(
                    //   contentPadding: EdgeInsets.zero,
                    //   title: const Text("Extra Time Management",
                    //       style: TextStyle(fontWeight: FontWeight.bold)),
                    //   value: _extraTimeManagement,
                    //   onChanged: _saving
                    //       ? null
                    //       : (value) {
                    //           setState(() {
                    //             _extraTimeManagement = value ?? false;
                    //           });
                    //         },
                    // ),
                    // const SizedBox(height: 10),
                    // const Text("Break Configuration",
                    //     style: TextStyle(fontWeight: FontWeight.bold)),
                    // const SizedBox(height: 6),
                    // Wrap(
                    //   crossAxisAlignment: WrapCrossAlignment.center,
                    //   spacing: 10,
                    //   runSpacing: 8,
                    //   children: [
                    //     Row(
                    //       mainAxisSize: MainAxisSize.min,
                    //       children: [
                    //         Radio<String>(
                    //           value: "Define",
                    //           groupValue: _breakConfig,
                    //           onChanged: _saving
                    //               ? null
                    //               : (value) =>
                    //                   setState(() => _breakConfig = value),
                    //         ),
                    //         const Text("Define Break"),
                    //       ],
                    //     ),
                    //     Row(
                    //       mainAxisSize: MainAxisSize.min,
                    //       children: [
                    //         Radio<String>(
                    //           value: "Flexible",
                    //           groupValue: _breakConfig,
                    //           onChanged: _saving
                    //               ? null
                    //               : (value) =>
                    //                   setState(() => _breakConfig = value),
                    //         ),
                    //         const Text("Flexible Break"),
                    //       ],
                    //     ),
                    //   ],
                    // ),
                    // --- End Commented Out ---

                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kButtonColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 12),
                        ),
                        onPressed: _saving ? null : _submitForm,
                        child: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text("Submit",
                                style: TextStyle(color: kTextColor)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
