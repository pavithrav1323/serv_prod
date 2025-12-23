import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'package:serv_app/models/company_data.dart';
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

const String _defaultApiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';
const String apiBase =
    String.fromEnvironment('API_BASE', defaultValue: _defaultApiBase);

class ApiService {
  // Aggregator (attendance + leaves)
  static const List<String> _approvalsPaths = [
    '/attendance/approvals',
  ];

  // Dedicated Other-Location (optional in backend)
  static const String _otherLocPath = '/attendance/other-location';
  static const String _otherLocDecisionPath =
      '/attendance/other-location/decision';

  static const String _myRequestsPath = '/attendance/my-requests';

  // ---------------- auth ----------------
  static Future<Map<String, String>> _authHeaders({bool json = true}) async {
    String? token = CompanyData.token;
    if ((token!.isEmpty) && kIsWeb) {
      try {
        final t1 = html.window.localStorage['token'];
        final t2 = html.window.sessionStorage['token'];
        token = (t1 != null && t1.isNotEmpty) ? t1 : (t2 ?? token);
      } catch (_) {}
    }
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ------------ friendly error helpers ------------
  static Exception _friendlyNetworkError(Object e) {
    const msg =
        'Network unavailable. Please check your connection and try again.';
    if (e is TimeoutException ||
        e is SocketException ||
        e is HandshakeException) {
      return Exception(msg);
    }
    if (e is http.ClientException &&
        (e.message.contains('Failed host lookup') ||
            e.message.contains('No address associated with hostname'))) {
      return Exception(msg);
    }
    return Exception(msg);
  }

  static Future<http.Response> _safeGet(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    try {
      return await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  static Future<http.Response> _safePost(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    try {
      return await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw _friendlyNetworkError(e);
    }
  }

  // -------------- helpers --------------
  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _mapTypeForServer(String? uiOrCode) {
    if (uiOrCode == null) return '';
    final raw = uiOrCode.trim();
    if (raw.isEmpty) return '';
    final lower = raw.toLowerCase();
    if (lower == 'other location' ||
        lower == 'other_location' ||
        lower == 'other-location' ||
        lower.contains('attendance:other_location')) {
      return '';
    }
    switch (lower) {
      case 'all':
      case 'type':
        return '';
      case 'late check in':
        return 'late check in';
      case 'early check out':
        return 'early check out';
      case 'leave type':
        return 'leave type';
      case 'permission':
        return 'permission';
      case 'over time':
        return 'over time';
      case 'half day leave':
        return 'half day leave';
      case 'comp off':
        return 'comp off';
      default:
        return raw;
    }
  }

  static String? _normStatus(String? status) {
    if (status == null) return null;
    final s = status.trim().toLowerCase();
    if (s.isEmpty || s == 'all' || s == 'status') return null;
    if (s == 'pending') return 'Pending';
    if (s == 'approved') return 'Approved';
    if (s == 'rejected') return 'Rejected';
    return status.trim();
  }

  static String? _inferSource(Map<String, dynamic> item, {String? hint}) {
    final fromItem = (item['source'] ?? item['collection'] ?? item['src'])
        ?.toString()
        .toLowerCase();
    if (fromItem == 'attendance' || fromItem == 'leaves') return fromItem;

    final t = (item['type'] ?? item['category'] ?? hint ?? '')
        .toString()
        .toLowerCase();
    if (t.contains('late') ||
        t.contains('early') ||
        t.contains('attend') ||
        t.contains('other location')) {
      return 'attendance';
    }
    if (t.contains('leave') ||
        t.contains('permission') ||
        t.contains('over time') ||
        t.contains('half') ||
        t.contains('comp')) {
      return 'leaves';
    }

    if (item.containsKey('checkIn') ||
        item.containsKey('checkOut') ||
        item.containsKey('requestTime')) {
      return 'attendance';
    }
    if (item.containsKey('leaveType') ||
        item.containsKey('fromDate') ||
        item.containsKey('toDate')) {
      return 'leaves';
    }
    return null;
  }

  static bool _ok(http.Response r) => r.statusCode >= 200 && r.statusCode < 300;
  static bool _is404(http.Response r) => r.statusCode == 404;

  // -------------- HTTP helpers --------------
  static Future<http.Response> _getWithFallback(
    List<String> paths, {
    Map<String, String>? query,
  }) async {
    final headers = await _authHeaders();
    http.Response? last;
    for (final p in paths) {
      final uri = Uri.parse('$apiBase$p').replace(queryParameters: query);
      final resp = await _safeGet(uri, headers: headers);
      last = resp;
      if (_ok(resp)) return resp;
    }
    return last!;
  }

  static Future<http.Response> _postWithFallback(
    List<String> paths, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final headers = await _authHeaders();
    http.Response? last;
    for (final p in paths) {
      final uri = Uri.parse('$apiBase$p').replace(queryParameters: query);
      final resp = await _safePost(uri, headers: headers, body: body);
      last = resp;
      if (_ok(resp)) return resp;
    }
    return last!;
  }

  // ================== ADMIN ==================
  static Future<List<Map<String, dynamic>>> fetchApprovals({
    required String type,
    required String status,
    String? start,
    String? end,
  }) async {
    final mappedType = _mapTypeForServer(type);
    final qp = <String, String>{
      if (mappedType.isNotEmpty) 'type': mappedType,
      if (_normStatus(status) != null) 'status': _normStatus(status)!,
      if (start != null && start.isNotEmpty) 'start': start,
      if (end != null && end.isNotEmpty) 'end': end,
    };

    final res = await _getWithFallback(_approvalsPaths, query: qp);
    if (!_ok(res)) {
      throw Exception(
          'Failed to fetch approvals (${res.statusCode}): ${res.body}');
    }

    final body = json.decode(res.body);
    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (body is Map && body['items'] is List) {
      return (body['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (body is Map<String, dynamic>) return [body];
    return <Map<String, dynamic>>[];
  }

  static Future<List<Map<String, dynamic>>> fetchOtherLocation({
    required String status,
    String? start,
    String? end,
  }) async {
    final headers = await _authHeaders();
    final qp = <String, String>{
      'status': (_normStatus(status) ?? 'All'),
      if (start != null && start.isNotEmpty) 'start': start,
      if (end != null && end.isNotEmpty) 'end': end,
    };

    final first = await _safeGet(
      Uri.parse('$apiBase$_otherLocPath').replace(queryParameters: qp),
      headers: headers,
    );
    if (_ok(first)) {
      final body = jsonDecode(first.body);
      if (body is List) {
        return body
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return <Map<String, dynamic>>[];
    }

    if (_is404(first)) {
      final aggQp = <String, String>{
        'type': 'attendance:other_location',
        if (_normStatus(status) != null) 'status': _normStatus(status)!,
        if (start != null && start.isNotEmpty) 'start': start,
        if (end != null && end.isNotEmpty) 'end': end,
      };
      final res = await _getWithFallback(_approvalsPaths, query: aggQp);
      if (!_ok(res)) {
        throw Exception(
            'Failed to fetch other-location via fallback (${res.statusCode}): ${res.body}');
      }
      final body = json.decode(res.body);
      if (body is List) {
        return body
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return <Map<String, dynamic>>[];
    }

    throw Exception(
        'Failed to fetch other-location (${first.statusCode}): ${first.body}');
  }

  static Future<void> decideApproval({
    required Map<String, dynamic> item,
    required String status,
    String? remarks,
    String? sourceHint,
  }) async {
    final s = status.trim().toLowerCase();
    final normalizedStatus = (s == 'approve' || s == 'approved')
        ? 'Approved'
        : (s == 'reject' || s == 'rejected')
            ? 'Rejected'
            : (throw Exception('Decision failed: invalid status "$status"'));

    String? src = sourceHint?.trim().toLowerCase();
    src ??= _inferSource(item);
    if (src != 'attendance' && src != 'leaves') {
      throw Exception(
          'Decision failed: could not determine source (attendance/leaves)');
    }

    final payload = <String, dynamic>{
      'status': normalizedStatus,
      'source': src,
      if (remarks != null && remarks.trim().isNotEmpty)
        'remarks': remarks.trim(),
    };

    final genericId =
        (item['id'] ?? item['docId'] ?? item['requestId'])?.toString();
    if (genericId != null && genericId.isNotEmpty) payload['id'] = genericId;

    if (src == 'attendance') {
      final attendanceId = (item['attendanceId'] ?? item['attId'])?.toString();
      final empid =
          (item['empid'] ?? item['empId'] ?? item['employeeId'])?.toString();
      final rawDate =
          (item['requestDate'] ?? item['date'] ?? item['onDate'])?.toString();
      String? normDate;
      if (rawDate != null && rawDate.isNotEmpty) {
        normDate = rawDate.length >= 10 ? rawDate.substring(0, 10) : rawDate;
      }

      if (attendanceId != null && attendanceId.isNotEmpty) {
        payload['attendanceId'] = attendanceId;
      } else if ((empid != null && empid.isNotEmpty) &&
          (normDate != null && normDate.isNotEmpty)) {
        payload['empid'] = empid;
        payload['date'] = normDate;
      }
    } else {
      final leaveId = (item['leaveId'] ??
              item['leave_id'] ??
              item['requestId'] ??
              item['id'])
          ?.toString();
      if (leaveId == null || leaveId.isEmpty) {
        throw Exception('Decision failed: leaveId required');
      }
      payload['leaveId'] = leaveId;
    }

    final res = await _postWithFallback(
      _approvalsPaths.map((p) => '$p/decision').toList(),
      body: jsonEncode(payload),
    );
    if (!_ok(res)) {
      throw Exception('Decision failed (${res.statusCode}): ${res.body}');
    }
  }

  static Future<void> decideOtherLocation({
    required String id,
    required String status,
    String? remarks,
  }) async {
    final s = status.trim().toLowerCase();
    final normalizedStatus = (s == 'approve' || s == 'approved')
        ? 'Approved'
        : (s == 'reject' || s == 'rejected')
            ? 'Rejected'
            : (throw Exception('Decision failed: invalid status "$status"'));

    final first = await _safePost(
      Uri.parse('$apiBase$_otherLocDecisionPath'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'id': id,
        'status': normalizedStatus,
        if (remarks != null && remarks.trim().isNotEmpty)
          'remarks': remarks.trim(),
      }),
    );
    if (_ok(first)) return;

    if (_is404(first)) {
      await decideApproval(
        item: {'id': id, 'source': 'attendance'},
        status: normalizedStatus,
        remarks: remarks,
        sourceHint: 'attendance',
      );
      return;
    }

    throw Exception('Decision failed (${first.statusCode}): ${first.body}');
  }

  // ================== USER ==================
  static Future<List<Map<String, dynamic>>> fetchMyRequests({
    required DateTime from,
    required DateTime to,
    String status = 'All',
  }) async {
    final qp = <String, String>{
      'start': _ymd(from),
      'end': _ymd(to),
      if (_normStatus(status) != null) 'status': _normStatus(status)!,
    };
    final uri =
        Uri.parse('$apiBase$_myRequestsPath').replace(queryParameters: qp);
    final res = await _safeGet(uri, headers: await _authHeaders());
    if (!_ok(res)) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final body = json.decode(res.body);
    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (body is Map && body['items'] is List) {
      return (body['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  // NEW: request details (attendance + otherLocation)
  static Future<Map<String, dynamic>> fetchRequestDetails({
    String? id,
    String? src, // 'attendance' | 'other_location'
    String? empid,
    String? date, // 'YYYY-MM-DD'
  }) async {
    final headers = await _authHeaders();
    final qp = <String, String>{
      if (id != null && id.isNotEmpty) 'id': id,
      if (src != null && src.isNotEmpty) 'src': src,
      if (empid != null && empid.isNotEmpty) 'empid': empid,
      if (date != null && date.isNotEmpty) 'date': date,
    };
    final uri = Uri.parse('$apiBase/attendance/request-details')
        .replace(queryParameters: qp);

    final res = await _safeGet(uri, headers: headers);

    if (res.statusCode == 404) {
      return <String, dynamic>{};
    }

    if (_ok(res)) {
      final body = json.decode(res.body);
      return (body is Map)
          ? Map<String, dynamic>.from(body)
          : <String, dynamic>{};
    }
    throw Exception('details ${res.statusCode}: ${res.body}');
  }

  // Legacy
  static Future<void> decideAttendance({
    required String requestId,
    required String empid,
    required String date,
    required String status,
    String? remarks,
  }) async {
    await decideApproval(
      item: {'id': requestId, 'empid': empid, 'requestDate': date},
      status: status,
      remarks: remarks,
      sourceHint: 'attendance',
    );
  }

  // ================== LIVE EMPLOYEE DETAILS ==================
  static Future<Map<String, dynamic>> fetchLiveEmployeeDetails({
    required String empid,
    required String dateIso, // YYYY-MM-DD
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$apiBase/liveEmployeeDetails/$empid')
        .replace(queryParameters: {'dateIso': dateIso});

    final res = await _safeGet(uri, headers: headers);
    if (!_ok(res)) {
      throw Exception('liveEmployeeDetails ${res.statusCode}: ${res.body}');
    }

    final body = json.decode(res.body);
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data']);
    }
    return <String, dynamic>{};
  }

  // ================== TRACKING (for path on map) ==================
  static Future<Map<String, dynamic>> fetchTrackingDay({
    required String empid,
    required String dateIso, // YYYY-MM-DD
  }) async {
    final headers = await _authHeaders();
    // controller accepts empid in token/header/query/body — we pass header
    final allHeaders = {
      ...headers,
      'x-empid': empid,
    };

    final uri = Uri.parse('$apiBase/tracking/day')
        .replace(queryParameters: {'dateIso': dateIso});
    final res = await _safeGet(uri, headers: allHeaders);
    if (!_ok(res)) {
      throw Exception('tracking/day ${res.statusCode}: ${res.body}');
    }
    final body = json.decode(res.body);
    if (body is Map && body['data'] is Map) {
      return Map<String, dynamic>.from(body['data']);
    }
    return <String, dynamic>{};
  }
}
