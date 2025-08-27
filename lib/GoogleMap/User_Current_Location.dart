import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../core/constant.dart';

class StationMapScreen extends StatefulWidget {
  const StationMapScreen({super.key});

  @override
  State<StationMapScreen> createState() => _StationMapScreenState();
}

class _StationMapScreenState extends State<StationMapScreen> {
  GoogleMapController? mapController;
  LatLng? currentPosition;
  List<Marker> stationMarkers = [];
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeEverything();
  }

  Future<void> _initializeEverything() async {
    await _getCurrentLocation();
    await _loadStationMarkers();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        currentPosition = LatLng(position.latitude, position.longitude);
      });
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(currentPosition!, 14),
      );
    } catch (e) {
      debugPrint("Error getting current location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get current location')),
      );
    }
  }

  Future<void> _loadStationMarkers() async {
    final snapshot = await FirebaseFirestore.instance.collection('ev_stations').get();
    final List<Marker> markers = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();

      // Parse lat/lng safely
      final latRaw = data['latitude'];
      final lngRaw = data['longitude'];
      final lat = latRaw is num ? latRaw.toDouble() : double.tryParse(latRaw.toString()) ?? 0;
      final lng = lngRaw is num ? lngRaw.toDouble() : double.tryParse(lngRaw.toString()) ?? 0;

      if (lat == 0 || lng == 0) continue;

      final slots = data['points'] ?? 0;
      final available = data['availablePoints'] ?? slots;

      markers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: data['name'] ?? 'Unnamed Station',
            snippet: '${data['city']} • $available/$slots slots\nTap to view details',
            onTap: () => _showStationDetails(doc.id, data),
          ),
        ),
      );
    }

    setState(() {
      stationMarkers = markers;
    });
  }

  void _showStationDetails(String id, Map<String, dynamic> data) {
    if (currentPosition == null) return;

    final latRaw = data['latitude'];
    final lngRaw = data['longitude'];
    final lat = latRaw is num ? latRaw.toDouble() : double.tryParse(latRaw.toString()) ?? 0;
    final lng = lngRaw is num ? lngRaw.toDouble() : double.tryParse(lngRaw.toString()) ?? 0;

    final distanceMeters = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      lat,
      lng,
    );

    final formattedDistance = distanceMeters.isNaN
        ? 'Unknown'
        : '${(distanceMeters / 1000).toStringAsFixed(2)} km';

    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 230,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['name'] ?? 'Unnamed Station',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(data['location'] ?? 'No address available'),
              const SizedBox(height: 4),
              Text('Slots: ${data['availablePoints'] ?? '-'} / ${data['points'] ?? '-'}'),
              const SizedBox(height: 4),
              Text('Distance: $formattedDistance'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  _drawRouteToStation(
                    currentPosition!,
                    LatLng(lat, lng),
                  );
                  Navigator.pop(context); // Close the bottom sheet
                },
                icon: const Icon(Icons.directions),
                label: const Text("Get Directions"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _drawRouteToStation(LatLng origin, LatLng destination) async {
    final apiKey = ApiKeys.googleMaps;

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final encodedPoints = data['routes'][0]['overview_polyline']['points'];
      final points = _decodePolyline(encodedPoints);

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId("route"),
            points: points,
            color: Colors.blue,
            width: 5,
          )
        };
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to fetch directions")),
      );
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return polyline;
  }

  Future<void> _goToCurrentLocation() async {
    await _getCurrentLocation();
    if (currentPosition != null) {
      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: currentPosition!, zoom: 14),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stations Map')),
      body: currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
        initialCameraPosition:
        CameraPosition(target: currentPosition!, zoom: 12),
        markers: Set.from(stationMarkers),
        polylines: _polylines,
        myLocationEnabled: true,
        onMapCreated: (ctrl) => mapController = ctrl,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
