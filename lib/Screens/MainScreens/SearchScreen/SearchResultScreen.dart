import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';// your model for station if needed
import 'package:fyp_project/Model/Connector_info_Model.dart'; // adjust path
import 'package:geolocator/geolocator.dart';

import '../../../Model/chargingstation_model.dart';

class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;

  const SearchResultsScreen({required this.searchQuery, super.key});

  @override
  _SearchResultsScreenState createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print("Location error: $e");
    }
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Results for "${widget.searchQuery}"'),
      ),
      body: _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ev_stations')
            .where('status', isEqualTo: 'Open')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          final matchingStations = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toString().toLowerCase();
            final location =
            (data['location'] ?? '').toString().toLowerCase();
            return name.contains(widget.searchQuery.toLowerCase()) ||
                location.contains(widget.searchQuery.toLowerCase());
          }).toList();

          if (matchingStations.isEmpty) {
            return const Center(child: Text("No matching stations found."));
          }

          return ListView(
            children: matchingStations.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final double distance = calculateDistance(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  data['latitude'],
                  data['longitude']);

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: ChargingCard(
                  stationId: doc.id,
                  name: data['name'] ?? 'Unnamed Station',
                  location: data['location'] ?? 'Unknown Location',
                  rating: (data['rating'] ?? 0).toDouble(),
                  status: data['status'] ?? 'Unknown',
                  imagePath: data['imageUrl'] ?? '',
                  distance: '${distance.toStringAsFixed(2)} km',
                  connectors: (data['connectors'] as List<dynamic>?)
                      ?.map((e) => ConnectorInfo.fromJson(
                      Map<String, dynamic>.from(e)))
                      .toList() ??
                      [],
                  amenities: List<String>.from(data['amenities'] ?? []),
                  latitude: data['latitude'],
                  longitude: data['longitude'],
                  isImageLeft: true,
                  width: double.infinity,
                  height: 185,
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
