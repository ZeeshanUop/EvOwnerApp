import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../Model/Connector_info_Model.dart';
import '../../../Model/chargingstation_model.dart';
import '../../../core/constant.dart';

class NearbyStationsScreen extends StatefulWidget {
  const NearbyStationsScreen({super.key});

  @override
  State<NearbyStationsScreen> createState() => _NearbyStationsScreenState();
}

class _NearbyStationsScreenState extends State<NearbyStationsScreen> {
  Position? _currentPosition;

  Future<double?> getRoadDistanceInKm(
      double originLat, double originLng, double destLat, double destLng) async {
    final apiKey = ApiKeys.googleMaps;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=$originLat,$originLng'
          '&destinations=$destLat,$destLng'
          '&mode=driving'
          '&units=metric'
          '&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rows = data['rows'];
        if (rows != null &&
            rows.isNotEmpty &&
            rows[0]['elements'] != null &&
            rows[0]['elements'].isNotEmpty &&
            rows[0]['elements'][0]['status'] == 'OK') {
          final meters = rows[0]['elements'][0]['distance']['value'];
          return meters / 1000.0;
        }
      } else {
        print('Distance Matrix API error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching road distance: $e');
    }
    return null;
  }

  // Dropdown filter state
  String selectedDistance = '< 20 km';
  final List<String> distanceOptions = ['< 5 km', '< 10 km', '< 20 km'];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _currentPosition = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nearby Stations"),
        backgroundColor: Colors.green.shade700,
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Distance filter dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text("Distance: ", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  value: selectedDistance,
                  items: distanceOptions.map((option) {
                    return DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDistance = value!;
                    });
                  },
                ),
              ],
            ),
          ),

          // Stream and station list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ev_stations').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || _currentPosition == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final futures = docs.map((doc) async {
                  final data = doc.data() as Map<String, dynamic>;
                  final lat = data['latitude'];
                  final lng = data['longitude'];

                  if (lat == null || lng == null) return null;

                  final roadDistance = await getRoadDistanceInKm(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                    lat,
                    lng,
                  );

                  if (roadDistance == null) return null;

                  return {
                    'doc': doc,
                    'data': data,
                    'distanceKm': roadDistance,
                  };
                }).toList();

                return FutureBuilder<List<Map<String, dynamic>?>>(
                  future: Future.wait(futures),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final validStations = snapshot.data!.whereType<Map<String, dynamic>>().toList();

                    final filtered = validStations.where((entry) {
                      final distance = entry['distanceKm'] as double;

                      switch (selectedDistance) {
                        case '< 5 km':
                          return distance < 5;
                        case '< 10 km':
                          return distance < 10;
                        case '< 20 km':
                          return distance < 20;
                        default:
                          return true;
                      }
                    }).toList();

                    if (filtered.isEmpty) {
                      return const Center(child: Text("No stations found in this range."));
                    }

                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: filtered.map((entry) {
                        final doc = entry['doc'] as DocumentSnapshot;
                        final data = entry['data'] as Map<String, dynamic>;
                        final distanceKm = entry['distanceKm'] as double;

                        final connectors = (data['connectors'] as List<dynamic>?)
                            ?.map((e) => ConnectorInfo.fromJson(Map<String, dynamic>.from(e)))
                            .toList() ??
                            [];

                        return ChargingCard(
                          stationId: doc.id,
                          name: data['name'] ?? '',
                          location: data['location'] ?? '',
                          rating: (data['rating'] ?? 0).toDouble(),
                          status: data['status'] ?? '',
                          imagePath: data['imageUrl'] ?? '',
                          connectors: connectors,
                          amenities: List<String>.from(data['amenities'] ?? []),
                          distance: '${distanceKm.toStringAsFixed(2)} km',
                          isImageLeft: true,
                          height: 182,
                          latitude: data['latitude'],
                          longitude: data['longitude'],
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),

        ],
      ),
    );
  }
}
