import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../../../GoogleMap/Location_Picker_Screen.dart';
import '../../../GoogleMap/Station_location.dart';
import '../../../core/constant.dart';

final apiKey = ApiKeys.googleMaps;

class EnrouteChargingScreen extends StatefulWidget {
  @override
  State<EnrouteChargingScreen> createState() => _EnrouteChargingScreenState();
}

class _EnrouteChargingScreenState extends State<EnrouteChargingScreen> {
  LatLng? startLatLng;
  LatLng? endLatLng;
  String? startAddress;
  String? endAddress;

  List<LatLng> polylinePoints = [];

  // Pick location from MapPickerScreen
  Future<void> _pickLocation(bool isStart) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (result != null && result is Map<String, dynamic>) {
      LatLng picked = result['latLng'];
      String address = result['address'] ?? "Unknown";
      setState(() {
        if (isStart) {
          startLatLng = picked;
          startAddress = address;
        } else {
          endLatLng = picked;
          endAddress = address;
        }
      });
    }
  }

  // Get current location
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        throw "Location services disabled";
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Location permission denied";
      }
      if (permission == LocationPermission.deniedForever) throw "Location permission permanently denied";

      Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        startLatLng = LatLng(pos.latitude, pos.longitude);
        startAddress = "Current Location";
      });
    } catch (e) {
      print("❌ Current location error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to get current location")));
    }
  }

  // Fetch polyline from Google Directions API
// Fetch polyline from Google Directions API

// Show stations on map
  // Fetch polyline from Google Directions API
// Decode polyline
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

// Fetch polyline from Google Directions API
  Future<bool> _fetchPolyline() async {
    if (startLatLng == null || endLatLng == null) return false;

    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${startLatLng!.latitude},${startLatLng!.longitude}&destination=${endLatLng!.latitude},${endLatLng!.longitude}&key=$apiKey';

    try {
      print('🔗 Fetching Directions API URL: $url');
      final response = await http.get(Uri.parse(url));
      final data = jsonDecode(response.body);
      print('📝 Directions API response: $data');

      if (data['status'] == 'OK' &&
          data['routes'] != null &&
          data['routes'].isNotEmpty) {
        final steps = data['routes'][0]['overview_polyline']?['points'];
        if (steps != null) {
          polylinePoints = decodePolyline(steps);
          print('✅ Polyline loaded: ${polylinePoints.length} points');
          return true;
        }
      }
      print("Google Maps API Key: $apiKey"); // should print your key

      print('❌ Directions API returned no route or invalid response.');
      return false;
    } catch (e) {
      print('❌ Directions API exception: $e');
      return false;
    }
  }

// Show stations on map
  Future<void> _showStationsOnMap() async {
    try {
      if (startLatLng == null) await _getCurrentLocation();
      if (endLatLng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pick destination")));
        return;
      }

      bool routeFetched = await _fetchPolyline();
      if (!routeFetched) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to fetch route. Showing nearby stations only.")));
      }

      double threshold = routeFetched ? _computeDynamicThreshold() : 5.0;

      final stations =
      await FirebaseFirestore.instance.collection('ev_stations').get();
      List<Map<String, dynamic>> matchedStations = [];

      for (var doc in stations.docs) {
        final data = doc.data();
        if (data['latitude'] == null || data['longitude'] == null) continue;

        final LatLng stationPos = LatLng(
          double.parse(data['latitude'].toString()),
          double.parse(data['longitude'].toString()),
        );

        double distanceToRoute =
        routeFetched ? _distanceToPolyline(stationPos) : Geolocator.distanceBetween(
          startLatLng!.latitude,
          startLatLng!.longitude,
          stationPos.latitude,
          stationPos.longitude,
        ) / 1000.0;

        if (distanceToRoute <= threshold) {
          matchedStations.add({
            'stationId': doc.id,
            'name': data['name'],
            'location': data['location'],
            'latitude': data['latitude'],
            'longitude': data['longitude'],
            'bookedSlots': data['connectors']?[0]?['bookedSlots'] ?? 0,
            'totalSlots': data['connectors']?[0]?['totalSlots'] ?? 0,
            'status': data['status'],
            'imageUrl': data['imageUrl'],
            'connectors': data['connectors'],
            'amenities': data['amenities'],
          });
        }
      }

      print("✅ Found ${matchedStations.length} stations to display");
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChargerMapScreen(
            polylinePoints: polylinePoints,
            stationData: matchedStations,
          ),
        ),
      );
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching stations: $e")));
    }
  }

  // Geodesic distance from point to polyline
  double _distanceToLineSegment(LatLng a, LatLng b, LatLng p) {
    double dist13 = Geolocator.distanceBetween(a.latitude, a.longitude, p.latitude, p.longitude);
    double dist12 = Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
    double dist23 = Geolocator.distanceBetween(b.latitude, b.longitude, p.latitude, p.longitude);

    double cosA = (dist12 * dist12 + dist13 * dist13 - dist23 * dist23) / (2 * dist12 * dist13);
    if (cosA < 0) return dist13 / 1000.0;

    double cosB = (dist12 * dist12 + dist23 * dist23 - dist13 * dist13) / (2 * dist12 * dist23);
    if (cosB < 0) return dist23 / 1000.0;

    double s = (dist12 + dist13 + dist23) / 2;
    double area = sqrt(s * (s - dist12) * (s - dist13) * (s - dist23));
    double height = (2 * area) / dist12;
    return height / 1000.0;
  }

  double _distanceToPolyline(LatLng point) {
    double minDistance = double.infinity;
    for (int i = 0; i < polylinePoints.length - 1; i++) {
      double d = _distanceToLineSegment(polylinePoints[i], polylinePoints[i + 1], point);
      if (d < minDistance) minDistance = d;
    }
    return minDistance;
  }

  // Compute route length
  double _computeRouteLength() {
    double total = 0.0;
    for (int i = 0; i < polylinePoints.length - 1; i++) {
      total += Geolocator.distanceBetween(
        polylinePoints[i].latitude,
        polylinePoints[i].longitude,
        polylinePoints[i + 1].latitude,
        polylinePoints[i + 1].longitude,
      );
    }
    return total / 1000.0;
  }

  // Dynamic threshold
  double _computeDynamicThreshold() {
    double len = _computeRouteLength();
    if (len < 10) return 2.0;
    if (len < 50) return 5.0;
    return 10.0;
  }

  // Show stations

  Widget mapCard(String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF25633C)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 260,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(image: AssetImage("Assets/12.jpg"), fit: BoxFit.cover),
                ),
              ),
              Container(height: 260, width: double.infinity, color: Colors.black.withOpacity(0.4)),
              const Positioned(
                left: 16,
                bottom: 16,
                child: Text(
                  'Enroute charging station',
                  style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: const Text(
              'Pick starting point & destination to see charging stations along the route.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  mapCard(
                    "Pick starting point",
                    startAddress ?? "Please pick starting point in Google Map",
                        () => _pickLocation(true),
                  ),
                  mapCard(
                    "Pick destination point",
                    endAddress ?? "Please pick destination point in Google Map",
                        () => _pickLocation(false),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _showStationsOnMap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25633C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text("See enroute charging stations", style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
