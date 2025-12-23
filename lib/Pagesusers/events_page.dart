import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==== Colors ====
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;


// ------- API base (must match your backend) -------
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';
// To resolve /uploads/... into a full URL
final String _apiOrigin = apiBase.replaceFirst(RegExp(r'/api/?$'), '');

class UserEventUpdatesPage extends StatefulWidget {
  const UserEventUpdatesPage({super.key});

  @override
  State<UserEventUpdatesPage> createState() => _UserEventUpdatesPageState();
}

class _UserEventUpdatesPageState extends State<UserEventUpdatesPage> {
  late Future<List<Map<String, String>>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = fetchEventData();
  }

  // Make '/uploads/abc.jpg' -> '<origin>/uploads/abc.jpg'
  String _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$_apiOrigin$url';
    return '$_apiOrigin/$url';
  }

  // Format 'YYYY-MM-DD' -> 'dd/MM'
  String _fmtDate(String? d) {
    if (d == null || d.isEmpty) return '';
    final parts = d.split('T').first.split('-'); // [yyyy, mm, dd]
    if (parts.length != 3) return d;
    return '${parts[2]}/${parts[1]}';
  }

  Future<List<Map<String, String>>> fetchEventData() async {
    try {
      final res = await http.get(Uri.parse('$apiBase/events'));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final List<dynamic> data = jsonDecode(res.body);

      // Map backend fields to UI keys (image kept but not rendered)
      return data.map<Map<String, String>>((e) {
        final title = (e['title'] ?? '').toString();
        final location = (e['location'] ?? '').toString();
        final desc = (e['description'] ?? '').toString();
        final fromDateStr = (e['fromDate'] ?? '').toString();
        final toDateStr = (e['toDate'] ?? '').toString();
        final imageUrl = _resolveUrl((e['imageUrl'] ?? '').toString());

        return {
          'event': title,
          'from': _fmtDate(fromDateStr),
          'to': _fmtDate(toDateStr),
          'location': location,
          'image': imageUrl, // not rendered
          'desc': desc,
        };
      }).toList();
    } catch (e) {
      throw Exception('Error fetching events: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Event Updates'),
        backgroundColor: const Color(0xFF8C6EAF),
      ),
      // ✅ Apply the same gradient as Rewards page
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFD1C4E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: FutureBuilder<List<Map<String, String>>>(
          future: _eventsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No events found.'));
            }

            final events = snapshot.data!;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Image column removed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: kButtonColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                            "Event Name",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            "From",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            "To",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            "Location",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        // Image column removed
                        SizedBox(
                          width: 220, // widened since Image column is gone
                          child: Text(
                            "Description",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Rows (Image cell removed)
                  ...events.map((event) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 2),
                        ],
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 130,
                            child: Text(event['event'] ?? ''),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(event['from'] ?? ''),
                          ),
                          SizedBox(
                            width: 90,
                            child: Text(event['to'] ?? ''),
                          ),
                          SizedBox(
                            width: 110,
                            child: Text(event['location'] ?? ''),
                          ),
                          // Image widget removed
                          SizedBox(
                            width: 220,
                            child: Text(event['desc'] ?? ''),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
