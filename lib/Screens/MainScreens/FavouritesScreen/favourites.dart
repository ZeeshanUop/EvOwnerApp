import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../Provider/FavouriteProvider.dart';
import '../../../Model/Connector_info_Model.dart';
import '../StationDetailScreen/Charging_station_info.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Position _userPosition;
  bool _loading = true;
  List<Map<String, dynamic>> _favoriteStations = [];
  final String _googleApiKey = 'AIzaSyD-p_PCcAP6MUJSjkizdxi4vy7Jh5A1JBE'; // Replace with your Distance Matrix API key

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      _userPosition = await Geolocator.getCurrentPosition();
      final favoriteProvider = Provider.of<FavoriteProvider>(context, listen: false);
      final favoriteIds = favoriteProvider.favorites;

      final snapshot = await FirebaseFirestore.instance.collection('ev_stations').get();
      final allDocs = snapshot.docs.where((doc) => favoriteIds.contains(doc.id)).toList();

      List<Map<String, dynamic>> stationsWithDistance = [];
      for (var doc in allDocs) {
        final data = doc.data();
        final lat = (data['latitude'] ?? 0.0).toDouble();
        final lng = (data['longitude'] ?? 0.0).toDouble();

        final distance = await _getDrivingDistance(
          _userPosition.latitude,
          _userPosition.longitude,
          lat,
          lng,
        );

        stationsWithDistance.add({
          'id': doc.id,
          'data': data,
          'distance': distance,
        });
      }

      stationsWithDistance.sort(
            (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      if (!mounted) return; // ✅ avoid setState after dispose

      setState(() {
        _favoriteStations = stationsWithDistance;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error loading favorites: $e");
      if (!mounted) return; // ✅ safe guard
      setState(() => _loading = false);
    }
  }

  // Use Google Distance Matrix API to get driving distance in km
  Future<double> _getDrivingDistance(double originLat, double originLng, double destLat, double destLng) async {
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json?origins=$originLat,$originLng&destinations=$destLat,$destLng&mode=driving&units=metric&key=$_googleApiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final distanceMeters = data['rows'][0]['elements'][0]['distance']['value'];
        return distanceMeters / 1000;
      }
    } catch (e) {
      debugPrint("Distance Matrix API error: $e");
    }
    return double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          elevation: 4,
          automaticallyImplyLeading: false, // removes default back button
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
          ),
          flexibleSpace: Container(
            padding: const EdgeInsets.only(left: 20),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade900],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text(
              "Favorite Charging Stations",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favoriteStations.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.heart_broken, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text("Your favorites list is empty", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            const Text("You’ll see updates about your favorite stations here",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _favoriteStations.length,
        itemBuilder: (context, index) {
          final station = _favoriteStations[index];
          final data = station['data'];
          final distance = station['distance'] as double;
          final docId = station['id'];

          final connectors = (data['connectors'] as List<dynamic>?)
              ?.map((e) => ConnectorInfo.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
              [];

          final stationName = data['name'] ?? 'Unknown';
          final location = data['location'] ?? '';
          final rating = (data['rating'] ?? 0).toDouble();
          final status = (data['status'] ?? 'closed').toString().toLowerCase() == 'open';
          final imageUrl = data['imageUrl'] ?? '';
          final availableSlots = connectors.fold<int>(0, (sum, c) => sum + (c.availableSlots ?? 0));
          final lat = (data['latitude'] ?? 0.0).toDouble();
          final lng = (data['longitude'] ?? 0.0).toDouble();

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ChargingStationDetailScreen(stationId: docId)),
                );
              },
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
                        child: Image.network(
                          imageUrl,
                          width: 120,
                          height: 150,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 120,
                            height: 150,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stationName,
                                      style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    status ? Icons.check_circle : Icons.cancel,
                                    color: status ? Colors.green : Colors.red,
                                    size: 18,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                location,
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                                  const SizedBox(width: 4),
                                  Text(rating.toStringAsFixed(1)),
                                  const SizedBox(width: 8),
                                  Text("• $availableSlots points",
                                      style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("${distance.toStringAsFixed(1)} km",
                                      style: const TextStyle(fontWeight: FontWeight.w500)),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final googleUrl =
                                          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
                                      if (await canLaunchUrl(Uri.parse(googleUrl))) {
                                        await launchUrl(Uri.parse(googleUrl));
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text("Direction", style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
