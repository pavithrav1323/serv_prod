// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:intl_phone_field/intl_phone_field.dart';
// import 'package:http/http.dart' as http;
// import 'report_scheduler_page.dart';

// // Use localStorage only when targeting Web
// // ignore: avoid_web_libraries_in_flutter
// import 'package:serv_app/html_stub.dart'
//     if (dart.library.html) 'package:serv_app/html_web.dart' as html;

// // >>> NEW: read token from the same in-memory place as other pages
// import 'package:serv_app/models/company_data.dart';

// // ===== Theme =====
// const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
// const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
// const Color kAppBarColor = Color(0xFF655193);
// const Color kButtonColor = Color(0xFF655193);
// const Color kTextColor = Colors.white;

// // ===== API base =====
// const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api'; // keep /api here

// // ===== Model =====
// class Employee {
//   final String name;
//   final String id; // <-- Employee ID (empid)
//   final String email;
//   final String mobile; // phone
//   final String location;
//   final String dept;
//   final String designation;
//   final String status; // "Active"/"Inactive" (UI)
//   final String shiftGroup;
//   final String? docId; // Firestore document id (server generated)
//   final String? password; // only used on create
//   final String role; // defaults to "employee"

//   Employee({
//     required this.name,
//     required this.id,
//     required this.email,
//     required this.mobile,
//     required this.location,
//     required this.dept,
//     required this.designation,
//     required this.status,
//     required this.shiftGroup,
//     this.docId,
//     this.password,
//     this.role = 'employee',
//   });

//   /// Build from backend JSON (GET /api/employees)
//   factory Employee.fromServer(Map<String, dynamic> j) {
//     return Employee(
//       docId: j['id'] as String?,
//       id: (j['empid'] ?? '').toString(),
//       name: (j['name'] ?? '').toString(),
//       email: (j['email'] ?? '').toString(),
//       mobile: (j['phone'] ?? '').toString(),
//       location: (j['location'] ?? '').toString(),
//       dept: (j['dept'] ?? '').toString(),
//       designation: (j['designation'] ?? '').toString(),
//       shiftGroup: (j['shiftGroup'] ?? '').toString(),
//       status: ((j['status'] ?? 'active').toString().toLowerCase() == 'active')
//           ? 'Active'
//           : 'Inactive',
//       role: (j['role'] ?? 'employee').toString(),
//     );
//   }

//   /// Body for POST /api/employees
//   Map<String, dynamic> toCreateBody() => {
//         'name': name,
//         'empid': id,
//         'email': email,
//         'phone': mobile,
//         'password': password, // backend hashes it
//         'location': location,
//         'dept': dept,
//         'designation': designation,
//         'shiftGroup': shiftGroup.isEmpty ? null : shiftGroup,
//         'role': role,
//       };
// }

// // ===== Service =====
// class EmployeeService {
//   static bool _looksLikeJwt(String v) =>
//       RegExp(r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$')
//           .hasMatch(v);

//   static String? _readToken() {
//     // --- MOST IMPORTANT: app-wide in-memory token (works on Android/iOS) ---
//     final mem = CompanyData.token;
//     if (mem != null && mem.isNotEmpty) return mem;

//     // Known keys that might be used on Web builds
//     const candidates = [
//       'token',
//       'jwt',
//       'authToken',
//       'access_token',
//       'accessToken',
//       'id_token',
//     ];

//     // localStorage (Web)
//     for (final k in candidates) {
//       final v = html.window.localStorage[k];
//       if (v != null && v.isNotEmpty) return v;
//     }

//     // sessionStorage (Web)
//     try {
//       for (final k in candidates) {
//         final v = html.window.sessionStorage[k];
//         if (v != null && v.isNotEmpty) return v;
//       }
//     } catch (_) {}

//     // Fallback: scan storages for any JWT-looking value (Web)
//     try {
//       for (final k in html.window.localStorage.keys) {
//         final v = html.window.localStorage[k];
//         if (v != null && _looksLikeJwt(v)) return v;
//       }
//     } catch (_) {}
//     try {
//       for (final k in html.window.sessionStorage.keys) {
//         final v = html.window.sessionStorage[k];
//         if (v != null && _looksLikeJwt(v)) return v;
//       }
//     } catch (_) {}

//     return null;
//   }

//   static Map<String, String> _headers() {
//     final token = _readToken();
//     final headers = <String, String>{'Content-Type': 'application/json'};
//     if (token != null && token.isNotEmpty) {
//       headers['Authorization'] = 'Bearer $token';
//       headers['x-auth-token'] = token;
//     }
//     return headers;
//   }

//   // static Future<List<Employee>> fetchEmployees() async {
//   //   final res =
//   //       await http.get(Uri.parse('$apiBase/employees'), headers: _headers());
//   //
//   //   if (res.statusCode == 200) {
//   //     final decoded = jsonDecode(res.body);
//   //     final List<dynamic> list = decoded is List
//   //         ? decoded
//   //         : (decoded is Map<String, dynamic> && decoded['data'] is List)
//   //             ? decoded['data'] as List
//   //             : <dynamic>[];
//   //     return list
//   //         .map((e) => Employee.fromServer(e as Map<String, dynamic>))
//   //         .toList();
//   //   }
//   //   if (res.statusCode == 404) return <Employee>[];
//   //   throw Exception('Failed to fetch employees (${res.statusCode}): ${res.body}');
//   // }

//   static Future<List<Employee>> fetchEmployees({int limit = 50}) async {
//     int page = 1;
//     final List<Employee> all = [];

//     while (true) {
//       final url = Uri.parse('$apiBase/employees?page=$page&limit=$limit');
//       final res = await http.get(url, headers: _headers());

//       if (res.statusCode == 200) {
//         final decoded = jsonDecode(res.body);
//         final List<dynamic> raw = decoded is List
//             ? decoded
//             : (decoded is Map<String, dynamic> && decoded['data'] is List)
//                 ? decoded['data'] as List
//                 : <dynamic>[];

//         final items = raw
//             .map((e) => Employee.fromServer(e as Map<String, dynamic>))
//             .toList();
//         all.addAll(items);

//         if (items.length < limit) break; // last page
//         page += 1;
//         continue;
//       }

//       if (res.statusCode == 404) break; // no data
//       throw Exception(
//           'Failed to fetch employees (${res.statusCode}): ${res.body}');
//     }

//     return all;
//   }

//   static Future<String> createEmployee(Employee e) async {
//     final body = jsonEncode(e.toCreateBody());
//     final res = await http.post(
//       Uri.parse('$apiBase/employees'),
//       headers: _headers(),
//       body: body,
//     );
//     if (res.statusCode == 201) {
//       final j = jsonDecode(res.body) as Map<String, dynamic>;
//       if (j['id'] != null) return j['id'].toString();
//       if (j['data'] is Map && (j['data'] as Map)['id'] != null) {
//         return (j['data'] as Map)['id'].toString();
//       }
//       return '';
//     }
//     throw Exception('Create failed (${res.statusCode}): ${res.body}');
//   }

//   static Future<void> updateEmployee(
//       String docId, Map<String, dynamic> updates) async {
//     final res = await http.put(
//       Uri.parse('$apiBase/employees/$docId'),
//       headers: _headers(),
//       body: jsonEncode(updates),
//     );
//     if (res.statusCode != 200) {
//       throw Exception('Update failed (${res.statusCode}): ${res.body}');
//     }
//   }

//   // === fetch shift groups for dropdown ===
//   static Future<List<String>> fetchShiftGroups() async {
//     final res =
//         await http.get(Uri.parse('$apiBase/shifts'), headers: _headers());
//     if (res.statusCode != 200) {
//       throw Exception('Failed to load shifts (${res.statusCode})');
//     }
//     final list = jsonDecode(res.body) as List<dynamic>;
//     final names = <String>[];
//     for (final it in list) {
//       final m = it as Map<String, dynamic>;
//       final n = (m['name'] ?? m['shiftname'] ?? '').toString().trim();
//       if (n.isNotEmpty) names.add(n);
//     }
//     return names;
//   }
// }

// // ===== Screens =====
// class EmployeeListScreen extends StatefulWidget {
//   const EmployeeListScreen({super.key});
//   @override
//   State<EmployeeListScreen> createState() => _EmployeeListScreenState();
// }

// class _EmployeeListScreenState extends State<EmployeeListScreen> {
//   List<Employee> employees = [];
//   List<Employee> filtered = [];
//   final TextEditingController searchController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();
//     _loadEmployees();
//   }

//   Future<void> _loadEmployees() async {
//     try {
//       final list = await EmployeeService.fetchEmployees();
//       setState(() {
//         employees = list;
//         filtered = list;
//       });
//     } catch (_) {
//       // optionally show a SnackBar
//     }
//   }

//   void updateFiltered(String query) {
//     setState(() {
//       final q = query.toLowerCase();
//       filtered = employees.where((e) {
//         return e.name.toLowerCase().contains(q) ||
//             e.id.toLowerCase().contains(q) ||
//             e.email.toLowerCase().contains(q);
//       }).toList();
//     });
//   }

//   int countStatus(String status) =>
//       employees.where((e) => e.status.toLowerCase() == status.toLowerCase()).length;

//   Widget statButton(String label, int count, Color color) {
//     return SizedBox(
//       width: 85,
//       height: 30,
//       child: ElevatedButton(
//         style: ElevatedButton.styleFrom(
//           backgroundColor: color,
//           foregroundColor: kTextColor,
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//           padding: EdgeInsets.zero,
//         ),
//         onPressed: () {},
//         child: Text('$label $count',
//             textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
//       ),
//     );
//   }

//   Widget _cell(String text, {required int flex}) {
//     return Expanded(
//       flex: flex,
//       child: Text(
//         text,
//         overflow: TextOverflow.ellipsis,
//         maxLines: 1,
//         style: const TextStyle(fontSize: 13),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.transparent,
//       appBar: AppBar(
//         toolbarHeight: 50,
//         backgroundColor: kAppBarColor,
//         foregroundColor: Colors.white,
//         leading: IconButton(icon: const Icon(Icons.arrow_back, size: 0), onPressed: () {}),
//         titleSpacing: 0,
//         title: const Text("Employee Management",
//             style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
//           ),
//         ),
//         child: Column(
//           children: [
//             const SizedBox(height: 10),
//             Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               alignment: WrapAlignment.center,
//               children: [
//                 statButton('Total', employees.length, kButtonColor),
//                 statButton('Active', countStatus('Active'), kButtonColor),
//                 statButton('Inactive', countStatus('Inactive'), kButtonColor),
//                 statButton('Suspended', 0, kButtonColor),
//                 statButton('Relived', 0, kButtonColor),
//               ],
//             ),
//             const SizedBox(height: 10),
//             Column(
//               children: [
//                 ElevatedButton(
//                   onPressed: () async {
//                     final result = await Navigator.push<Employee>(
//                       context,
//                       MaterialPageRoute(builder: (_) => const CreateEmployeeScreen()),
//                     );
//                     if (result != null) {
//                       try {
//                         await EmployeeService.createEmployee(result);
//                         await _loadEmployees();
//                         if (context.mounted) {
//                           ScaffoldMessenger.of(context)
//                               .showSnackBar(const SnackBar(content: Text('Employee created.')));
//                         }
//                       } catch (e) {
//                         if (context.mounted) {
//                           ScaffoldMessenger.of(context)
//                               .showSnackBar(SnackBar(content: Text('Create failed: $e')));
//                         }
//                       }
//                     }
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: kButtonColor,
//                     foregroundColor: kTextColor,
//                     minimumSize: const Size(120, 36),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                   ),
//                   child: const Text("Create Employee", style: TextStyle(fontSize: 12)),
//                 ),
//                 const SizedBox(height: 10),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (_) => ReportSchedulerPage()),
//                     );
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: kButtonColor,
//                     foregroundColor: kTextColor,
//                     minimumSize: const Size(120, 36),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//                   ),
//                   child: const Text("Create Report Scheduler", style: TextStyle(fontSize: 12)),
//                 ),
//               ],
//             ),
//             Padding(
//               padding: const EdgeInsets.all(10),
//               child: TextField(
//                 controller: searchController,
//                 onChanged: updateFiltered,
//                 decoration: InputDecoration(
//                   prefixIcon: const Icon(Icons.search),
//                   hintText: 'Search',
//                   filled: true,
//                   fillColor: Colors.white,
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                 ),
//               ),
//             ),
//             Expanded(
//               child: SingleChildScrollView(
//                 scrollDirection: Axis.horizontal,
//                 child: SizedBox(
//                   width: 1300,
//                   child: Column(
//                     children: [
//                       Container(
//                         color: Colors.grey[300],
//                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//                         child: const Row(
//                           children: [
//                             Expanded(flex: 4, child: Text("ID", style: TextStyle(fontWeight: FontWeight.bold))),
//                             Expanded(flex: 6, child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
//                             Expanded(flex: 8, child: Text("Email", style: TextStyle(fontWeight: FontWeight.bold))),
//                             Expanded(flex: 7, child: Text("Mobile", style: TextStyle(fontWeight: FontWeight.bold))),
//                             Expanded(flex: 6, child: Text("Shift Group", style: TextStyle(fontWeight: FontWeight.bold))),
//                             Expanded(flex: 6, child: Text("Location", style: TextStyle(fontWeight: FontWeight.bold))),
//                             Expanded(flex: 6, child: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
//                             Expanded(flex: 6, child: Text("Designation", style: TextStyle(fontWeight: FontWeight.bold))),
//                             Expanded(flex: 4, child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
//                             Expanded(flex: 5, child: Center(child: Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)))),
//                             Expanded(flex: 5, child: Center(child: Text("Edit", style: TextStyle(fontWeight: FontWeight.bold)))),
//                           ],
//                         ),
//                       ),
//                       Expanded(
//                         child: ListView.builder(
//                           itemCount: filtered.length,
//                           itemBuilder: (context, i) {
//                             final e = filtered[i];
//                             return Container(
//                               color: Colors.white,
//                               padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
//                               child: Row(
//                                 crossAxisAlignment: CrossAxisAlignment.center,
//                                 children: [
//                                   _cell(e.id, flex: 4),
//                                   _cell(e.name, flex: 6),
//                                   _cell(e.email, flex: 8),
//                                   _cell(e.mobile, flex: 7),
//                                   _cell(e.shiftGroup, flex: 6),
//                                   _cell(e.location, flex: 6),
//                                   _cell(e.dept, flex: 6),
//                                   _cell(e.designation, flex: 6),
//                                   _cell(e.status, flex: 4),
//                                   Expanded(
//                                     flex: 5,
//                                     child: Center(
//                                       child: IconButton(
//                                         icon: const Icon(Icons.delete, color: Colors.red),
//                                         onPressed: () {
//                                           setState(() {
//                                             employees.removeWhere((emp) => emp.docId == e.docId || emp.id == e.id);
//                                             updateFiltered(searchController.text);
//                                           });
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                   Expanded(
//                                     flex: 5,
//                                     child: Center(
//                                       child: IconButton(
//                                         icon: const Icon(Icons.edit, color: Colors.blue),
//                                         onPressed: () async {
//                                           final edited = await Navigator.push<Employee>(
//                                             context,
//                                             MaterialPageRoute(
//                                               builder: (_) => CreateEmployeeScreen(editEmployee: e),
//                                             ),
//                                           );
//                                           if (edited != null) {
//                                             if (e.docId != null) {
//                                               try {
//                                                 await EmployeeService.updateEmployee(e.docId!, {
//                                                   'name': edited.name,
//                                                   'empid': edited.id,
//                                                   'email': edited.email,
//                                                   'phone': edited.mobile,
//                                                   'location': edited.location,
//                                                   'dept': edited.dept,
//                                                   'designation': edited.designation,
//                                                   'shiftGroup': edited.shiftGroup,
//                                                   'status': edited.status.toLowerCase(),
//                                                 });
//                                                 await _loadEmployees();
//                                               } catch (err) {
//                                                 if (context.mounted) {
//                                                   ScaffoldMessenger.of(context).showSnackBar(
//                                                     SnackBar(content: Text('Update failed: $err')),
//                                                   );
//                                                 }
//                                               }
//                                             }
//                                           }
//                                         },
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           },
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class CreateEmployeeScreen extends StatefulWidget {
//   final Employee? editEmployee;
//   const CreateEmployeeScreen({super.key, this.editEmployee});

//   @override
//   State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
// }

// class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final name = TextEditingController();
//   final id = TextEditingController(); // empid
//   final email = TextEditingController();
//   final mobile = TextEditingController();
//   final shiftgroup = TextEditingController();
//   final password = TextEditingController();
//   final location = TextEditingController();
//   final dept = TextEditingController();
//   final desig = TextEditingController();

//   bool _obscurePassword = true;
//   String status = 'Active';
//   String dialCode = '+91';

//   // === dynamic shift groups pulled from API ===
//   List<String> _shiftOptions = [];
//   bool _shiftsLoading = false;
//   String? _shiftsError;

//   @override
//   void initState() {
//     super.initState();
//     final emp = widget.editEmployee;
//     if (emp != null) {
//       name.text = emp.name;
//       id.text = emp.id;
//       email.text = emp.email;
//       mobile.text = emp.mobile.replaceFirst(RegExp(r'^\+\d+\s*'), '');
//       shiftgroup.text = emp.shiftGroup;
//       location.text = emp.location;
//       dept.text = emp.dept;
//       desig.text = emp.designation;
//       status = emp.status;
//     }
//     _loadShiftGroups();
//   }

//   Future<void> _loadShiftGroups() async {
//     setState(() {
//       _shiftsLoading = true;
//       _shiftsError = null;
//     });
//     try {
//       final list = await EmployeeService.fetchShiftGroups();
//       setState(() {
//         _shiftOptions = list;
//         _shiftsLoading = false;
//         if (shiftgroup.text.isNotEmpty && !_shiftOptions.contains(shiftgroup.text)) {
//           _shiftOptions = [shiftgroup.text, ..._shiftOptions];
//         }
//       });
//     } catch (e) {
//       setState(() {
//         _shiftsError = 'Failed to load shifts';
//         _shiftsLoading = false;
//       });
//     }
//   }

//   Widget formField(String label, TextEditingController ctrl,
//       {TextInputType type = TextInputType.text}) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextFormField(
//         controller: ctrl,
//         keyboardType: type,
//         validator: (v) {
//           if (v == null || v.trim().isEmpty) return 'Required';
//           if (label == "Email") {
//             final emailRegex =
//                 RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
//             if (!emailRegex.hasMatch(v.trim())) return 'Enter valid email';
//           }
//           return null;
//         },
//         decoration: InputDecoration(
//           label: RichText(
//             text: TextSpan(
//               text: label,
//               style: const TextStyle(color: Colors.black),
//               children: const [
//                 TextSpan(text: ' *', style: TextStyle(color: Colors.red))
//               ],
//             ),
//           ),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       ),
//     );
//   }

//   Widget passwordField() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: TextFormField(
//         controller: password,
//         obscureText: _obscurePassword,
//         validator: (v) {
//           if (widget.editEmployee != null && (v == null || v.isEmpty)) {
//             return null; // allow empty on edit
//           }
//           if (v == null || v.trim().isEmpty) return 'Required';
//           if (v.trim().length < 6) return 'Password too short';
//           return null;
//         },
//         decoration: InputDecoration(
//           label: RichText(
//             text: const TextSpan(
//               text: "Password",
//               style: TextStyle(color: Colors.black),
//               children: [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
//             ),
//           ),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//           suffixIcon: IconButton(
//             icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
//             onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget shiftDropdownField() {
//     if (_shiftsLoading) {
//       return const Padding(
//         padding: EdgeInsets.symmetric(vertical: 6),
//         child: LinearProgressIndicator(minHeight: 2),
//       );
//     }
//     final error = _shiftsError;
//     final options = _shiftOptions;
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 6),
//       child: DropdownButtonFormField<String>(
//         isExpanded: true,
//         initialValue: shiftgroup.text.isNotEmpty && options.contains(shiftgroup.text)
//             ? shiftgroup.text
//             : null,
//         items: options
//             .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
//             .toList(),
//         onChanged: (value) => setState(() => shiftgroup.text = value ?? ''),
//         validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
//         decoration: InputDecoration(
//           label: RichText(
//             text: const TextSpan(
//               text: 'Shift Group',
//               style: TextStyle(color: Colors.black),
//               children: [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
//             ),
//           ),
//           helperText: (error != null) ? error : null,
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       ),
//     );
//   }

//   void submit() {
//     if (!(_formKey.currentState?.validate() ?? false)) return;

//     final newEmp = Employee(
//       name: name.text.trim(),
//       id: id.text.trim(),
//       email: email.text.trim().toLowerCase(),
//       mobile: '$dialCode ${mobile.text.trim()}',
//       shiftGroup: shiftgroup.text.trim(),
//       location: location.text.trim(),
//       dept: dept.text.trim(),
//       designation: desig.text.trim(),
//       status: status,
//       password: password.text, // used only on create
//       role: 'employee',
//     );

//     Navigator.pop(context, newEmp);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Create Employee", style: TextStyle(fontSize: 16)),
//         backgroundColor: kAppBarColor,
//         foregroundColor: Colors.white,
//       ),
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
//           ),
//         ),
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(12),
//           child: Form(
//             key: _formKey,
//             child: Column(
//               children: [
//                 formField("Employee Name", name),
//                 formField("Employee ID", id),
//                 formField("Email", email, type: TextInputType.emailAddress),
//                 IntlPhoneField(
//                   decoration: InputDecoration(
//                     border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                     label: const Text.rich(
//                       TextSpan(
//                         text: 'Mobile',
//                         style: TextStyle(color: Colors.black, fontSize: 16),
//                         children: [TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontSize: 16))],
//                       ),
//                     ),
//                   ),
//                   initialCountryCode: 'IN',
//                   onChanged: (phone) {
//                     dialCode = phone.countryCode;
//                     mobile.text = phone.number;
//                   },
//                 ),
//                 shiftDropdownField(),
//                 passwordField(),
//                 formField("Location", location),
//                 formField("Department", dept),
//                 formField("Designation", desig),
//                 Row(
//                   children: [
//                     const Text("Status: "),
//                     Radio<String>(
//                       value: 'Active',
//                       groupValue: status,
//                       onChanged: (val) => setState(() => status = val!),
//                     ),
//                     const Text("Active"),
//                     Radio<String>(
//                       value: 'Inactive',
//                       groupValue: status,
//                       onChanged: (val) => setState(() => status = val!),
//                     ),
//                     const Text("Inactive"),
//                   ],
//                 ),
//                 const SizedBox(height: 20),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceAround,
//                   children: [
//                     ElevatedButton(
//                       onPressed: () => Navigator.pop(context),
//                       style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
//                       child: const Text("Cancel"),
//                     ),
//                     ElevatedButton(
//                       onPressed: submit,
//                       style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                       child: Text(widget.editEmployee == null ? "Create" : "Update"),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:http/http.dart' as http;
import 'report_scheduler_page.dart';

// Use localStorage only when targeting Web
// ignore: avoid_web_libraries_in_flutter
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

// >>> NEW: read token from the same in-memory place as other pages
import 'package:serv_app/models/company_data.dart';

// ===== Theme =====
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF655193);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// ===== API base =====
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api'; // keep /api here

// ===== Model =====
class Employee {
  final String name;
  final String id; // <-- Employee ID (empid)
  final String email;
  final String mobile; // phone
  final String location;
  final String dept;
  final String designation;
  final String status; // "Active"/"Inactive" (UI)
  final String shiftGroup;
  final String? docId; // Firestore document id (server generated)
  final String? password; // only used on create
  final String role; // defaults to "employee"

  Employee({
    required this.name,
    required this.id,
    required this.email,
    required this.mobile,
    required this.location,
    required this.dept,
    required this.designation,
    required this.status,
    required this.shiftGroup,
    this.docId,
    this.password,
    this.role = 'employee',
  });

  /// Build from backend JSON (GET /api/employees)
  factory Employee.fromServer(Map<String, dynamic> j) {
    return Employee(
      docId: j['id'] as String?,
      id: (j['empid'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      mobile: (j['phone'] ?? '').toString(),
      location: (j['location'] ?? '').toString(),
      dept: (j['dept'] ?? '').toString(),
      designation: (j['designation'] ?? '').toString(),
      shiftGroup: (j['shiftGroup'] ?? '').toString(),
      status: ((j['status'] ?? 'active').toString().toLowerCase() == 'active')
          ? 'Active'
          : 'Inactive',
      role: (j['role'] ?? 'employee').toString(),
    );
  }

  /// Body for POST /api/employees
  Map<String, dynamic> toCreateBody() => {
        'name': name,
        'empid': id,
        'email': email,
        'phone': mobile,
        'password': password, // backend hashes it
        'location': location,
        'dept': dept,
        'designation': designation,
        'shiftGroup': shiftGroup.isEmpty ? null : shiftGroup,
        'role': role,
      };
}

// ===== Service =====
class EmployeeService {
  static bool _looksLikeJwt(String v) =>
      RegExp(r'^[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+\.[A-Za-z0-9\-_]+$')
          .hasMatch(v);

  static String? _readToken() {
    // --- MOST IMPORTANT: app-wide in-memory token (works on Android/iOS) ---
    final mem = CompanyData.token;
    if (mem != null && mem.isNotEmpty) return mem;

    // Known keys that might be used on Web builds
    const candidates = [
      'token',
      'jwt',
      'authToken',
      'access_token',
      'accessToken',
      'id_token',
    ];

    // localStorage (Web)
    for (final k in candidates) {
      final v = html.window.localStorage[k];
      if (v != null && v.isNotEmpty) return v;
    }

    // sessionStorage (Web)
    try {
      for (final k in candidates) {
        final v = html.window.sessionStorage[k];
        if (v != null && v.isNotEmpty) return v;
      }
    } catch (_) {}

    // Fallback: scan storages for any JWT-looking value (Web)
    try {
      for (final k in html.window.localStorage.keys) {
        final v = html.window.localStorage[k];
        if (v != null && _looksLikeJwt(v)) return v;
      }
    } catch (_) {}
    try {
      for (final k in html.window.sessionStorage.keys) {
        final v = html.window.sessionStorage[k];
        if (v != null && _looksLikeJwt(v)) return v;
      }
    } catch (_) {}

    return null;
  }

  static Map<String, String> _headers() {
    final token = _readToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      headers['x-auth-token'] = token;
    }
    return headers;
  }

  static Future<List<Employee>> fetchEmployees({int limit = 50}) async {
    int page = 1;
    final List<Employee> all = [];

    while (true) {
      final url = Uri.parse('$apiBase/employees?page=$page&limit=$limit');
      final res = await http.get(url, headers: _headers());

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final List<dynamic> raw = decoded is List
            ? decoded
            : (decoded is Map<String, dynamic> && decoded['data'] is List)
                ? decoded['data'] as List
                : <dynamic>[];

        final items = raw
            .map((e) => Employee.fromServer(e as Map<String, dynamic>))
            .toList();
        all.addAll(items);

        if (items.length < limit) break; // last page
        page += 1;
        continue;
      }

      if (res.statusCode == 404) break; // no data
      throw Exception(
          'Failed to fetch employees (${res.statusCode}): ${res.body}');
    }

    return all;
  }

  static Future<String> createEmployee(Employee e) async {
    final body = jsonEncode(e.toCreateBody());
    final res = await http.post(
      Uri.parse('$apiBase/employees'),
      headers: _headers(),
      body: body,
    );
    if (res.statusCode == 201) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      if (j['id'] != null) return j['id'].toString();
      if (j['data'] is Map && (j['data'] as Map)['id'] != null) {
        return (j['data'] as Map)['id'].toString();
      }
      return '';
    }
    throw Exception('Create failed (${res.statusCode}): ${res.body}');
  }

  static Future<void> updateEmployee(
      String docId, Map<String, dynamic> updates) async {
    final res = await http.put(
      Uri.parse('$apiBase/employees/$docId'),
      headers: _headers(),
      body: jsonEncode(updates),
    );
    if (res.statusCode != 200) {
      throw Exception('Update failed (${res.statusCode}): ${res.body}');
    }
  }

  // === fetch shift groups for dropdown ===
  static Future<List<String>> fetchShiftGroups() async {
    final res =
        await http.get(Uri.parse('$apiBase/shifts'), headers: _headers());
    if (res.statusCode != 200) {
      throw Exception('Failed to load shifts (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List<dynamic>;
    final names = <String>[];
    for (final it in list) {
      final m = it as Map<String, dynamic>;
      final n = (m['name'] ?? m['shiftname'] ?? '').toString().trim();
      if (n.isNotEmpty) names.add(n);
    }
    return names;
  }

  // >>> NEW: delete employee by Firestore document id
  static Future<void> deleteEmployeeById(String docId) async {
    final res = await http.delete(
      Uri.parse('$apiBase/employees/$docId'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw Exception('Delete failed (${res.statusCode}): ${res.body}');
    }
  }
}

// ===== Screens =====
class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});
  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  List<Employee> employees = [];
  List<Employee> filtered = [];
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final list = await EmployeeService.fetchEmployees();
      setState(() {
        employees = list;
        filtered = list;
      });
    } catch (_) {
      // optionally show a SnackBar
    }
  }

  void updateFiltered(String query) {
    setState(() {
      final q = query.toLowerCase();
      filtered = employees.where((e) {
        return e.name.toLowerCase().contains(q) ||
            e.id.toLowerCase().contains(q) ||
            e.email.toLowerCase().contains(q);
      }).toList();
    });
  }

  int countStatus(String status) =>
      employees.where((e) => e.status.toLowerCase() == status.toLowerCase()).length;

  Widget statButton(String label, int count, Color color) {
    return SizedBox(
      width: 85,
      height: 30,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: kTextColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {},
        child: Text('$label $count',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  Widget _cell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        toolbarHeight: 50,
        backgroundColor: kAppBarColor,
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 0), onPressed: () {}),
        titleSpacing: 0,
        title: const Text("Employee Management",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                statButton('Total', employees.length, kButtonColor),
                statButton('Active', countStatus('Active'), kButtonColor),
                statButton('Inactive', countStatus('Inactive'), kButtonColor),
                statButton('Suspended', 0, kButtonColor),
                statButton('Relived', 0, kButtonColor),
              ],
            ),
            const SizedBox(height: 10),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final result = await Navigator.push<Employee>(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateEmployeeScreen()),
                    );
                    if (result != null) {
                      try {
                        await EmployeeService.createEmployee(result);
                        await _loadEmployees();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Employee created.')));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Create failed: $e')));
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kButtonColor,
                    foregroundColor: kTextColor,
                    minimumSize: const Size(120, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("Create Employee", style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ReportSchedulerPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kButtonColor,
                    foregroundColor: kTextColor,
                    minimumSize: const Size(120, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("Create Report Scheduler", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: searchController,
                onChanged: updateFiltered,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 1300,
                  child: Column(
                    children: [
                      Container(
                        color: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: const Row(
                          children: [
                            Expanded(flex: 4, child: Text("ID", style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 6, child: Text("Name", style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 8, child: Text("Email", style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 7, child: Text("Mobile", style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 6, child: Text("Shift Group", style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 6, child: Text("Location", style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 6, child: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 6, child: Text("Designation", style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 4, child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
                            Expanded(flex: 5, child: Center(child: Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)))),
                            Expanded(flex: 5, child: Center(child: Text("Edit", style: TextStyle(fontWeight: FontWeight.bold)))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final e = filtered[i];
                            return Container(
                              color: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _cell(e.id, flex: 4),
                                  _cell(e.name, flex: 6),
                                  _cell(e.email, flex: 8),
                                  _cell(e.mobile, flex: 7),
                                  _cell(e.shiftGroup, flex: 6),
                                  _cell(e.location, flex: 6),
                                  _cell(e.dept, flex: 6),
                                  _cell(e.designation, flex: 6),
                                  _cell(e.status, flex: 4),

                                  // >>> UPDATED DELETE BUTTON
                                  Expanded(
                                    flex: 5,
                                    child: Center(
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () async {
                                          final idToDelete = e.docId;
                                          if (idToDelete == null || idToDelete.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Missing server id for this employee')),
                                            );
                                            return;
                                          }

                                          final sure = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete employee?'),
                                              content: Text('This will permanently delete ${e.name}.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Delete'),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (sure != true) return;

                                          try {
                                            await EmployeeService.deleteEmployeeById(idToDelete);
                                            await _loadEmployees();
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Employee deleted')),
                                              );
                                            }
                                          } catch (err) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Delete failed: $err')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    flex: 5,
                                    child: Center(
                                      child: IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () async {
                                          final edited = await Navigator.push<Employee>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CreateEmployeeScreen(editEmployee: e),
                                            ),
                                          );
                                          if (edited != null) {
                                            if (e.docId != null) {
                                              try {
                                                await EmployeeService.updateEmployee(e.docId!, {
                                                  'name': edited.name,
                                                  'empid': edited.id,
                                                  'email': edited.email,
                                                  'phone': edited.mobile,
                                                  'location': edited.location,
                                                  'dept': edited.dept,
                                                  'designation': edited.designation,
                                                  'shiftGroup': edited.shiftGroup,
                                                  'status': edited.status.toLowerCase(),
                                                });
                                                await _loadEmployees();
                                              } catch (err) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Update failed: $err')),
                                                  );
                                                }
                                              }
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateEmployeeScreen extends StatefulWidget {
  final Employee? editEmployee;
  const CreateEmployeeScreen({super.key, this.editEmployee});

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final id = TextEditingController(); // empid
  final email = TextEditingController();
  final mobile = TextEditingController();
  final shiftgroup = TextEditingController();
  final password = TextEditingController();
  final location = TextEditingController();
  final dept = TextEditingController();
  final desig = TextEditingController();

  bool _obscurePassword = true;
  String status = 'Active';
  String dialCode = '+91';

  // === dynamic shift groups pulled from API ===
  List<String> _shiftOptions = [];
  bool _shiftsLoading = false;
  String? _shiftsError;

  @override
  void initState() {
    super.initState();
    final emp = widget.editEmployee;
    if (emp != null) {
      name.text = emp.name;
      id.text = emp.id;
      email.text = emp.email;
      mobile.text = emp.mobile.replaceFirst(RegExp(r'^\+\d+\s*'), '');
      shiftgroup.text = emp.shiftGroup;
      location.text = emp.location;
      dept.text = emp.dept;
      desig.text = emp.designation;
      status = emp.status;
    }
    _loadShiftGroups();
  }

  Future<void> _loadShiftGroups() async {
    setState(() {
      _shiftsLoading = true;
      _shiftsError = null;
    });
    try {
      final list = await EmployeeService.fetchShiftGroups();
      setState(() {
        _shiftOptions = list;
        _shiftsLoading = false;
        if (shiftgroup.text.isNotEmpty && !_shiftOptions.contains(shiftgroup.text)) {
          _shiftOptions = [shiftgroup.text, ..._shiftOptions];
        }
      });
    } catch (e) {
      setState(() {
        _shiftsError = 'Failed to load shifts';
        _shiftsLoading = false;
      });
    }
  }

  Widget formField(String label, TextEditingController ctrl,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: ctrl,
        keyboardType: type,
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (label == "Email") {
            final emailRegex =
                RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
            if (!emailRegex.hasMatch(v.trim())) return 'Enter valid email';
          }
          return null;
        },
        decoration: InputDecoration(
          label: RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(color: Colors.black),
              children: const [
                TextSpan(text: ' *', style: TextStyle(color: Colors.red))
              ],
            ),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget passwordField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: password,
        obscureText: _obscurePassword,
        validator: (v) {
          if (widget.editEmployee != null && (v == null || v.isEmpty)) {
            return null; // allow empty on edit
          }
          if (v == null || v.trim().isEmpty) return 'Required';
          if (v.trim().length < 6) return 'Password too short';
          return null;
        },
        decoration: InputDecoration(
          label: RichText(
            text: const TextSpan(
              text: "Password",
              style: TextStyle(color: Colors.black),
              children: [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
            ),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
    );
  }

  Widget shiftDropdownField() {
    if (_shiftsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    final error = _shiftsError;
    final options = _shiftOptions;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: shiftgroup.text.isNotEmpty && options.contains(shiftgroup.text)
            ? shiftgroup.text
            : null,
        items: options
            .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
            .toList(),
        onChanged: (value) => setState(() => shiftgroup.text = value ?? ''),
        validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
        decoration: InputDecoration(
          label: RichText(
            text: const TextSpan(
              text: 'Shift Group',
              style: TextStyle(color: Colors.black),
              children: [TextSpan(text: ' *', style: TextStyle(color: Colors.red))],
            ),
          ),
          helperText: (error != null) ? error : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newEmp = Employee(
      name: name.text.trim(),
      id: id.text.trim(),
      email: email.text.trim().toLowerCase(),
      mobile: '$dialCode ${mobile.text.trim()}',
      shiftGroup: shiftgroup.text.trim(),
      location: location.text.trim(),
      dept: dept.text.trim(),
      designation: desig.text.trim(),
      status: status,
      password: password.text, // used only on create
      role: 'employee',
    );

    Navigator.pop(context, newEmp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Employee", style: TextStyle(fontSize: 16)),
        backgroundColor: kAppBarColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                formField("Employee Name", name),
                formField("Employee ID", id),
                formField("Email", email, type: TextInputType.emailAddress),
                IntlPhoneField(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    label: const Text.rich(
                      TextSpan(
                        text: 'Mobile',
                        style: TextStyle(color: Colors.black, fontSize: 16),
                        children: [TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontSize: 16))],
                      ),
                    ),
                  ),
                  initialCountryCode: 'IN',
                  onChanged: (phone) {
                    dialCode = phone.countryCode;
                    mobile.text = phone.number;
                  },
                ),
                shiftDropdownField(),
                passwordField(),
                formField("Location", location),
                formField("Department", dept),
                formField("Designation", desig),
                Row(
                  children: [
                    const Text("Status: "),
                    Radio<String>(
                      value: 'Active',
                      groupValue: status,
                      onChanged: (val) => setState(() => status = val!),
                    ),
                    const Text("Active"),
                    Radio<String>(
                      value: 'Inactive',
                      groupValue: status,
                      onChanged: (val) => setState(() => status = val!),
                    ),
                    const Text("Inactive"),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: submit,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: Text(widget.editEmployee == null ? "Create" : "Update"),
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
}
