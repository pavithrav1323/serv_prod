import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapSmokeTest extends StatelessWidget {
  const MapSmokeTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(13.047789, 80.090998),
            zoom: 12,
          ),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
      ),
    );
  }
}
