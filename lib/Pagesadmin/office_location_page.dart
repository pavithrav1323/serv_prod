import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// ADD THIS: token source used elsewhere in your app
import 'package:serv_app/models/company_data.dart';

const Color kPrimaryBackgroundTop = Color(0xFFFFFFFF);
const Color kPrimaryBackgroundBottom = Color(0xFFD1C4E9);
const Color kAppBarColor = Color(0xFF8c6eaf);
const Color kButtonColor = Color(0xFF655193);
const Color kTextColor = Colors.white;

// ===== Backend base =====
const String _apiBase = 'https://api-zmj7dqloiq-el.a.run.app/api';

class LocationModel {
  final String docId; // Firestore doc id
  final String branchName;
  final String address;
  final double radius;
  final LatLng latLng;

  LocationModel({
    required this.docId,
    required this.branchName,
    required this.address,
    required this.radius,
    required this.latLng,
  });
}

class OfficeLocationPage extends StatefulWidget {
  const OfficeLocationPage({super.key});

  @override
  State<OfficeLocationPage> createState() => _OfficeLocationPageState();
}

class _OfficeLocationPageState extends State<OfficeLocationPage> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  final List<LocationModel> _locations = [];

  bool _loading = false;

  LatLng _mapCenter = LatLng(20.5937, 78.9629); // India default
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadLocations(); // <-- fetch from DB on start
  }

  Map<String, String> _authHeaders({Map<String, String>? extra}) {
    final token = CompanyData.token;
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  // -------------------- Backend --------------------

  Future<void> _loadLocations() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/office/locations'),
        headers: _authHeaders(),
      );
      
      debugPrint('[Office] GET /office/locations -> ${res.statusCode} ${res.body}');
      
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body) as List;
        _locations.clear();
        
        for (var item in data) {
          try {
            final m = item as Map<String, dynamic>;
            debugPrint('Processing location item: $m');
            
            // Parse coordinates and radius with null checks
            final lat = (m['latitude'] as num?)?.toDouble() ?? 0.0;
            final lng = (m['longitude'] as num?)?.toDouble() ?? 0.0;
            final rad = (m['radius'] as num?)?.toDouble() ?? 100.0;
            
            // Get branch name with fallback to empty string
            final branchName = (m['branchName'] ?? m['name'] ?? m['branch'] ?? 'Unnamed Location').toString().trim();
            
            _locations.add(LocationModel(
              docId: (m['docId'] ?? m['id'] ?? '').toString(),
              branchName: branchName,
              address: (m['address'] ?? '').toString().trim(),
              radius: rad,
              latLng: LatLng(lat, lng),
            ));
            
            debugPrint('Added location: $branchName');
          } catch (e) {
            debugPrint('Error parsing location item: $e');
          }
        }

        // Center the map to the first location (if any)
        if (_locations.isNotEmpty) {
          _mapCenter = _locations.first.latLng;
          _mapController.move(_mapCenter, 12.0);
        } else {
          debugPrint('No locations found in the response');
        }
      } else {
        final error = jsonDecode(res.body)['message'] ?? 'Unknown error';
        _toast('Failed to load locations: $error');
      }
    } catch (e) {
      debugPrint('Error in _loadLocations: $e');
      _toast('Error loading locations: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _postLocation({
    required String branchName,
    required String address,
    required double radius,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final requestBody = {
        'branchName': branchName.trim(),
        'name': branchName.trim(), // For backward compatibility
        'address': address.trim(),
        'radius': radius,
        'latitude': latitude,
        'longitude': longitude,
      };
      
      debugPrint('[Office] Sending request: ${jsonEncode(requestBody)}');
      
      final res = await http.post(
        Uri.parse('$_apiBase/office/add'),
        headers: _authHeaders(),
        body: jsonEncode(requestBody),
      );
      
      debugPrint('[Office] POST /office/add -> ${res.statusCode} ${res.body}');
      
      if (res.statusCode == 201) {
        _toast('Location saved successfully');
        return true;
      } else {
        final errorMsg = jsonDecode(res.body)['message'] ?? 'Unknown error';
        _toast('Failed to save: $errorMsg');
        return false;
      }
    } catch (e) {
      debugPrint('Error in _postLocation: $e');
      _toast('Error: ${e.toString()}');
      return false;
    }
  }

  Future<bool> _deleteRemote(String docId) async {
    try {
      final res = await http.delete(
        Uri.parse('$_apiBase/office/delete/$docId'),
        headers: _authHeaders(),
      );
      debugPrint(
          '[Office] DELETE /office/delete/$docId -> ${res.statusCode} ${res.body}');
      if (res.statusCode == 200) return true;
      _toast('Delete failed (${res.statusCode})');
    } catch (e) {
      _toast('Delete error: $e');
    }
    return false;
  }

  // -------------------- Geolocation helpers --------------------

  Future<void> _getCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {}
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=$address&format=json&limit=1',
    );
    try {
      final response =
          await http.get(url, headers: {'User-Agent': 'FlutterApp'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat']),
            double.parse(data[0]['lon']),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // -------------------- UI actions --------------------

  void _addOrEditLocation({int? indexToEdit}) {
    final isEdit = indexToEdit != null;
    final branchController = TextEditingController(
      text: isEdit ? _locations[indexToEdit].branchName : '',
    );
    final addressController = TextEditingController(
      text: isEdit ? _locations[indexToEdit].address : _searchController.text,
    );
    final radiusController = TextEditingController(
      text: isEdit ? _locations[indexToEdit].radius.toString() : '',
    );
    final latController = TextEditingController(
      text: isEdit ? _locations[indexToEdit].latLng.latitude.toString() : '',
    );
    final lngController = TextEditingController(
      text: isEdit ? _locations[indexToEdit].latLng.longitude.toString() : '',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? 'Edit Location' : 'Add Office Branch'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: branchController,
                decoration:
                    const InputDecoration(labelText: 'Branch location name'),
                textCapitalization: TextCapitalization.words,
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              TextField(
                controller: radiusController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Radius (meters)'),
              ),
              TextField(
                controller: latController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Latitude (optional)'),
              ),
              TextField(
                controller: lngController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Longitude (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: kButtonColor, foregroundColor: kTextColor),
            onPressed: () async {
              final branch = branchController.text.trim();
              final address = addressController.text.trim();
              final radius = double.tryParse(radiusController.text) ?? 100.0;

              if (branch.isEmpty) {
                _toast('Please enter branch location name');
                return;
              }
              if (address.isEmpty) {
                _toast('Please enter address');
                return;
              }

              double? lat = double.tryParse(latController.text.trim());
              double? lng = double.tryParse(lngController.text.trim());
              LatLng? coords = (lat != null && lng != null)
                  ? LatLng(lat, lng)
                  : await _geocodeAddress(address);

              if (coords == null) {
                _toast('Could not determine location');
                return;
              }

              final ok = await _postLocation(
                branchName: branch,
                address: address,
                radius: radius,
                latitude: coords.latitude,
                longitude: coords.longitude,
              );
              if (ok) {
                if (mounted) Navigator.pop(context);
                await _loadLocations();
                _mapCenter = coords;
                _mapController.move(coords, 15.5);
                _searchController.clear();
              }
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLocation(int index) async {
    final docId = _locations[index].docId;
    final ok = await _deleteRemote(docId);
    if (ok) {
      await _loadLocations();
    }
  }

  void _openInMaps() async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${_mapCenter.latitude},${_mapCenter.longitude}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _toast('Could not launch Maps');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryBackgroundTop, kPrimaryBackgroundBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: kAppBarColor,
          title: const Text('Office Location',
              style: TextStyle(color: kTextColor)),
          leading: const BackButton(color: kTextColor),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _loadLocations,
              icon: const Icon(Icons.refresh, color: kTextColor),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add the offices or locations where your team members will be checking in and checkout',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.search),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration:
                            const InputDecoration(hintText: 'Search Location'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _addOrEditLocation,
                      icon: const Icon(Icons.add),
                      label: const Text('Add More'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kButtonColor,
                        foregroundColor: kTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _locations.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final loc = _locations[index];
                      return ListTile(
                        title: Text(
                          (loc.branchName.isNotEmpty
                              ? loc.branchName
                              : loc.address.split(',').first),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (loc.branchName.isNotEmpty) Text(loc.address),
                            Text('Radius: ${loc.radius.toStringAsFixed(0)}M'),
                          ],
                        ),
                        onTap: () {
                          _mapController.move(loc.latLng, 16.0);
                          setState(() => _mapCenter = loc.latLng);
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _addOrEditLocation(indexToEdit: index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteLocation(index),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 260,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          center: _mapCenter,
                          zoom: 6.0,
                          interactiveFlags: InteractiveFlag.all,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c'],
                          ),
                          MarkerLayer(
                            markers: [
                              if (_currentLocation != null)
                                Marker(
                                  point: _currentLocation!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.person_pin_circle,
                                      color: Colors.green, size: 40),
                                ),
                              ..._locations.map(
                                (loc) => Marker(
                                  point: loc.latLng,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.location_on,
                                      color: Colors.red, size: 40),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: ElevatedButton.icon(
                          onPressed: _openInMaps,
                          icon: const Icon(Icons.map),
                          label: const Text("Open in Maps"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: kAppBarColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
