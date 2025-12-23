import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Only available on Flutter Web; harmless try/catch elsewhere
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart' as html;

/// Change only this if your API base moves.
const String kApiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class ShiftModel {
  final String id;
  final String name; // UI "Shift Name"
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"
  final String shiftname; // Group / Shift Group display name

  ShiftModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.shiftname,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> m) => ShiftModel(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        startTime: (m['startTime'] ?? '').toString(),
        endTime: (m['endTime'] ?? '').toString(),
        shiftname: (m['shiftname'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime,
        'endTime': endTime,
        'shiftname': shiftname,
      };
}

class ShiftApi {
  static Future<String?> _token() async {
    try {
      final t = html.window.localStorage['token'];
      if (t != null && t.isNotEmpty) return t;
    } catch (_) {}
    final sp = await SharedPreferences.getInstance();
    final t2 = sp.getString('token');
    return (t2 != null && t2.isNotEmpty) ? t2 : null;
  }

  static Future<List<ShiftModel>> getAll() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final t = await _token();
    if (t != null) headers['Authorization'] = 'Bearer $t';

    final uri = Uri.parse('$kApiBase/shifts');
    final res = await http.get(uri, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Fetch shifts failed: ${res.statusCode} ${res.body}');
    }
    final list = (jsonDecode(res.body) as List).cast<dynamic>();
    return list
        .map((e) => ShiftModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<ShiftModel> create({
    required String name,
    required String startTimeHHmm,
    required String endTimeHHmm,
    required String shiftGroupName,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final t = await _token();
    if (t != null) headers['Authorization'] = 'Bearer $t';

    final uri = Uri.parse('$kApiBase/shifts');
    final body = jsonEncode({
      'name': name,
      'startTime': startTimeHHmm,
      'endTime': endTimeHHmm,
      'shiftname': shiftGroupName,
    });

    final res = await http.post(uri, headers: headers, body: body);
    if (res.statusCode != 201) {
      throw Exception('Create shift failed: ${res.statusCode} ${res.body}');
    }
    final m = jsonDecode(res.body) as Map<String, dynamic>;
    return ShiftModel.fromJson(m);
  }

  static Future<void> deleteById(String id) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final t = await _token();
    if (t != null) headers['Authorization'] = 'Bearer $t';

    final uri = Uri.parse('$kApiBase/shifts/$id');
    final res = await http.delete(uri, headers: headers);
    if (res.statusCode != 200) {
      throw Exception('Delete shift failed: ${res.statusCode} ${res.body}');
    }
  }
}
