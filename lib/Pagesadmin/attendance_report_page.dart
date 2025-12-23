// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// // web localStorage (ignored on mobile/desktop)
// import 'package:serv_app/html_stub.dart'
//     if (dart.library.html) 'package:serv_app/html_web.dart' as html;
// import 'package:serv_app/Pagesadmin/attendance_report_screen_page.dart';

// import 'package:excel/excel.dart' as xls;
// import 'package:file_saver/file_saver.dart';

// const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
// const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
// const Color kAppBarColor = Color(0xFF8c6eaf);
// const Color kButtonColor = Color(0xFF655193);
// const Color kTextColor = Colors.white;

// const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

// class AttendanceReportScreen extends StatefulWidget {
//   const AttendanceReportScreen({super.key, required String initialFilter});

//   @override
//   State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
// }

// class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
//   DateTime _toDate = DateTime.now();

//   // Data from API
//   List<AttendanceRecord> _allRecords = [];
//   List<AttendanceRecord> _filteredRecords = [];

//   // Card counts (from API)
//   int _countActive = 0;
//   int _countOnLeave = 0;
//   int _countCheckedIn = 0;
//   int _countAbsent = 0;
//   int _countLate = 0;
//   int _countField = 0; // not available from API; keep 0
//   int _countEarly = 0;
//   int _countHalf = 0;

//   String _selectedFilter = '';
//   bool _loading = false;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _applyFilters(); // initial fetch
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

//   String _ymd(DateTime d) =>
//       '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
//   String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

//   Future<void> _applyFilters() async {
//     setState(() {
//       _loading = true;
//       _error = null;
//     });

//     try {
//       final token = await _getToken();
//       final headers = <String, String>{'Content-Type': 'application/json'};
//       if (token != null) headers['Authorization'] = 'Bearer $token';

//       final start = _ymd(_fromDate);
//       final end = _ymd(_toDate);

//       final uri =
//           Uri.parse('$_apiBase/attendance/range-summary?start=$start&end=$end');
//       final res = await http.get(uri, headers: headers);

//       if (res.statusCode != 200) {
//         setState(() {
//           _loading = false;
//           _error = 'Failed: ${res.statusCode}';
//         });
//         return;
//       }

//       final body = jsonDecode(res.body) as Map<String, dynamic>;
//       final counts = (body['counts'] as Map<String, dynamic>? ?? {});
//       final rows = (body['rows'] as List? ?? []);

//       _countActive = counts['activeEmployees'] ?? 0;
//       _countOnLeave = counts['onLeave'] ?? 0;
//       _countCheckedIn = counts['checkedIn'] ?? 0;
//       _countAbsent = counts['absent'] ?? 0;
//       _countLate = counts['lateCheckIn'] ?? 0;
//       _countEarly = counts['earlyCheckOut'] ?? 0;
//       _countHalf = counts['halfDay'] ?? 0;
//       _countField = 0; // no data in backend; keep 0

//       _allRecords = rows.map<AttendanceRecord>((r) {
//         final m = r as Map<String, dynamic>;
//         return AttendanceRecord(
//           employeeId: (m['employeeId'] ?? '').toString(),
//           employeeName: (m['employeeName'] ?? '').toString(),
//           shift: (m['shift'] ?? '').toString(),
//           date: (m['date'] ?? '').toString(),
//           checkIn: (m['checkIn'] ?? '-').toString(),
//           checkOut: (m['checkOut'] ?? '-').toString(),
//           department: (m['department'] ?? '').toString(),
//           attendance: (m['attendance'] ?? '').toString(),
//           workedHours: (m['workedHours'] ?? '-').toString(),
//         );
//       }).toList();

//       // default view = all rows for range
//       _filteredRecords = List.of(_allRecords);
//       _selectedFilter = '';
//       _searchController.clear();

//       setState(() => _loading = false);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: const Text('Filters applied!'),
//             backgroundColor: kButtonColor),
//       );
//     } catch (e) {
//       setState(() {
//         _loading = false;
//         _error = 'Network error: $e';
//       });
//     }
//   }

//   List<AttendanceRecord> _getFilteredRecordsByAttendance(String title) {
//     switch (title) {
//       case 'Active Employees':
//         final activeEmpIds = _allRecords
//             .where(
//                 (r) => r.attendance == 'Present' || r.attendance == 'Half Day')
//             .map((r) => r.employeeId)
//             .toSet();
//         final out = <AttendanceRecord>[];
//         final seen = <String>{};
//         for (final r in _allRecords) {
//           if (activeEmpIds.contains(r.employeeId) &&
//               !seen.contains(r.employeeId)) {
//             out.add(r);
//             seen.add(r.employeeId);
//           }
//         }
//         return out;
//       case 'On Leave':
//         return _allRecords.where((r) => r.attendance == 'On Leave').toList();
//       case 'Checked-In':
//         return _allRecords
//             .where((r) => r.checkIn != '-' && r.attendance != 'Absent')
//             .toList();
//       case 'Absent':
//         return _allRecords.where((r) => r.attendance == 'Absent').toList();
//       case 'Late Check-In':
//         return _allRecords
//             .where((r) =>
//                 r.checkIn != '-' &&
//                 r.attendance != 'Absent' &&
//                 r.attendance != 'On Leave')
//             .toList();
//       case 'Field Attendance':
//         return const <AttendanceRecord>[];
//       case 'Early Check-Out':
//         return _allRecords.where((r) => r.checkOut != '-').toList();
//       case 'Half Day':
//         return _allRecords.where((r) => r.attendance == 'Half Day').toList();
//       default:
//         return _allRecords;
//     }
//   }

//   void _onCardTapped(String title) {
//     setState(() {
//       if (_selectedFilter == title) {
//         _selectedFilter = '';
//         _filteredRecords = _allRecords;
//       } else {
//         _selectedFilter = title;
//         _filteredRecords = _getFilteredRecordsByAttendance(title);
//       }
//       _searchController.clear();
//     });

//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(
//           _selectedFilter.isEmpty
//               ? 'Filter cleared - showing all records'
//               : 'Showing $_selectedFilter records',
//         ),
//         backgroundColor: kButtonColor,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   void _searchEmployees(String query) {
//     setState(() {
//       final base = _selectedFilter.isEmpty
//           ? _allRecords
//           : _getFilteredRecordsByAttendance(_selectedFilter);
//       if (query.isEmpty) {
//         _filteredRecords = base;
//       } else {
//         final q = query.toLowerCase();
//         _filteredRecords = base
//             .where((r) =>
//                 r.employeeName.toLowerCase().contains(q) ||
//                 r.employeeId.toLowerCase().contains(q) ||
//                 r.department.toLowerCase().contains(q))
//             .toList();
//       }
//     });
//   }

//   Future<void> _selectDate(BuildContext ctx, bool isFrom) async {
//     final picked = await showDatePicker(
//       context: ctx,
//       initialDate: isFrom ? _fromDate : _toDate,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now(),
//       builder: (context, child) {
//         return Theme(
//           data: Theme.of(context).copyWith(
//             colorScheme: ColorScheme.light(
//               primary: kButtonColor,
//               onPrimary: kTextColor,
//               surface: kPrimaryBackgroundTop,
//               onSurface: Colors.black87,
//             ),
//           ),
//           child: child!,
//         );
//       },
//     );
//     if (picked != null) {
//       setState(() {
//         if (isFrom) {
//           _fromDate = picked;
//         } else {
//           _toDate = picked;
//         }
//       });
//     }
//   }

//   // ---- excel helpers (API expects List<CellValue>) ----
//   List<xls.CellValue> _rowVals(List<dynamic> values) => values
//       .map<xls.CellValue>((v) => xls.TextCellValue(v.toString()))
//       .toList();

//   // ---------------------- Excel download ----------------------
//   Future<void> _downloadReport() async {
//     final rows = _filteredRecords.isNotEmpty ? _filteredRecords : _allRecords;
//     if (rows.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: const Text('No data to export'),
//             backgroundColor: kButtonColor),
//       );
//       return;
//     }

//     try {
//       final book = xls.Excel.createExcel();
//       final sheetName = book.getDefaultSheet() ?? 'Sheet1';
//       final sheet = book[sheetName];

//       // Meta rows
//       sheet.appendRow(_rowVals(['Attendance', 'Reports']));

//       String two(int n) => n.toString().padLeft(2, '0');
//       final now = DateTime.now();
//       final gen =
//           '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}';
//       sheet.appendRow(_rowVals(['Generated', gen]));

//       // Header
//       final headers = <String>[
//         'Employee ID',
//         'Employee Name',
//         'Shift',
//         'Date',
//         'CheckIn',
//         'CheckOut',
//         'Department',
//         'Attendance',
//         'Worked Hours'
//       ];
//       const headerRowIndex = 2; // after meta rows
//       sheet.appendRow(_rowVals(headers));

//       // Data rows
//       for (final r in rows) {
//         sheet.appendRow(_rowVals([
//           r.employeeId,
//           r.employeeName,
//           r.shift,
//           r.date,
//           r.checkIn,
//           r.checkOut,
//           r.department,
//           r.attendance,
//           r.workedHours
//         ]));
//       }

//       // Styles (your excel version expects ExcelColor)
//       final headerStyle = xls.CellStyle(
//         bold: true,
//         backgroundColorHex: xls.ExcelColor.fromHexString('#D1C4E9'),
//         fontColorHex: xls.ExcelColor.fromHexString('#000000'),
//         horizontalAlign: xls.HorizontalAlign.Center,
//         verticalAlign: xls.VerticalAlign.Center,
//       );
//       for (int c = 0; c < headers.length; c++) {
//         sheet
//             .cell(xls.CellIndex.indexByColumnRow(
//                 columnIndex: c, rowIndex: headerRowIndex))
//             .cellStyle = headerStyle;
//       }

//       final bodyStyle = xls.CellStyle(
//         bold: false,
//         backgroundColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
//         fontColorHex: xls.ExcelColor.fromHexString('#000000'),
//         horizontalAlign: xls.HorizontalAlign.Left,
//         verticalAlign: xls.VerticalAlign.Center,
//       );
//       for (int r = headerRowIndex + 1; r <= headerRowIndex + rows.length; r++) {
//         for (int c = 0; c < headers.length; c++) {
//           sheet
//               .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
//               .cellStyle = bodyStyle;
//         }
//       }

//       final bytes = Uint8List.fromList(book.encode()!);
//       final fileName = 'attendance_${_ymd(_fromDate)}_${_ymd(_toDate)}.xlsx';

//       // Your plugin version doesn’t have `ext:`; filename already has .xlsx
//       await FileSaver.instance.saveFile(
//         name: fileName,
//         bytes: bytes,
//         mimeType: MimeType.microsoftExcel,
//       );

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Report downloaded: $fileName'),
//             backgroundColor: kButtonColor),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//             content: Text('Download failed: $e'),
//             backgroundColor: Colors.redAccent),
//       );
//     }
//   }
//   // ------------------------------------------------------------

//   @override
//   Widget build(BuildContext context) {
//     final isWeb = MediaQuery.of(context).size.width > 600;

//     return Scaffold(
//       backgroundColor: kPrimaryBackgroundBottom,
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
//           ),
//         ),
//         child: Column(
//           children: [
//             // Header + active filter pill (unchanged)
//             Container(
//               width: double.infinity,
//               color: kPrimaryBackgroundBottom.withOpacity(0.3),
//               padding: EdgeInsets.all(isWeb ? 16 : 12),
//               child: Row(
//                 children: [
//                   Text('Attendance Reports',
//                       style: TextStyle(
//                           fontWeight: FontWeight.w600, color: kButtonColor)),
//                   if (_selectedFilter.isNotEmpty) ...[
//                     const SizedBox(width: 8),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(
//                           color: kButtonColor.withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(12)),
//                       child: Row(children: [
//                         const SizedBox(width: 4),
//                         GestureDetector(
//                           onTap: () => _onCardTapped(_selectedFilter),
//                           child:
//                               Icon(Icons.close, size: 14, color: kButtonColor),
//                         ),
//                       ]),
//                     ),
//                   ],
//                 ],
//               ),
//             ),

//             Expanded(
//               child: Container(
//                 color: kPrimaryBackgroundTop,
//                 child: _loading
//                     ? const Center(child: CircularProgressIndicator())
//                     : _error != null
//                         ? Center(
//                             child: Text(_error!,
//                                 style: const TextStyle(color: Colors.red)))
//                         : SingleChildScrollView(
//                             child: Column(
//                               children: [
//                                 // Date row
//                                 Container(
//                                   padding: EdgeInsets.all(isWeb ? 16 : 12),
//                                   child: Row(
//                                     children: [
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text('From',
//                                                 style: TextStyle(
//                                                     fontWeight: FontWeight.w500,
//                                                     fontSize: isWeb ? 14 : 12,
//                                                     color: kButtonColor)),
//                                             SizedBox(height: isWeb ? 8 : 6),
//                                             GestureDetector(
//                                               onTap: () =>
//                                                   _selectDate(context, true),
//                                               child: _DateBox(
//                                                   text: _formatDate(_fromDate),
//                                                   isWeb: isWeb),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                       SizedBox(width: isWeb ? 16 : 8),
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text('To',
//                                                 style: TextStyle(
//                                                     fontWeight: FontWeight.w500,
//                                                     fontSize: isWeb ? 14 : 12,
//                                                     color: kButtonColor)),
//                                             SizedBox(height: isWeb ? 8 : 6),
//                                             GestureDetector(
//                                               onTap: () =>
//                                                   _selectDate(context, false),
//                                               child: _DateBox(
//                                                   text: _formatDate(_toDate),
//                                                   isWeb: isWeb),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),

//                                 // Download + Apply
//                                 Padding(
//                                   padding: EdgeInsets.symmetric(
//                                       horizontal: isWeb ? 16 : 12),
//                                   child: Row(
//                                     children: [
//                                       Expanded(
//                                         child: ElevatedButton.icon(
//                                           onPressed: _downloadReport,
//                                           icon: Icon(Icons.download,
//                                               size: isWeb ? 16 : 14,
//                                               color: kButtonColor),
//                                           label: Text('Download Report',
//                                               style: TextStyle(
//                                                   fontSize: isWeb ? 14 : 12,
//                                                   color: kButtonColor)),
//                                           style: ElevatedButton.styleFrom(
//                                             backgroundColor:
//                                                 kPrimaryBackgroundBottom,
//                                             foregroundColor: kButtonColor,
//                                             elevation: 0,
//                                             padding: EdgeInsets.symmetric(
//                                                 horizontal: isWeb ? 16 : 12,
//                                                 vertical: isWeb ? 10 : 8),
//                                             side:
//                                                 BorderSide(color: kButtonColor),
//                                           ),
//                                         ),
//                                       ),
//                                       SizedBox(width: isWeb ? 12 : 8),
//                                       ElevatedButton(
//                                         onPressed: _applyFilters,
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor: kButtonColor,
//                                           foregroundColor: kTextColor,
//                                           elevation: 0,
//                                           padding: EdgeInsets.symmetric(
//                                               horizontal: isWeb ? 20 : 16,
//                                               vertical: isWeb ? 10 : 8),
//                                         ),
//                                         child: Text('Apply',
//                                             style: TextStyle(
//                                                 fontSize: isWeb ? 14 : 12)),
//                                       ),
//                                     ],
//                                   ),
//                                 ),

//                                 const SizedBox(height: 10),

//                                 // Summary grid (numbers come from API)
//                                 Padding(
//                                   padding: EdgeInsets.symmetric(
//                                       horizontal: isWeb ? 16 : 12),
//                                   child: LayoutBuilder(builder: (ctx, c) {
//                                     int cols = isWeb ? 4 : 2;
//                                     double ratio = isWeb ? 2.2 : 2.5;
//                                     if (c.maxWidth < 600) {
//                                       cols = 2;
//                                       ratio = 2.0;
//                                     }
//                                     return GridView.count(
//                                       shrinkWrap: true,
//                                       physics:
//                                           const NeverScrollableScrollPhysics(),
//                                       crossAxisCount: cols,
//                                       crossAxisSpacing: isWeb ? 8 : 6,
//                                       mainAxisSpacing: isWeb ? 8 : 6,
//                                       childAspectRatio: ratio,
//                                       children: [
//                                         _buildSummaryCard(
//                                             'Active Employees',
//                                             '$_countActive',
//                                             const Color(0xFFB39DDB),
//                                             isWeb),
//                                         _buildSummaryCard(
//                                             'On Leave',
//                                             '$_countOnLeave',
//                                             const Color(0xFFD1C4E9),
//                                             isWeb),
//                                         _buildSummaryCard(
//                                             'Checked-In',
//                                             '$_countCheckedIn',
//                                             const Color(0xFFCE93D8),
//                                             isWeb),
//                                         _buildSummaryCard(
//                                             'Absent',
//                                             '$_countAbsent',
//                                             const Color(0xFFE1BEE7),
//                                             isWeb),
//                                         _buildSummaryCard(
//                                             'Late Check-In',
//                                             '$_countLate',
//                                             const Color(0xFFBA68C8),
//                                             isWeb),
//                                         _buildSummaryCard(
//                                             'Field Attendance',
//                                             '$_countField',
//                                             const Color(0xFFF8BBD0),
//                                             isWeb),
//                                         _buildSummaryCard(
//                                             'Early Check-Out',
//                                             '$_countEarly',
//                                             const Color(0xFFF48FB1),
//                                             isWeb),
//                                         _buildSummaryCard(
//                                             'Half Day',
//                                             '$_countHalf',
//                                             const Color(0xFFF06292),
//                                             isWeb),
//                                       ],
//                                     );
//                                   }),
//                                 ),

//                                 const SizedBox(height: 16),

//                                 // Search
//                                 Padding(
//                                   padding: EdgeInsets.symmetric(
//                                       horizontal: isWeb ? 16 : 12),
//                                   child: Row(
//                                     children: [
//                                       Expanded(
//                                         flex: 3,
//                                         child: SizedBox(
//                                           height: isWeb ? 40 : 35,
//                                           child: TextField(
//                                             controller: _searchController,
//                                             onChanged: _searchEmployees,
//                                             decoration: InputDecoration(
//                                               hintText: 'Search',
//                                               hintStyle: TextStyle(
//                                                   color: kButtonColor
//                                                       .withOpacity(0.6)),
//                                               prefixIcon: Icon(Icons.search,
//                                                   size: isWeb ? 20 : 18,
//                                                   color: kButtonColor),
//                                               border: OutlineInputBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(6),
//                                                   borderSide: BorderSide(
//                                                       color: kButtonColor)),
//                                               enabledBorder: OutlineInputBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(6),
//                                                   borderSide: BorderSide(
//                                                       color: kButtonColor
//                                                           .withOpacity(0.5))),
//                                               focusedBorder: OutlineInputBorder(
//                                                   borderRadius:
//                                                       BorderRadius.circular(6),
//                                                   borderSide: BorderSide(
//                                                       color: kButtonColor)),
//                                               isDense: true,
//                                               filled: true,
//                                               fillColor: kPrimaryBackgroundTop,
//                                             ),
//                                             style:
//                                                 TextStyle(color: kButtonColor),
//                                           ),
//                                         ),
//                                       ),
//                                       SizedBox(width: isWeb ? 12 : 8),
//                                       ElevatedButton(
//                                         onPressed: () {
//                                           // Keep your existing navigation for "Limit"
//                                           Navigator.push(
//                                               context,
//                                               MaterialPageRoute(
//                                                   builder: (_) =>
//                                                       const AttendanceReport()));
//                                         },
//                                         style: ElevatedButton.styleFrom(
//                                           backgroundColor: kAppBarColor,
//                                           foregroundColor: kTextColor,
//                                           padding: EdgeInsets.symmetric(
//                                               horizontal: isWeb ? 16 : 12,
//                                               vertical: isWeb ? 12 : 8),
//                                         ),
//                                         child: Text('Limit',
//                                             style: TextStyle(
//                                                 fontSize: isWeb ? 15 : 10)),
//                                       ),
//                                     ],
//                                   ),
//                                 ),

//                                 const SizedBox(height: 16),

//                                 // Table (unchanged visuals)
//                                 _AttendanceTable(
//                                     records: _filteredRecords, isWeb: isWeb),
//                                 const SizedBox(height: 16),
//                               ],
//                             ),
//                           ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSummaryCard(
//       String title, String count, Color color, bool isWeb) {
//     final isSelected = _selectedFilter == title;
//     return GestureDetector(
//       onTap: () => _onCardTapped(title),
//       child: Container(
//         padding: EdgeInsets.all(isWeb ? 8 : 6),
//         decoration: BoxDecoration(
//           color: color,
//           borderRadius: BorderRadius.circular(8),
//           border: isSelected ? Border.all(color: kButtonColor, width: 2) : null,
//           boxShadow: [
//             BoxShadow(
//                 color: kButtonColor.withOpacity(isSelected ? 0.3 : 0.1),
//                 blurRadius: isSelected ? 4 : 2,
//                 offset: const Offset(0, 2))
//           ],
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Flexible(
//               child: Text(
//                 title,
//                 style: TextStyle(
//                     fontSize: isWeb ? 30 : 12,
//                     fontWeight: FontWeight.bold,
//                     color: const Color.fromARGB(255, 0, 0, 0)),
//                 textAlign: TextAlign.center,
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//             SizedBox(height: isWeb ? 4 : 2),
//             Text(count,
//                 style: TextStyle(
//                     fontSize: isWeb ? 15 : 15,
//                     fontWeight: FontWeight.bold,
//                     color: const Color.fromARGB(234, 24, 24, 24))),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Small UI helpers (unchanged styles)
// class _DateBox extends StatelessWidget {
//   final String text;
//   final bool isWeb;
//   const _DateBox({required this.text, required this.isWeb});

//   get between => null;
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.symmetric(
//           horizontal: isWeb ? 12 : 8, vertical: isWeb ? 10 : 8),
//       decoration: BoxDecoration(
//         border: Border.all(color: kButtonColor.withOpacity(0.5)),
//         borderRadius: BorderRadius.circular(6),
//         color: kPrimaryBackgroundTop,
//       ),
//       child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
//         Expanded(
//             child: Text(text,
//                 overflow: TextOverflow.ellipsis,
//                 style:
//                     TextStyle(fontSize: isWeb ? 14 : 12, color: kButtonColor))),
//         Icon(Icons.calendar_today, size: isWeb ? 16 : 14, color: kButtonColor),
//       ]),
//     );
//   }
// }

// class _AttendanceTable extends StatelessWidget {
//   final List<AttendanceRecord> records;
//   final bool isWeb;
//   const _AttendanceTable({required this.records, required this.isWeb});
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 400,
//       margin: EdgeInsets.symmetric(horizontal: isWeb ? 16 : 12),
//       decoration: BoxDecoration(
//         color: kPrimaryBackgroundTop,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: kButtonColor.withOpacity(0.3)),
//       ),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         child: SizedBox(
//           width: isWeb ? 50 : 925,
//           child: Column(
//             children: [
//               Container(
//                 padding: EdgeInsets.all(isWeb ? 12 : 8),
//                 decoration: BoxDecoration(
//                   color: kPrimaryBackgroundBottom,
//                   borderRadius: const BorderRadius.only(
//                       topLeft: Radius.circular(8),
//                       topRight: Radius.circular(8)),
//                 ),
//                 child: Row(
//                   children: [
//                     _header('Employee ID', 100, isWeb),
//                     _header('Employee Name', 120, isWeb),
//                     _header('Shift', 80, isWeb),
//                     _header('Date', 100, isWeb),
//                     _header('CheckIn', 100, isWeb),
//                     _header('CheckOut', 100, isWeb),
//                     _header('Department', 100, isWeb),
//                     _header('Attendance', 100, isWeb),
//                     _header('Worked Hours', 100, isWeb),
//                   ],
//                 ),
//               ),
//               Expanded(
//                 child: records.isEmpty
//                     ? Center(
//                         child: Text(
//                           'No records found',
//                           style: TextStyle(
//                               fontSize: isWeb ? 14 : 12,
//                               color: kButtonColor.withOpacity(0.7)),
//                         ),
//                       )
//                     : ListView.builder(
//                         itemCount: records.length,
//                         itemBuilder: (ctx, i) {
//                           final r = records[i];
//                           return Container(
//                             padding: EdgeInsets.all(isWeb ? 12 : 8),
//                             decoration: BoxDecoration(
//                               border: Border(
//                                   bottom: BorderSide(
//                                       color: kPrimaryBackgroundBottom
//                                           .withOpacity(0.5),
//                                       width: 1)),
//                             ),
//                             child: Row(
//                               children: [
//                                 _cell(r.employeeId, 100, isWeb),
//                                 _cell(r.employeeName, 120, isWeb),
//                                 _cell(r.shift, 80, isWeb),
//                                 _cell(r.date, 100, isWeb),
//                                 _cell(r.checkIn, 100, isWeb),
//                                 _cell(r.checkOut, 100, isWeb),
//                                 _cell(r.department, 100, isWeb),
//                                 _cell(r.attendance, 100, isWeb),
//                                 _cell(r.workedHours, 100, isWeb),
//                               ],
//                             ),
//                           );
//                         },
//                       ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _header(String t, double w, bool isWeb) => SizedBox(
//         width: w,
//         child: Text(t,
//             style: TextStyle(
//                 fontWeight: FontWeight.w600,
//                 fontSize: isWeb ? 12 : 10,
//                 color: kButtonColor),
//             overflow: TextOverflow.ellipsis,
//             maxLines: 2),
//       );
//   Widget _cell(String t, double w, bool isWeb) => SizedBox(
//         width: w,
//         child: Text(t,
//             style: TextStyle(fontSize: isWeb ? 12 : 10, color: kButtonColor),
//             overflow: TextOverflow.ellipsis,
//             maxLines: 1),
//       );
// }

// // Data model (kept same fields your UI already uses)
// class AttendanceRecord {
//   final String employeeId;
//   final String employeeName;
//   final String shift;
//   final String date;
//   final String checkIn;
//   final String checkOut;
//   final String department;
//   final String attendance;
//   final String workedHours;
//   AttendanceRecord({
//     required this.employeeId,
//     required this.employeeName,
//     required this.shift,
//     required this.date,
//     required this.checkIn,
//     required this.checkOut,
//     required this.department,
//     required this.attendance,
//     required this.workedHours,
//   });
// }
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// web localStorage (ignored on mobile/desktop)
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;
import 'package:serv_app/Pagesadmin/attendance_report_screen_page.dart';

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'dart:io' show Platform, File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8c6eaf);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key, required String initialFilter});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  final TextEditingController _searchController = TextEditingController();
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  // Data from API
  List<AttendanceRecord> _allRecords = [];
  List<AttendanceRecord> _filteredRecords = [];

  // Card counts (from API)
  int _countActive = 0;
  int _countOnLeave = 0;
  int _countCheckedIn = 0;
  int _countAbsent = 0;
  int _countLate = 0;
  int _countField = 0; // not available from API; keep 0
  int _countEarly = 0;
  int _countHalf = 0;

  String _selectedFilter = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _applyFilters(); // initial fetch
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

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Future<void> _applyFilters() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final start = _ymd(_fromDate);
      final end = _ymd(_toDate);

      final uri =
          Uri.parse('$_apiBase/attendance/range-summary?start=$start&end=$end');
      final res = await http.get(uri, headers: headers);

      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'Failed: ${res.statusCode}';
        });
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final counts = (body['counts'] as Map<String, dynamic>? ?? {});
      final rows = (body['rows'] as List? ?? []);

      _countActive = counts['activeEmployees'] ?? 0;
      _countOnLeave = counts['onLeave'] ?? 0;
      _countCheckedIn = counts['checkedIn'] ?? 0;
      _countAbsent = counts['absent'] ?? 0;
      _countLate = counts['lateCheckIn'] ?? 0;
      _countEarly = counts['earlyCheckOut'] ?? 0;
      _countHalf = counts['halfDay'] ?? 0;
      _countField = 0; // no data in backend; keep 0

      _allRecords = rows.map<AttendanceRecord>((r) {
        final m = r as Map<String, dynamic>;
        return AttendanceRecord(
          employeeId: (m['employeeId'] ?? '').toString(),
          employeeName: (m['employeeName'] ?? '').toString(),
          shift: (m['shift'] ?? '').toString(),
          date: (m['date'] ?? '').toString(),
          checkIn: (m['checkIn'] ?? '-').toString(),
          checkOut: (m['checkOut'] ?? '-').toString(),
          department: (m['department'] ?? '').toString(),
          attendance: (m['attendance'] ?? '').toString(),
          workedHours: (m['workedHours'] ?? '-').toString(),
        );
      }).toList();

      // default view = all rows for range
      _filteredRecords = List.of(_allRecords);
      _selectedFilter = '';
      _searchController.clear();

      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Filters applied!'),
            backgroundColor: kButtonColor),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Network error: $e';
      });
    }
  }

  List<AttendanceRecord> _getFilteredRecordsByAttendance(String title) {
    switch (title) {
      case 'Active Employees':
        final activeEmpIds = _allRecords
            .where(
                (r) => r.attendance == 'Present' || r.attendance == 'Half Day')
            .map((r) => r.employeeId)
            .toSet();
        final out = <AttendanceRecord>[];
        final seen = <String>{};
        for (final r in _allRecords) {
          if (activeEmpIds.contains(r.employeeId) &&
              !seen.contains(r.employeeId)) {
            out.add(r);
            seen.add(r.employeeId);
          }
        }
        return out;
      case 'On Leave':
        return _allRecords.where((r) => r.attendance == 'On Leave').toList();
      case 'Checked-In':
        return _allRecords
            .where((r) => r.checkIn != '-' && r.attendance != 'Absent')
            .toList();
      case 'Absent':
        return _allRecords.where((r) => r.attendance == 'Absent').toList();
      case 'Late Check-In':
        return _allRecords
            .where((r) =>
                r.checkIn != '-' &&
                r.attendance != 'Absent' &&
                r.attendance != 'On Leave')
            .toList();
      case 'Field Attendance':
        return const <AttendanceRecord>[];
      case 'Early Check-Out':
        return _allRecords.where((r) => r.checkOut != '-').toList();
      case 'Half Day':
        return _allRecords.where((r) => r.attendance == 'Half Day').toList();
      default:
        return _allRecords;
    }
  }

  void _onCardTapped(String title) {
    setState(() {
      if (_selectedFilter == title) {
        _selectedFilter = '';
        _filteredRecords = _allRecords;
      } else {
        _selectedFilter = title;
        _filteredRecords = _getFilteredRecordsByAttendance(title);
      }
      _searchController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedFilter.isEmpty
              ? 'Filter cleared - showing all records'
              : 'Showing $_selectedFilter records',
        ),
        backgroundColor: kButtonColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _searchEmployees(String query) {
    setState(() {
      final base = _selectedFilter.isEmpty
          ? _allRecords
          : _getFilteredRecordsByAttendance(_selectedFilter);
      if (query.isEmpty) {
        _filteredRecords = base;
      } else {
        final q = query.toLowerCase();
        _filteredRecords = base
            .where((r) =>
                r.employeeName.toLowerCase().contains(q) ||
                r.employeeId.toLowerCase().contains(q) ||
                r.department.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _selectDate(BuildContext ctx, bool isFrom) async {
    final picked = await showDatePicker(
      context: ctx,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: kButtonColor,
              onPrimary: kTextColor,
              surface: kPrimaryBackgroundTop,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  // ---- excel helpers (API expects List<CellValue>) ----
  List<xls.CellValue> _rowVals(List<dynamic> values) => values
      .map<xls.CellValue>((v) => xls.TextCellValue(v.toString()))
      .toList();

  // ---------------------- Excel download ----------------------
Future<void> _downloadReport() async {
  // Use filtered list if present, otherwise all
  final rows = _filteredRecords.isNotEmpty ? _filteredRecords : _allRecords;
  if (rows.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('No data to export'), backgroundColor: kButtonColor),
    );
    return;
  }

  try {
    // ----- Build workbook (keeps your exact columns / styles) -----
    final book = xls.Excel.createExcel();
    final sheetName = book.getDefaultSheet() ?? 'Sheet1';
    final sheet = book[sheetName];

    // Meta rows
    sheet.appendRow(_rowVals(['Attendance', 'Reports']));
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final gen = '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}';
    sheet.appendRow(_rowVals(['Generated', gen]));

    // Header
    final headers = <String>[
      'Employee ID','Employee Name','Shift','Date','CheckIn','CheckOut','Department','Attendance','Worked Hours'
    ];
    const headerRowIndex = 2;
    sheet.appendRow(_rowVals(headers));

    // Data rows
    for (final r in rows) {
      sheet.appendRow(_rowVals([
        r.employeeId, r.employeeName, r.shift, r.date,
        r.checkIn, r.checkOut, r.department, r.attendance, r.workedHours
      ]));
    }

    // Styles
    final headerStyle = xls.CellStyle(
      bold: true,
      backgroundColorHex: xls.ExcelColor.fromHexString('#D1C4E9'),
      fontColorHex: xls.ExcelColor.fromHexString('#000000'),
      horizontalAlign: xls.HorizontalAlign.Center,
      verticalAlign: xls.VerticalAlign.Center,
    );
    for (int c = 0; c < headers.length; c++) {
      sheet
          .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIndex))
          .cellStyle = headerStyle;
    }

    final bodyStyle = xls.CellStyle(
      backgroundColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
      fontColorHex: xls.ExcelColor.fromHexString('#000000'),
      horizontalAlign: xls.HorizontalAlign.Left,
      verticalAlign: xls.VerticalAlign.Center,
    );
    for (int r = headerRowIndex + 1; r <= headerRowIndex + rows.length; r++) {
      for (int c = 0; c < headers.length; c++) {
        sheet
            .cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .cellStyle = bodyStyle;
      }
    }

    final bytes = Uint8List.fromList(book.encode()!);
    final fileName = 'attendance_${_ymd(_fromDate)}_${_ymd(_toDate)}.xlsx';

    // ----- Platform handling -----
    if (kIsWeb) {
      // Web: trigger browser download
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        mimeType: MimeType.microsoftExcel,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report downloaded: $fileName'), backgroundColor: kButtonColor),
      );
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: write to temp and open Share sheet (user chooses where to save)
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      final f = File(path);
      await f.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        subject: 'Attendance Report',
        text: 'Attendance report: $fileName',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report ready: $fileName'), backgroundColor: kButtonColor),
      );
      return;
    }

    // Desktop fallback
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      mimeType: MimeType.microsoftExcel,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report saved: $fileName'), backgroundColor: kButtonColor),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.redAccent),
    );
  }
}

  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: kPrimaryBackgroundBottom,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          ),
        ),
        child: Column(
          children: [
            // Header + active filter pill (unchanged)
            Container(
              width: double.infinity,
              color: kPrimaryBackgroundBottom.withOpacity(0.3),
              padding: EdgeInsets.all(isWeb ? 16 : 12),
              child: Row(
                children: [
                  Text('Attendance Reports',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: kButtonColor)),
                  if (_selectedFilter.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: kButtonColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _onCardTapped(_selectedFilter),
                          child:
                              Icon(Icons.close, size: 14, color: kButtonColor),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
            ),

            Expanded(
              child: Container(
                color: kPrimaryBackgroundTop,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.red)))
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                // Date row
                                Container(
                                  padding: EdgeInsets.all(isWeb ? 16 : 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('From',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: isWeb ? 14 : 12,
                                                    color: kButtonColor)),
                                            SizedBox(height: isWeb ? 8 : 6),
                                            GestureDetector(
                                              onTap: () =>
                                                  _selectDate(context, true),
                                              child: _DateBox(
                                                  text: _formatDate(_fromDate),
                                                  isWeb: isWeb),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: isWeb ? 16 : 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('To',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: isWeb ? 14 : 12,
                                                    color: kButtonColor)),
                                            SizedBox(height: isWeb ? 8 : 6),
                                            GestureDetector(
                                              onTap: () =>
                                                  _selectDate(context, false),
                                              child: _DateBox(
                                                  text: _formatDate(_toDate),
                                                  isWeb: isWeb),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Download + Apply
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isWeb ? 16 : 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _downloadReport,
                                          icon: Icon(Icons.download,
                                              size: isWeb ? 16 : 14,
                                              color: kButtonColor),
                                          label: Text('Download Report',
                                              style: TextStyle(
                                                  fontSize: isWeb ? 14 : 12,
                                                  color: kButtonColor)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                kPrimaryBackgroundBottom,
                                            foregroundColor: kButtonColor,
                                            elevation: 0,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: isWeb ? 16 : 12,
                                                vertical: isWeb ? 10 : 8),
                                            side:
                                                BorderSide(color: kButtonColor),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isWeb ? 12 : 8),
                                      ElevatedButton(
                                        onPressed: _applyFilters,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kButtonColor,
                                          foregroundColor: kTextColor,
                                          elevation: 0,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: isWeb ? 20 : 16,
                                              vertical: isWeb ? 10 : 8),
                                        ),
                                        child: Text('Apply',
                                            style: TextStyle(
                                                fontSize: isWeb ? 14 : 12)),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),

                                // Summary grid (numbers come from API)
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isWeb ? 16 : 12),
                                  child: LayoutBuilder(builder: (ctx, c) {
                                    int cols = isWeb ? 4 : 2;
                                    double ratio = isWeb ? 2.2 : 2.5;
                                    if (c.maxWidth < 600) {
                                      cols = 2;
                                      ratio = 2.0;
                                    }
                                    return GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: cols,
                                      crossAxisSpacing: isWeb ? 8 : 6,
                                      mainAxisSpacing: isWeb ? 8 : 6,
                                      childAspectRatio: ratio,
                                      children: [
                                        _buildSummaryCard(
                                            'Active Employees',
                                            '$_countActive',
                                            const Color(0xFFB39DDB),
                                            isWeb),
                                        _buildSummaryCard(
                                            'On Leave',
                                            '$_countOnLeave',
                                            const Color(0xFFD1C4E9),
                                            isWeb),
                                        _buildSummaryCard(
                                            'Checked-In',
                                            '$_countCheckedIn',
                                            const Color(0xFFCE93D8),
                                            isWeb),
                                        _buildSummaryCard(
                                            'Absent',
                                            '$_countAbsent',
                                            const Color(0xFFE1BEE7),
                                            isWeb),
                                        _buildSummaryCard(
                                            'Late Check-In',
                                            '$_countLate',
                                            const Color(0xFFBA68C8),
                                            isWeb),
                                        _buildSummaryCard(
                                            'Field Attendance',
                                            '$_countField',
                                            const Color(0xFFF8BBD0),
                                            isWeb),
                                        _buildSummaryCard(
                                            'Early Check-Out',
                                            '$_countEarly',
                                            const Color(0xFFF48FB1),
                                            isWeb),
                                        _buildSummaryCard(
                                            'Half Day',
                                            '$_countHalf',
                                            const Color(0xFFF06292),
                                            isWeb),
                                      ],
                                    );
                                  }),
                                ),

                                const SizedBox(height: 16),

                                // Search
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isWeb ? 16 : 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: SizedBox(
                                          height: isWeb ? 40 : 35,
                                          child: TextField(
                                            controller: _searchController,
                                            onChanged: _searchEmployees,
                                            decoration: InputDecoration(
                                              hintText: 'Search',
                                              hintStyle: TextStyle(
                                                  color: kButtonColor
                                                      .withOpacity(0.6)),
                                              prefixIcon: Icon(Icons.search,
                                                  size: isWeb ? 20 : 18,
                                                  color: kButtonColor),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: kButtonColor)),
                                              enabledBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: kButtonColor
                                                          .withOpacity(0.5))),
                                              focusedBorder: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  borderSide: BorderSide(
                                                      color: kButtonColor)),
                                              isDense: true,
                                              filled: true,
                                              fillColor: kPrimaryBackgroundTop,
                                            ),
                                            style:
                                                TextStyle(color: kButtonColor),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: isWeb ? 12 : 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          // Keep your existing navigation for "Limit"
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const AttendanceReport()));
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: kAppBarColor,
                                          foregroundColor: kTextColor,
                                          padding: EdgeInsets.symmetric(
                                              horizontal: isWeb ? 16 : 12,
                                              vertical: isWeb ? 12 : 8),
                                        ),
                                        child: Text('Limit',
                                            style: TextStyle(
                                                fontSize: isWeb ? 15 : 10)),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Table (unchanged visuals)
                                _AttendanceTable(
                                    records: _filteredRecords, isWeb: isWeb),
                                const SizedBox(height: 16),
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

  Widget _buildSummaryCard(
      String title, String count, Color color, bool isWeb) {
    final isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () => _onCardTapped(title),
      child: Container(
        padding: EdgeInsets.all(isWeb ? 8 : 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: kButtonColor, width: 2) : null,
          boxShadow: [
            BoxShadow(
                color: kButtonColor.withOpacity(isSelected ? 0.3 : 0.1),
                blurRadius: isSelected ? 4 : 2,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                    fontSize: isWeb ? 30 : 12,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 0, 0, 0)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: isWeb ? 4 : 2),
            Text(count,
                style: TextStyle(
                    fontSize: isWeb ? 15 : 15,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(234, 24, 24, 24))),
          ],
        ),
      ),
    );
  }
}

// Small UI helpers (unchanged styles)
class _DateBox extends StatelessWidget {
  final String text;
  final bool isWeb;
  const _DateBox({required this.text, required this.isWeb});

  get between => null;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isWeb ? 12 : 8, vertical: isWeb ? 10 : 8),
      decoration: BoxDecoration(
        border: Border.all(color: kButtonColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6),
        color: kPrimaryBackgroundTop,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: isWeb ? 14 : 12, color: kButtonColor))),
        Icon(Icons.calendar_today, size: isWeb ? 16 : 14, color: kButtonColor),
      ]),
    );
  }
}

class _AttendanceTable extends StatelessWidget {
  final List<AttendanceRecord> records;
  final bool isWeb;
  const _AttendanceTable({required this.records, required this.isWeb});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      margin: EdgeInsets.symmetric(horizontal: isWeb ? 16 : 12),
      decoration: BoxDecoration(
        color: kPrimaryBackgroundTop,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kButtonColor.withOpacity(0.3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: isWeb ? 50 : 925,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isWeb ? 12 : 8),
                decoration: BoxDecoration(
                  color: kPrimaryBackgroundBottom,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    _header('Employee ID', 100, isWeb),
                    _header('Employee Name', 120, isWeb),
                    _header('Shift', 80, isWeb),
                    _header('Date', 100, isWeb),
                    _header('CheckIn', 100, isWeb),
                    _header('CheckOut', 100, isWeb),
                    _header('Department', 100, isWeb),
                    _header('Attendance', 100, isWeb),
                    _header('Worked Hours', 100, isWeb),
                  ],
                ),
              ),
              Expanded(
                child: records.isEmpty
                    ? Center(
                        child: Text(
                          'No records found',
                          style: TextStyle(
                              fontSize: isWeb ? 14 : 12,
                              color: kButtonColor.withOpacity(0.7)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (ctx, i) {
                          final r = records[i];
                          return Container(
                            padding: EdgeInsets.all(isWeb ? 12 : 8),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(
                                      color: kPrimaryBackgroundBottom
                                          .withOpacity(0.5),
                                      width: 1)),
                            ),
                            child: Row(
                              children: [
                                _cell(r.employeeId, 100, isWeb),
                                _cell(r.employeeName, 120, isWeb),
                                _cell(r.shift, 80, isWeb),
                                _cell(r.date, 100, isWeb),
                                _cell(r.checkIn, 100, isWeb),
                                _cell(r.checkOut, 100, isWeb),
                                _cell(r.department, 100, isWeb),
                                _cell(r.attendance, 100, isWeb),
                                _cell(r.workedHours, 100, isWeb),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String t, double w, bool isWeb) => SizedBox(
        width: w,
        child: Text(t,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isWeb ? 12 : 10,
                color: kButtonColor),
            overflow: TextOverflow.ellipsis,
            maxLines: 2),
      );
  Widget _cell(String t, double w, bool isWeb) => SizedBox(
        width: w,
        child: Text(t,
            style: TextStyle(fontSize: isWeb ? 12 : 10, color: kButtonColor),
            overflow: TextOverflow.ellipsis,
            maxLines: 1),
      );
}

// Data model (kept same fields your UI already uses)
class AttendanceRecord {
  final String employeeId;
  final String employeeName;
  final String shift;
  final String date;
  final String checkIn;
  final String checkOut;
  final String department;
  final String attendance;
  final String workedHours;
  AttendanceRecord({
    required this.employeeId,
    required this.employeeName,
    required this.shift,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.department,
    required this.attendance,
    required this.workedHours,
  });
}