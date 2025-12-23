import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import 'leave_card.dart';
import 'leave_detail_screen.dart' show RequestDetailsCard;

class LeaveApprovalsScreen extends StatefulWidget {
  const LeaveApprovalsScreen({super.key});

  @override
  State<LeaveApprovalsScreen> createState() => _LeaveApprovalsScreenState();
}

class _LeaveApprovalsScreenState extends State<LeaveApprovalsScreen> {
  String selectedTab = 'All'; // Type filter (UI label)
  String selectedStatusFilter = 'Pending'; // Status chip
  final TextEditingController searchController = TextEditingController();

  List<Map<String, dynamic>> _rows = [];
  int _cPending = 0, _cApproved = 0, _cRejected = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAll(adjustForType: true);
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  bool _isOtherLocationTab(String label) {
    final t = label.trim().toLowerCase();
    return t == 'other location' || t == 'other_location';
  }
  /// Map UI tab → API `type` query value (what your backend expects)
  String _apiTypeForTab(String ui) {
    final t = ui.trim().toLowerCase();
    print('Getting API type for UI tab: $t');
    
    if (t == 'other location' || t == 'other_location') {
      // We won't pass this to fetchApprovals(); other-location uses its own API.
      return 'Other Location';
    }
    
    // Special case: If the tab is one of our special types, we'll do client-side filtering
    if (t == 'permission' || t == 'over time' || t == 'half day leave' || t == 'comp off' || t == 'leave type') {
      print('Using client-side filtering for tab: $t');
      return 'Leave Type';  // This matches the 'type' in your database
    }
    
    // For other cases, use the existing mapping
    switch (t) {
      case 'late check in':
        return 'attendance:late_check_in';
      case 'early check out':
        return 'attendance:early_check_out';
      case 'casual leave':
        return 'Casual Leave';
      case 'planned leave':
        return 'Planned Leave';
      case 'sick leave':
        return 'Sick Leave';
      case 'all':
      default:
        return 'all';
    }
  }

  String _normalizeDecision(String input) {
    final v = input.trim().toLowerCase();
    if (v == 'approve' || v == 'approved') return 'Approved';
    if (v == 'reject' || v == 'rejected') return 'Rejected';
    if (v == 'pending') return 'Pending';
    return input.trim();
  }

  /// Heuristic to decide if a row is attendance, leaves, or other_location.
  String _sourceFromItemOrTab(Map<String, dynamic> item) {
    // Explicit source wins.
    final s = (item['source'] ?? '').toString().toLowerCase();
    if (s == 'attendance' || s == 'leaves' || s == 'other_location') return s;

    // The tab can force it.
    if (_isOtherLocationTab(selectedTab)) return 'other_location';

    // If a leaveType field is present, it's definitely leaves.
    if ((item['leaveType'] ?? item['leave type'] ?? item['leave_type']) != null) {
      return 'leaves';
    }

    // Type/category hints.
    final typeStr =
        (item['type'] ?? item['category'] ?? '').toString().toLowerCase();
    if (typeStr.contains('other') && typeStr.contains('location')) {
      return 'other_location';
    }
    if (typeStr.contains('late') || typeStr.contains('early')) {
      return 'attendance';
    }
    if (typeStr.contains('leave') ||
        typeStr.contains('permission') ||
        typeStr.contains('overtime') ||
        typeStr.contains('half')) {
      return 'leaves';
    }

    // Field-based hints:
    if (item.containsKey('withinRadius') ||
        item.containsKey('expectedLatitude') ||
        item.containsKey('expectedLongitude') ||
        item.containsKey('distanceFromBranch') ||
        item.containsKey('requestLocation') ||
        item.containsKey('otherLocation') ||
        (item.containsKey('latitude') && item.containsKey('longitude'))) {
      return 'other_location';
    }

    // Attendance fall-back.
    return 'attendance';
  }

  // ✅ Only allow navigation for: Other Location, Late Check-In, Early Check-Out
  bool _isRowTappable(Map<String, dynamic> item) {
    if (_isOtherLocationTab(selectedTab)) return true;

    final src = _sourceFromItemOrTab(item);
    if (src == 'other_location') return true;

    if (src != 'attendance') return false;

    final type =
        (item['type'] ?? item['category'] ?? '').toString().toLowerCase();
    final isLateIn =
        type.contains('late') && type.contains('check') && type.contains('in');
    final isEarlyOut =
        type.contains('early') && type.contains('check') && type.contains('out');

    return isLateIn || isEarlyOut;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // LEAVE SUBTYPE HELPERS
  // ───────────────────────────────────────────────────────────────────────────

  String _stringOf(Map<String, dynamic> it, List<String> keys) {
    for (final k in keys) {
      final v = it[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  String _leaveTypeOf(Map<String, dynamic> it) {
    final leaveType = _stringOf(it, [
      'leave type', 'leaveType', 'leave_type',
      'leaveCategory', 'leave_category',
      'category', 'type'
    ]);
    if (leaveType.isNotEmpty) {
      print('Found leave type: "$leaveType" in item: ${it.toString()}');
    } else {
      print('No leave type found in item, available keys: ${it.keys.toList()}');
    }
    return leaveType;
  }

  bool _looksPermission(Map<String, dynamic> it) {
    final lt = _leaveTypeOf(it);
    final ltLower = lt.toLowerCase();
    final rsn = (it['reason'] ?? '').toString().toLowerCase();
    final isMatch = ltLower == 'permission time' || ltLower == 'permission' || 
                   ltLower == 'permission_time' || rsn.contains('permission');
    if (isMatch) {
      print('Permission match - Type: "$lt", Reason: "$rsn"');
    }
    return isMatch;
  }

  bool _looksOvertime(Map<String, dynamic> it) {
    final lt = _leaveTypeOf(it);
    final ltLower = lt.toLowerCase();
    final rsn = (it['reason'] ?? '').toString().toLowerCase();
    final isMatch = ltLower == 'overtime' || ltLower == 'over time' || 
                   ltLower == 'over_time' || rsn.contains('overtime') || 
                   rsn.contains('over time');
    if (isMatch) {
      print('Overtime match - Type: "$lt", Reason: "$rsn"');
    }
    return isMatch;
  }

  bool _looksHalfday(Map<String, dynamic> it) {
    final lt = _leaveTypeOf(it);
    final ltLower = lt.toLowerCase();
    final rsn = (it['reason'] ?? '').toString().toLowerCase();
    final isMatch = ltLower == 'half-day' || ltLower == 'half day' || 
                   ltLower == 'halfday' || ltLower == 'half_day' || 
                   (rsn.contains('half') && rsn.contains('day'));
    if (isMatch) {
      print('Half day match - Type: "$lt", Reason: "$rsn"');
    }
    return isMatch;
  }

  bool _looksCompoff(Map<String, dynamic> it) {
    final lt = _leaveTypeOf(it);
    final ltLower = lt.toLowerCase();
    final rsn = (it['reason'] ?? '').toString().toLowerCase();
    final isMatch = ltLower == 'comp off' || ltLower == 'compoff' || 
                   ltLower == 'comp-off' || ltLower == 'comp_off' || 
                   rsn.contains('comp off') || rsn.contains('compoff');
    if (isMatch) {
      print('Comp off match - Type: "$lt", Reason: "$rsn"');
    }
    return isMatch;
  }

  // Removed _isSpecificSubtype as it's no longer needed

  /// NEW: map Firestore leaveType → **UI label used in dropdown/tabs**
  String _uiLabelForLeaveType(Map<String, dynamic> it) {
    if (_looksPermission(it)) return 'Permission';
    if (_looksOvertime(it)) return 'Over Time';
    if (_looksHalfday(it)) return 'Half Day Leave';
    if (_looksCompoff(it)) return 'Comp Off';
    // anything else (Casual/Planned/Sick/etc.) shows under generic "Leave Type"
    return 'Leave Type';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UPDATED FILTER:
  // - For the 4 specific tabs, also FILTER CLIENT-SIDE by leaveType.
  // - For "Leave Type" tab, EXCLUDE those 4 subtypes.
  // ───────────────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _filterByTabSmart(
      List<Map<String, dynamic>> items, String tab) {
    final t = tab.trim().toLowerCase();
    print('Filtering ${items.length} items for tab: $t');

    // First, filter by the tab type if it's a specific leave type
    if (t == 'permission' || t == 'over time' || t == 'half day leave' || t == 'comp off') {
      // For these tabs, we need to check the reason field to determine the type
      final result = items.where((item) {
        final reason = (item['reason'] ?? '').toString().toLowerCase();
        final type = (item['type'] ?? '').toString().toLowerCase();
        
        if (t == 'permission') {
          // Check for permission in both type and reason fields
          final isPermission = 
              type.contains('permission') ||
              reason.contains('permission') ||
              reason == 'permission' ||
              (reason.isNotEmpty && reason.length < 20);
              
          if (isPermission) {
            print('Found permission leave - Type: $type, Reason: "$reason"');
          }
          return isPermission;
        } else if (t == 'over time') {
          final isOvertime = type.contains('overtime') || 
                            type.contains('over time') ||
                            reason.contains('overtime') || 
                            reason.contains('over time');
          if (isOvertime) {
            print('Found overtime leave - Type: $type, Reason: "$reason"');
          }
          return isOvertime;
        } else if (t == 'half day leave') {
          // Check for various ways half-day leave might be represented
          final isHalfDay = 
              (type.contains('half') && type.contains('day')) ||
              type.contains('half-day') ||
              type.contains('halfday') ||
              type.contains('half day') ||
              (reason.contains('half') && reason.contains('day')) ||
              reason.contains('half-day') ||
              reason.contains('halfday') ||
              reason.contains('half day');
          
          if (isHalfDay) {
            print('Found half day leave - Type: $type, Reason: "$reason"');
          }
          return isHalfDay;
        } else if (t == 'comp off') {
          final isCompOff = type.contains('comp') || 
                           type.contains('comp off') ||
                           type.contains('compoff') ||
                           reason.contains('comp off') || 
                           reason.contains('compoff');
          if (isCompOff) {
            print('Found comp off leave - Type: $type, Reason: "$reason"');
          }
          return isCompOff;
        }
        return false;
      }).toList();
      
      print('Found ${result.length} items matching tab: $t');
      return result;
    }

    // For 'leave type' tab, show items that don't match any specific subtype
    if (t == 'leave type') {
      final result = items.where((item) {
        final reason = (item['reason'] ?? '').toString().toLowerCase();
        final isSpecialType = 
          reason.contains('permission') ||
          reason.contains('overtime') ||
          reason.contains('over time') ||
          (reason.contains('half') && reason.contains('day')) ||
          reason.contains('half-day') ||
          reason.contains('halfday') ||
          reason.contains('half day') ||
          reason.contains('comp off') ||
          reason.contains('compoff') ||
          reason.contains('comp-off');
          
        print('Item with reason "$reason" is ${isSpecialType ? 'special' : 'generic'} leave type');
        return !isSpecialType;
      }).toList();
      
      print('Found ${result.length} generic leave type items');
      return result;
    }

    // For other tabs, return all items
    print('No specific filter for tab "$t", returning all ${items.length} items');
    return items;
  }

  /// Fetch rows for a given tab+status.
  Future<List<Map<String, dynamic>>> _fetchByTabAndStatus(
      String tab, String status) async {
    print('Fetching data for tab: $tab, status: $status');
    
    if (_isOtherLocationTab(tab)) {
      final data = await ApiService.fetchOtherLocation(status: status);
      print('Fetched ${data.length} other location items');
      return _filterByTabSmart(data, tab);
    }

    final apiType = _apiTypeForTab(tab);
    print('API type for tab "$tab": $apiType');
    
    final data = await ApiService.fetchApprovals(type: apiType, status: status);
    print('Fetched ${data.length} items from API');
    
    // Log the first few items to see their structure
    final itemsToLog = data.take(3).toList();
    for (var i = 0; i < itemsToLog.length; i++) {
      print('Item $i keys: ${itemsToLog[i].keys.toList()}');
      print('Item $i values: ${itemsToLog[i].values.take(5).toList()}...');
    }
    
    final filtered = _filterByTabSmart(data, tab);
    print('After filtering, ${filtered.length} items match tab "$tab"');
    
    return filtered;
  }

  Future<void> _loadAll({bool adjustForType = false}) async {
    setState(() => _loading = true);
    try {
      final pending  = await _fetchByTabAndStatus(selectedTab, 'Pending');
      final approved = await _fetchByTabAndStatus(selectedTab, 'Approved');
      final rejected = await _fetchByTabAndStatus(selectedTab, 'Rejected');

      final newPendingCount = pending.length;
      final newApprovedCount = approved.length;
      final newRejectedCount = rejected.length;

      String nextStatus = selectedStatusFilter;
      if (adjustForType) {
        final emptyNow = (nextStatus == 'Pending' && newPendingCount == 0) ||
            (nextStatus == 'Approved' && newApprovedCount == 0) ||
            (nextStatus == 'Rejected' && newRejectedCount == 0);
        if (emptyNow) {
          if (newPendingCount > 0) {
            nextStatus = 'Pending';
          } else if (newApprovedCount > 0) nextStatus = 'Approved';
          else if (newRejectedCount > 0) nextStatus = 'Rejected';
        }
      }

      List<Map<String, dynamic>> current;
      switch (nextStatus) {
        case 'Approved':
          current = approved;
          break;
        case 'Rejected':
          current = rejected;
          break;
        case 'Pending':
        default:
          current = pending;
          break;
      }

      if (!mounted) return;
      setState(() {
        _cPending = newPendingCount;
        _cApproved = newApprovedCount;
        _cRejected = newRejectedCount;
        selectedStatusFilter = nextStatus;
        _rows = current;
      });
    } catch (e) {
      _snack('Failed to fetch approvals: $e');
      if (!mounted) return;
      setState(() {
        _rows = [];
        _cPending = _cApproved = _cRejected = 0;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // Turn raw backend item into values for the card
  Map<String, dynamic> _toDisplay(Map<String, dynamic> item) {
    String pickStr(List keys, {String fallback = '-'}) {
      for (final k in keys) {
        final v = item[k]?.toString();
        if (v != null && v.trim().isNotEmpty) return v;
      }
      return fallback;
    }

    final requestTime = pickStr(['requestTime', 'time', 'checkIn', 'checkOut']);
    final requestDate =
        pickStr(['requestDate', 'date', 'startDate', 'selectDate'], fallback: '');

    // Show the right UI label in the card based on leaveType
    final typeLabel = _sourceFromItemOrTab(item) == 'leaves'
        ? _uiLabelForLeaveType(item)
        : pickStr(['type', 'category'], fallback: '-');

    return <String, dynamic>{
      'type': typeLabel,
      'empid': pickStr(['empid', 'empId', 'employeeId'], fallback: '-'),
      'department': pickStr(['department', 'dept'], fallback: '-'),
      'name': pickStr(['name', 'employeeName'], fallback: '-'),
      'shift': pickStr(['shift', 'shiftGroup'], fallback: '-'),
      'requestTime': requestTime,
      'requestDate': requestDate,
      'reason': pickStr(['reason', 'otherLocation'], fallback: '-'),
      'location': pickStr(['location', 'requestLocation'], fallback: '-'),
      'branchName': pickStr(['branchName', 'branchLocation'], fallback: '-'),
      'status': pickStr(['status', 'approvalStatus'], fallback: 'Pending'),
    };
  }

  // 🔧 Prefer otherLocId first to avoid mixing ids between sources
  String _pickAnyId(Map<String, dynamic> item) {
    for (final k in [
      'otherLocId',
      'requestId',
      'id',
      'docId',
      'attendanceId',
      'leaveId',
    ]) {
      final v = item[k]?.toString();
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return '';
  }

  Future<void> _openDetails(
    Map<String, dynamic> backendItem,
    Map<String, dynamic> viewItem,
  ) async {
    Map<String, dynamic> details = {};
    try {
      String src = _sourceFromItemOrTab(backendItem);
      if (_isOtherLocationTab(selectedTab)) {
        src = 'other_location';
      }

      if (src == 'attendance' || src == 'other_location') {
        final id = _pickAnyId(backendItem);
        String empid =
            (backendItem['empid'] ?? backendItem['empId'] ?? backendItem['employeeId'])?.toString() ?? '';
        String date  =
            (backendItem['requestDate'] ?? backendItem['date'] ?? backendItem['onDate'])?.toString() ?? '';
        if (date.length > 10) date = date.substring(0, 10);

        if (id.isNotEmpty) {
          details = await ApiService.fetchRequestDetails(id: id, src: src);
        } else if (empid.isNotEmpty && date.isNotEmpty) {
          details = await ApiService.fetchRequestDetails(empid: empid, date: date);
        }
      }
    } catch (e) {
      debugPrint('fetchRequestDetails failed: $e');
    }

    final merged = {...backendItem, ...viewItem, ...details};

    final decision = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestDetailsCard(data: merged)),
    );

    if (decision is String &&
        (decision.toLowerCase() == 'approved' ||
            decision.toLowerCase() == 'rejected')) {
      final normalized = _normalizeDecision(decision);
      try {
        final src = _sourceFromItemOrTab(backendItem);
        if (src == 'other_location') {
          final id = _pickAnyId(backendItem);
          if (id.isEmpty) throw 'Missing id for other-location';
          await ApiService.decideOtherLocation(
            id: id,
            status: normalized,
            remarks: backendItem['decisionRemarks'],
          );
        } else {
          final payload =
              Map<String, dynamic>.from(backendItem)..['status'] = normalized;
          await ApiService.decideApproval(
            item: payload,
            status: normalized,
            sourceHint: src,
          );
        }

        _snack('Updated: $normalized');
        await _loadAll(adjustForType: true);
      } catch (e) {
        _snack('Update failed: $e');
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const kAppBarColor = Color(0xFF8C6EAF);
    const kBgTop = Color(0xFFFFFFFF);
    const kBgBottom = Color(0xFFD1C4E9);

    final today = DateFormat('dd MMM yyyy').format(DateTime.now());

    final displayList = _rows.map(_toDisplay).toList();
    final q = searchController.text.toLowerCase();

    final filteredIndices = <int>[];
    final filteredDisplay = <Map<String, dynamic>>[];
    for (int i = 0; i < displayList.length; i++) {
      final disp = displayList[i];
      final hit =
          disp.values.any((v) => (v ?? '').toString().toLowerCase().contains(q));
      if (hit) {
        filteredIndices.add(i);
        filteredDisplay.add(disp);
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        title: const Text("Leave Approvals"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(child: Text(today)),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [kBgTop, kBgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple[100],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedTab,
                        onChanged: (val) async {
                          setState(() => selectedTab = val!);
                          await _loadAll(adjustForType: true);
                        },
                        icon: const Icon(Icons.arrow_drop_down,
                            size: 18, color: Colors.black),
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                        dropdownColor: Colors.white,
                        isDense: true,
                        isExpanded: false,
                        items: const [
                          'All',
                          'Late check in',
                          'Early check out',
                          'Leave Type',
                          'Permission',
                          'Over Time',
                          'Half Day Leave',
                          'Comp Off',
                          'Other Location',
                        ].map((t) =>
                            DropdownMenuItem(value: t, child: Text(t))).toList(),
                      ),
                    ),
                  ),
                  _buildStatusButton("Pending", _cPending),
                  const SizedBox(width: 6),
                  _buildStatusButton("Approved", _cApproved),
                  const SizedBox(width: 6),
                  _buildStatusButton("Rejected", _cRejected),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: filteredDisplay.isEmpty
                    ? const Center(child: Text('No requests'))
                    : ListView.builder(
                        itemCount: filteredDisplay.length,
                        itemBuilder: (context, viewIdx) {
                          final backendIdx = filteredIndices[viewIdx];
                          final backendItem = _rows[backendIdx];
                          final viewItem = filteredDisplay[viewIdx];

                          final tappable = _isRowTappable(backendItem);

                          final card = LeaveCard(
                            item: viewItem,
                            onStatusChange: (status) async {
                              try {
                                final normalized = _normalizeDecision(status);
                                if (normalized != 'Approved' &&
                                    normalized != 'Rejected') {
                                  throw 'Invalid status "$status"';
                                }
                                final src = _sourceFromItemOrTab(backendItem);

                                if (src == 'other_location') {
                                  final id = _pickAnyId(backendItem);
                                  if (id.isEmpty) throw 'Missing id for other-location';
                                  await ApiService.decideOtherLocation(
                                    id: id,
                                    status: normalized,
                                    remarks: backendItem['decisionRemarks'],
                                  );
                                } else {
                                  final payloadItem =
                                      Map<String, dynamic>.from(backendItem)
                                        ..['status'] = normalized;
                                  await ApiService.decideApproval(
                                    item: payloadItem,
                                    status: normalized,
                                    sourceHint: src,
                                  );
                                }

                                _snack('Updated: $normalized');
                                await _loadAll(adjustForType: true);
                              } catch (e) {
                                _snack('Update failed: $e');
                              }
                            },
                          );

                          if (!tappable) return card;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _openDetails(backendItem, viewItem),
                            child: card,
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String label, int count) {
    final color = label == 'Pending'
        ? Colors.pink[100]!
        : label == 'Approved'
            ? Colors.greenAccent
            : Colors.red[200]!;
    final isSelected = selectedStatusFilter == label;

    return GestureDetector(
      onTap: () async {
        setState(() => selectedStatusFilter = label);
        await _loadAll();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(isSelected ? 1.0 : 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black),
        ),
        child: Text(
          "$label ($count)",
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
        ),
      ),
    );
  }
}
