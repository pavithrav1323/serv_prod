import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:serv_app/html_stub.dart'
    if (dart.library.html) 'package:serv_app/html_web.dart'
    as html; // Web-only APIs (fine for Flutter Web builds)

import 'event_model_page.dart';
import 'add_event_page.dart';

// ====== CONFIG ======
const String apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';
// Derive the origin (no /api) so we can resolve /uploads/...
final String _apiOrigin = apiBase.replaceFirst(RegExp(r'/api/?$'), '');

// ====== THEME ======
const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8C6EAF);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

class EventUpdatesPage extends StatefulWidget {
  const EventUpdatesPage({super.key});
  @override
  State<EventUpdatesPage> createState() => _EventUpdatesPageState();
}

class _EventUpdatesPageState extends State<EventUpdatesPage> {
  List<EventModel> _filtered = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------- Networking ----------
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(Uri.parse('$apiBase/events'));
      if (r.statusCode == 200) {
        final List data = jsonDecode(r.body);
        eventsList = data.map((e) => EventModel.fromJson(e)).toList();
        setState(() => _filtered = List.of(eventsList));
      } else {
        _toast('Load failed: ${r.statusCode}');
      }
    } catch (e) {
      _toast('Load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      final r = await http.delete(Uri.parse('$apiBase/events/$id'));
      if (r.statusCode == 200) {
        _toast('Deleted');
        await _load();
      } else {
        _toast('Delete failed: ${r.statusCode}');
      }
    } catch (e) {
      _toast('Delete error: $e');
    }
  }

  // ---------- Helpers ----------
  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // Turn '/uploads/abc.jpg' into 'http://localhost:3000/uploads/abc.jpg'
  String _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$_apiOrigin$url';
    return '$_apiOrigin/$url';
  }

  // Show an in-app preview dialog for the image
  void _showImagePreview(String? url) {
    final link = _resolveUrl(url);
    if (link.isEmpty) {
      _toast('No image available');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Stack(
          children: [
            // Zoom/pan
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Center(
                child: Image.network(
                  link,
                  fit: BoxFit.contain,
                  // Progress indicator while loading
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 420,
                      width: 560,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  // Friendly error UI
                  errorBuilder: (ctx, err, stack) => SizedBox(
                    height: 420,
                    width: 560,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'Could not load image',
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            link,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBackgroundBottom,
      appBar: AppBar(
        backgroundColor: kAppBarColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Event Updates', style: TextStyle(color: kTextColor)),
        actions: [
          IconButton(
              icon: const Icon(Icons.search, color: kTextColor),
              onPressed: _search),
          IconButton(
              icon: const Icon(Icons.refresh, color: kTextColor),
              onPressed: _load),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _downloadCsv,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kButtonColor,
                      foregroundColor: kTextColor),
                  icon: const Icon(Icons.download),
                  label: const Text("Download"),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EventUploadPage()));
                    await _load();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kButtonColor,
                      foregroundColor: kTextColor),
                  icon: const Icon(Icons.add),
                  label: const Text("Add"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: 980,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                color:
                                    kPrimaryBackgroundBottom.withOpacity(0.5),
                                child: Row(
                                  children: const [
                                    _HeaderCell('Event Name', width: 160),
                                    _HeaderCell('From Date', width: 120),
                                    _HeaderCell('To Date', width: 120),
                                    _HeaderCell('Location', width: 150),
                                    _HeaderCell('Image', width: 100),
                                    _HeaderCell('Description', width: 260),
                                    _HeaderCell('Delete', width: 60),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: _filtered.isEmpty
                                    ? const Center(child: Text('No data'))
                                    : ListView.builder(
                                        itemCount: _filtered.length,
                                        itemBuilder: (_, i) {
                                          final e = _filtered[i];
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 10),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                  bottom: BorderSide(
                                                      color: Colors
                                                          .grey.shade300)),
                                            ),
                                            child: Row(
                                              children: [
                                                _BodyCell(e.title, width: 160),
                                                _BodyCell(
                                                  e.fromDate
                                                      .toIso8601String()
                                                      .split('T')
                                                      .first,
                                                  width: 120,
                                                ),
                                                _BodyCell(
                                                  e.toDate
                                                      .toIso8601String()
                                                      .split('T')
                                                      .first,
                                                  width: 120,
                                                ),
                                                _BodyCell(e.location,
                                                    width: 150),

                                                // ====== VIEW BUTTON (in-app preview) ======
                                                SizedBox(
                                                  width: 100,
                                                  child: (e.imageUrl ?? '')
                                                          .isEmpty
                                                      ? const Text('—',
                                                          textAlign:
                                                              TextAlign.center)
                                                      : TextButton(
                                                          onPressed: () =>
                                                              _showImagePreview(
                                                                  e.imageUrl),
                                                          child: const Text(
                                                              'View'),
                                                        ),
                                                ),

                                                _BodyCell(e.description,
                                                    width: 260),
                                                SizedBox(
                                                  width: 60,
                                                  child: IconButton(
                                                    icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.red),
                                                    onPressed: () =>
                                                        _delete(e.id),
                                                  ),
                                                ),
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
            ),
          ],
        ),
      ),
    );
  }

  void _search() {
    String q = '';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search Events'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => q = v,
          decoration: const InputDecoration(hintText: 'Event title'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filtered = eventsList
                    .where(
                        (e) => e.title.toLowerCase().contains(q.toLowerCase()))
                    .toList();
              });
              Navigator.of(context).pop();
            },
            child: const Text('Search'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _filtered = List.of(eventsList));
              Navigator.of(context).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _downloadCsv() {
    if (!kIsWeb) {
      _toast('CSV download is supported on Web only.');
      return;
    }

    final b = StringBuffer()
      ..writeln('Event Name,From Date,To Date,Location,Image,Description');

    for (final e in _filtered) {
      b.writeln('${e.title},'
          '${e.fromDate.toIso8601String().split('T').first},'
          '${e.toDate.toIso8601String().split('T').first},'
          '${e.location},'
          '${(e.imageUrl ?? '').isNotEmpty ? 'Yes' : 'No'},'
          '${e.description.replaceAll(',', ' ')}');
    }

    final bytes = utf8.encode(b.toString());
    final blob = html.Blob([bytes], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = 'event_updates.csv'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;
  const _HeaderCell(this.label, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String text;
  final double width;
  const _BodyCell(this.text, {required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(text, overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }
}