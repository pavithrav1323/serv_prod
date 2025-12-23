class EventModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime fromDate;
  final DateTime toDate;
  final String? imageUrl;
  final String? fileUrl;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.fromDate,
    required this.toDate,
    this.imageUrl,
    this.fileUrl,
  });

  factory EventModel.fromJson(Map<String, dynamic> j) {
    DateTime parse(String? s) =>
        (s == null || s.isEmpty) ? DateTime.now() : DateTime.parse(s);
    return EventModel(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      location: (j['location'] ?? '').toString(),
      fromDate: parse(j['fromDate']?.toString()),
      toDate: parse(j['toDate']?.toString()),
      imageUrl: j['imageUrl']?.toString(),
      fileUrl: j['fileUrl']?.toString(),
    );
  }

  Map<String, dynamic> toCsvMap() => {
        'Event Name': title,
        'From Date': fromDate.toIso8601String().split('T').first,
        'To Date': toDate.toIso8601String().split('T').first,
        'Location': location,
        'Image': (imageUrl ?? '').isNotEmpty ? 'Yes' : 'No',
        'Description': description,
      };
}

// Global cache for list page
List<EventModel> eventsList = [];
