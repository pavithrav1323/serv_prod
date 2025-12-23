import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Only available on web; safely ignored on mobile/desktop.
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF); // Light lavender
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9); // Deeper lavender
const Color kAppBarColor = Color(0xFF8c6eaf);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class AttendanceReport extends StatefulWidget {
  const AttendanceReport({super.key});

  @override
  State<AttendanceReport> createState() => _AttendanceReportState();
}

class _AttendanceReportState extends State<AttendanceReport> {
  final TextEditingController _searchController = TextEditingController();

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  // API data
  List<AttendanceRecord> _allRecords = [];
  List<AttendanceRecord> _filteredRecords = [];

  // UI state
  String _selectedFilter = '';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRange(); // initial load for last 7 days
  }

  // ------- helpers: auth + dates -------
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

  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }

  // ------- API fetch -------
  Future<void> _fetchRange() async {
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
      final rows = (body['rows'] as List? ?? []);

      _allRecords = rows.map<AttendanceRecord>((raw) {
        final m = raw as Map<String, dynamic>;
        return AttendanceRecord(
          employeeId: (m['employeeId'] ?? m['empid'] ?? '').toString(),
          employeeName: (m['employeeName'] ?? m['name'] ?? '').toString(),
          shift: (m['shift'] ?? m['shiftGroup'] ?? '').toString(),
          date: (m['date'] ?? '').toString(),
          checkIn: (m['checkIn'] ?? '-').toString(),
          checkOut: (m['checkOut'] ?? '-').toString(),
          department: (m['department'] ?? m['dept'] ?? '').toString(),
          attendance: (m['attendance'] ?? m['status'] ?? '').toString(),
          workedHours: (m['workedHours'] ?? '-').toString(),
        );
      }).toList();

      _selectedFilter = '';
      _searchController.clear();
      _filteredRecords = List.of(_allRecords);

      setState(() => _loading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Filters applied!'),
            backgroundColor: kButtonColor,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Network error: $e';
      });
    }
  }

  // ------- filtering -------
  bool _matchesFilter(AttendanceRecord record, String filter) {
    switch (filter) {
      case 'Present':
        return record.attendance == 'Present';
      case 'Absent':
        return record.attendance == 'Absent';
      case 'On Leave':
        return record.attendance == 'On Leave' || record.attendance == 'Leave';
      case 'Holiday':
        return record.attendance == 'Holiday';
      case 'Week Off':
        return record.attendance == 'Week Off' ||
            record.attendance == 'WeekOff';
      case 'Half Day':
        return record.attendance == 'Half Day';
      case 'Regularized':
        return record.attendance == 'Regularized';
      default:
        return true;
    }
  }

  int _getCountForType(String type) {
    return _allRecords.where((r) => _matchesFilter(r, type)).length;
  }

  void _filterByAttendanceType(String attendanceType) {
    setState(() {
      _selectedFilter = _selectedFilter == attendanceType ? '' : attendanceType;
      _searchController.clear();

      if (_selectedFilter.isEmpty) {
        _filteredRecords = _allRecords;
      } else {
        _filteredRecords = _allRecords
            .where((r) => _matchesFilter(r, _selectedFilter))
            .toList();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _selectedFilter.isEmpty
              ? 'Filter cleared - showing all records'
              : 'Filtered by: $_selectedFilter',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _searchEmployees(String query) {
    setState(() {
      final baseRecords = _selectedFilter.isEmpty
          ? _allRecords
          : _allRecords
              .where((r) => _matchesFilter(r, _selectedFilter))
              .toList();

      if (query.isEmpty) {
        _filteredRecords = baseRecords;
      } else {
        final q = query.toLowerCase();
        _filteredRecords = baseRecords
            .where((r) =>
                r.employeeName.toLowerCase().contains(q) ||
                r.employeeId.toLowerCase().contains(q) ||
                r.department.toLowerCase().contains(q))
            .toList();
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
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
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  // ================= Excel Download (FIXED for excel v4) =================
  Future<void> _downloadReport() async {
    final rows = _filteredRecords.isNotEmpty ? _filteredRecords : _allRecords;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('No data to export'),
            backgroundColor: kButtonColor),
      );
      return;
    }

    try {
      final book = xls.Excel.createExcel(); // creates workbook with 'Sheet1'
      final sheetName = book.getDefaultSheet() ?? 'Sheet1';
      final sheet = book[sheetName];

      // Meta rows
      sheet.appendRow(<xls.CellValue?>[
        xls.TextCellValue('Attendance'),
        xls.TextCellValue('Reports'),
      ]);

      String two(int n) => n.toString().padLeft(2, '0');
      final now = DateTime.now();
      final generatedAt =
          '${two(now.day)}/${two(now.month)}/${now.year} ${two(now.hour)}:${two(now.minute)}';
      sheet.appendRow(<xls.CellValue?>[
        xls.TextCellValue('Generated'),
        xls.TextCellValue(generatedAt),
      ]);

      // Headers
      final headers = <String>[
        'Employee ID',
        'Employee Name',
        'Shift',
        'Date',
        'CheckIn',
        'CheckOut',
        'Department',
        'Attendance',
        'Worked Hours'
      ];
      const headerRowIndex = 2; // after the two meta rows
      sheet.appendRow(
          headers.map<xls.CellValue?>((h) => xls.TextCellValue(h)).toList());

      // Data rows
      for (final r in rows) {
        sheet.appendRow(<xls.CellValue?>[
          xls.TextCellValue(r.employeeId),
          xls.TextCellValue(r.employeeName),
          xls.TextCellValue(r.shift),
          xls.TextCellValue(r.date),
          xls.TextCellValue(r.checkIn),
          xls.TextCellValue(r.checkOut),
          xls.TextCellValue(r.department),
          xls.TextCellValue(r.attendance),
          xls.TextCellValue(r.workedHours),
        ]);
      }

      // Styles (use ExcelColor, not String)
      final headerStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.fromHexString('#FFD1C4E9'),
        fontColorHex: xls.ExcelColor.fromHexString('#FF000000'),
        horizontalAlign: xls.HorizontalAlign.Center,
        verticalAlign: xls.VerticalAlign.Center,
      );
      for (int c = 0; c < headers.length; c++) {
        sheet
            .cell(xls.CellIndex.indexByColumnRow(
                columnIndex: c, rowIndex: headerRowIndex))
            .cellStyle = headerStyle;
      }

      final bodyStyle = xls.CellStyle(
        bold: false,
        backgroundColorHex: xls.ExcelColor.fromHexString('#FFFFFFFF'),
        fontColorHex: xls.ExcelColor.fromHexString('#FF000000'),
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

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        // ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Report downloaded: $fileName'),
            backgroundColor: kButtonColor),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }
  // ======================================================================

  // =================== UI ===================
  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E8),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: kPrimaryBackgroundBottom.withOpacity(0.3),
            padding: EdgeInsets.all(isWeb ? 16 : 12),
            child: Row(
              children: [
                Icon(Icons.chevron_right, color: kButtonColor),
                const SizedBox(width: 4),
                Text(
                  'Attendance Reports',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kButtonColor,
                  ),
                ),
                if (_selectedFilter.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: kButtonColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _filterByAttendanceType(_selectedFilter),
                          child:
                              Icon(Icons.close, size: 14, color: kButtonColor),
                        ),
                      ],
                    ),
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
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              // === DATE FILTER ROW ===
                              Container(
                                padding: EdgeInsets.all(isWeb ? 16 : 12),
                                child: Row(
                                  children: [
                                    // From
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'From',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: isWeb ? 14 : 12,
                                              color: kButtonColor,
                                            ),
                                          ),
                                          SizedBox(height: isWeb ? 8 : 6),
                                          GestureDetector(
                                            onTap: () =>
                                                _selectDate(context, true),
                                            child: _DateBox(
                                              text: _formatDate(_fromDate),
                                              isWeb: isWeb,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(width: isWeb ? 16 : 8),

                                    // To
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'To',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: isWeb ? 14 : 12,
                                              color: kButtonColor,
                                            ),
                                          ),
                                          SizedBox(height: isWeb ? 8 : 6),
                                          GestureDetector(
                                            onTap: () =>
                                                _selectDate(context, false),
                                            child: _DateBox(
                                              text: _formatDate(_toDate),
                                              isWeb: isWeb,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Buttons
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isWeb ? 16 : 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: _downloadReport,
                                        icon: Icon(
                                          Icons.download,
                                          size: isWeb ? 16 : 14,
                                          color: kButtonColor,
                                        ),
                                        label: Text(
                                          'Download Report',
                                          style: TextStyle(
                                            fontSize: isWeb ? 14 : 12,
                                            color: kButtonColor,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              kPrimaryBackgroundBottom,
                                          foregroundColor: kButtonColor,
                                          elevation: 0,
                                          padding: EdgeInsets.symmetric(
                                            horizontal: isWeb ? 16 : 12,
                                            vertical: isWeb ? 10 : 8,
                                          ),
                                          side: BorderSide(color: kButtonColor),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: isWeb ? 12 : 8),
                                    ElevatedButton(
                                      onPressed:
                                          _fetchRange, // re-fetch using selected dates
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kButtonColor,
                                        foregroundColor: kTextColor,
                                        elevation: 0,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isWeb ? 20 : 16,
                                          vertical: isWeb ? 10 : 8,
                                        ),
                                      ),
                                      child: Text(
                                        'Apply',
                                        style: TextStyle(
                                            fontSize: isWeb ? 14 : 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Summary Cards
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: isWeb ? 16 : 12),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    int crossAxisCount = isWeb ? 4 : 2;
                                    double childAspectRatio = isWeb ? 2.2 : 2.5;

                                    if (constraints.maxWidth < 600) {
                                      crossAxisCount = 2;
                                      childAspectRatio = 2.0;
                                    }

                                    return GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: isWeb ? 8 : 6,
                                      mainAxisSpacing: isWeb ? 8 : 6,
                                      childAspectRatio: childAspectRatio,
                                      children: [
                                        _buildSummaryCard(
                                          'Present',
                                          _getCountForType('Present')
                                              .toString(),
                                          const Color(0xFFB39DDB),
                                          isWeb,
                                        ),
                                        _buildSummaryCard(
                                          'Absent',
                                          _getCountForType('Absent').toString(),
                                          const Color(0xFFD1C4E9),
                                          isWeb,
                                        ),
                                        _buildSummaryCard(
                                          'On Leave',
                                          _getCountForType('On Leave')
                                              .toString(),
                                          const Color(0xFFCE93D8),
                                          isWeb,
                                        ),
                                        _buildSummaryCard(
                                          'Holiday',
                                          _getCountForType('Holiday')
                                              .toString(),
                                          const Color(0xFFE1BEE7),
                                          isWeb,
                                        ),
                                        _buildSummaryCard(
                                          'Week Off',
                                          _getCountForType('Week Off')
                                              .toString(),
                                          const Color(0xFFBA68C8),
                                          isWeb,
                                        ),
                                        _buildSummaryCard(
                                          'Half Day',
                                          _getCountForType('Half Day')
                                              .toString(),
                                          const Color(0xFFF8BBD0),
                                          isWeb,
                                        ),
                                        _buildSummaryCard(
                                          'Regularized',
                                          _getCountForType('Regularized')
                                              .toString(),
                                          const Color(0xFFF06292),
                                          isWeb,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),

                              SizedBox(height: isWeb ? 16 : 12),

                              // Search
                              Container(
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
                                              color:
                                                  kButtonColor.withOpacity(0.6),
                                            ),
                                            prefixIcon: Icon(
                                              Icons.search,
                                              size: isWeb ? 20 : 18,
                                              color: kButtonColor,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: BorderSide(
                                                  color: kButtonColor),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: BorderSide(
                                                color: kButtonColor
                                                    .withOpacity(0.5),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: BorderSide(
                                                  color: kButtonColor),
                                            ),
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                              horizontal: isWeb ? 12 : 8,
                                              vertical: isWeb ? 8 : 6,
                                            ),
                                            isDense: true,
                                          ),
                                          style: TextStyle(color: kButtonColor),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              // === ATTENDANCE TABLE ===
                              Container(
                                height: 400,
                                margin: EdgeInsets.symmetric(
                                    horizontal: isWeb ? 16 : 12),
                                decoration: BoxDecoration(
                                  color: kPrimaryBackgroundTop,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: kButtonColor.withOpacity(0.3),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: isWeb ? 690 : 690,
                                    child: Column(
                                      children: [
                                        // Header Row
                                        Container(
                                          padding:
                                              EdgeInsets.all(isWeb ? 12 : 8),
                                          decoration: BoxDecoration(
                                            color: kPrimaryBackgroundBottom,
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(8),
                                              topRight: Radius.circular(8),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              _buildHeaderCell('Employee ID',
                                                  isWeb ? 80 : 70, isWeb),
                                              _buildHeaderCell('Employee Name',
                                                  isWeb ? 100 : 90, isWeb),
                                              _buildHeaderCell('Shift',
                                                  isWeb ? 70 : 60, isWeb),
                                              _buildHeaderCell('Date',
                                                  isWeb ? 80 : 70, isWeb),
                                              _buildHeaderCell('CheckIn',
                                                  isWeb ? 70 : 60, isWeb),
                                              _buildHeaderCell('CheckOut',
                                                  isWeb ? 70 : 60, isWeb),
                                              _buildHeaderCell('Department',
                                                  isWeb ? 80 : 70, isWeb),
                                              _buildHeaderCell('Attendance',
                                                  isWeb ? 80 : 70, isWeb),
                                              _buildHeaderCell(
                                                  'Total Worked Hours',
                                                  isWeb ? 110 : 110,
                                                  isWeb),
                                            ],
                                          ),
                                        ),

                                        // Data Rows
                                        Expanded(
                                          child: _filteredRecords.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    'No records found${_selectedFilter.isNotEmpty ? ' for $_selectedFilter' : ''}',
                                                    style: TextStyle(
                                                      fontSize: isWeb ? 14 : 12,
                                                      color: kButtonColor
                                                          .withOpacity(0.7),
                                                    ),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  itemCount:
                                                      _filteredRecords.length,
                                                  itemBuilder: (ctx, i) {
                                                    final r =
                                                        _filteredRecords[i];
                                                    return Container(
                                                      padding: EdgeInsets.all(
                                                          isWeb ? 12 : 8),
                                                      decoration: BoxDecoration(
                                                        border: Border(
                                                          bottom: BorderSide(
                                                            color:
                                                                kPrimaryBackgroundBottom
                                                                    .withOpacity(
                                                                        0.5),
                                                            width: 1,
                                                          ),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          _buildDataCell(
                                                              r.employeeId,
                                                              isWeb ? 80 : 70,
                                                              isWeb),
                                                          _buildDataCell(
                                                              r.employeeName,
                                                              isWeb ? 100 : 90,
                                                              isWeb),
                                                          _buildDataCell(
                                                              r.shift,
                                                              isWeb ? 70 : 60,
                                                              isWeb),
                                                          _buildDataCell(
                                                              r.date,
                                                              isWeb ? 80 : 70,
                                                              isWeb),
                                                          _buildDataCell(
                                                              r.checkIn,
                                                              isWeb ? 70 : 60,
                                                              isWeb),
                                                          _buildDataCell(
                                                              r.checkOut,
                                                              isWeb ? 70 : 60,
                                                              isWeb),
                                                          _buildDataCell(
                                                              r.department,
                                                              isWeb ? 80 : 70,
                                                              isWeb),
                                                          _buildDataCell(
                                                              r.attendance,
                                                              isWeb ? 80 : 70,
                                                              isWeb),
                                                          _buildDataCell(
                                                              r.workedHours,
                                                              isWeb ? 90 : 80,
                                                              isWeb),
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
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  // ------- small UI pieces -------
  Widget _buildHeaderCell(String text, double width, bool isWeb) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isWeb ? 12 : 10,
          color: kButtonColor,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  Widget _buildDataCell(String text, double width, bool isWeb) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: TextStyle(fontSize: isWeb ? 12 : 10, color: kButtonColor),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    Color color,
    bool isWeb,
  ) {
    final isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: () => _filterByAttendanceType(title),
      child: Container(
        padding: EdgeInsets.all(isWeb ? 8 : 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: kButtonColor, width: 2) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kButtonColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: kButtonColor.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
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
                  color: const Color.fromARGB(255, 0, 0, 0),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: isWeb ? 4 : 2),
            Text(
              count,
              style: TextStyle(
                fontSize: isWeb ? 15 : 15,
                fontWeight: FontWeight.bold,
                color: const Color.fromARGB(234, 24, 24, 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Data model
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

class _DateBox extends StatelessWidget {
  final String text;
  final bool isWeb;
  const _DateBox({required this.text, required this.isWeb});

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: isWeb ? 14 : 12, color: kButtonColor),
            ),
          ),
          Icon(Icons.calendar_today,
              size: isWeb ? 16 : 14, color: kButtonColor),
        ],
      ),
    );
  }
}
