// lib/models/leave_approval.dart
class LeaveApproval {
  final String source;           // "attendance" | "leaves" (we use "attendance" here)
  final String requestId;
  final String type;             // "Late check in", etc.
  final String empid;
  final String name;
  final String department;
  final int? shift;
  final String? shiftGroup;
  final String? requestTime;     // "HH:mm:ss"
  final String requestDate;      // "YYYY-MM-DD"
  final String? reason;          // "-" or text
  final String? location;        // city/branch
  final double? latitude;
  final double? longitude;
  String status;                 // "Pending" | "Approved" | "Rejected"

  LeaveApproval({
    required this.source,
    required this.requestId,
    required this.type,
    required this.empid,
    required this.name,
    required this.department,
    required this.shift,
    required this.shiftGroup,
    required this.requestTime,
    required this.requestDate,
    required this.reason,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  factory LeaveApproval.fromJson(Map<String, dynamic> j) {
    double? numToDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return LeaveApproval(
      source:      (j['source'] ?? '').toString(),
      requestId:   (j['requestId'] ?? '').toString(),
      type:        (j['type'] ?? '').toString(),
      empid:       (j['empid'] ?? j['id'] ?? '').toString(),
      name:        (j['name'] ?? '').toString(),
      department:  (j['department'] ?? '').toString(),
      shift:       j['shift'] == null ? null : int.tryParse(j['shift'].toString()),
      shiftGroup:  j['shiftGroup']?.toString(),
      requestTime: j['requestTime']?.toString(),
      requestDate: (j['requestDate'] ?? '').toString(),
      reason:      j['reason']?.toString(),
      location:    j['location']?.toString(),
      latitude:    numToDouble(j['latitude']),
      longitude:   numToDouble(j['longitude']),
      status:      (j['status'] ?? '').toString(),
    );
  }

  /// Keep UI unchanged — the cards expect a Map with keys similar to your mock data.
  Map<String, dynamic> toMap() => {
        'type': type,
        'id': empid,                 // 👈 existing UI shows "Employee ID: ${data['id']}"
        'empid': empid,
        'name': name,
        'department': department,
        'requestType': type,
        'reason': (reason == null || reason!.trim().isEmpty) ? '-' : reason,
        'shift': shift,
        'shiftGroup': shiftGroup,
        'requestTime': requestTime ?? '',
        'requestDate': _ddMMyyyyFromIso(requestDate),
        'status': status.toLowerCase(), // cards compare lowercase
        'requestLocation': location ?? '',
        'branchLocation': '',           // not provided by API
        'latitude': latitude,
        'longitude': longitude,
        // extras for decision
        '_requestId': requestId,
        '_requestDateIso': requestDate,
        '_source': source,
      };

  static String _ddMMyyyyFromIso(String isoYmd) {
    // "2025-08-11" -> "11-08-2025" to match the UI's sample format
    if (isoYmd.length >= 10 && isoYmd.contains('-')) {
      final y = isoYmd.substring(0, 4);
      final m = isoYmd.substring(5, 7);
      final d = isoYmd.substring(8, 10);
      return '$d-$m-$y';
    }
    return isoYmd;
  }
}
