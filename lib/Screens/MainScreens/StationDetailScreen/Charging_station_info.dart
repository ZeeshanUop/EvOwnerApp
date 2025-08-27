import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_project/Screens/MainScreens/Booking/Ev_booking%20screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../Model/Connector_info_Model.dart';
import '../../../Provider/FavouriteProvider.dart';
import '../../../core/constant.dart';

class ChargingStationDetailScreen extends StatefulWidget {
  final String stationId;

  const ChargingStationDetailScreen({super.key, required this.stationId});

  @override
  State<ChargingStationDetailScreen> createState() => _ChargingStationDetailScreenState();
}

class _ChargingStationDetailScreenState extends State<ChargingStationDetailScreen> {
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<FavoriteProvider>(context, listen: false);
    isFavorite = provider.isFavorite(widget.stationId);
  }

  String cleanAddress(String raw) {
    final parts = raw.split(',');
    if (parts.isNotEmpty && RegExp(r'^[A-Z0-9+]{5,}\$').hasMatch(parts.first.trim())) {
      parts.removeAt(0);
    }
    return parts.join(',').trim();
  }


  Future<double?> getRoadDistanceInKm(double destLat, double destLng) async {
    final pos = await Geolocator.getCurrentPosition();
    final apiKey = ApiKeys.googleMaps;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=${pos.latitude},${pos.longitude}'
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
      }
    } catch (e) {
      debugPrint('Distance API Error: $e');
    }

    return null;
  }

  Future<int> getBookedSlots(String stationId, String connectorName) async {
    final now = DateTime.now();
    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('stationId', isEqualTo: stationId)
        .where('connectionType', isEqualTo: connectorName)
        .where('released', isEqualTo: false)
        .get();

    int activeBookings = 0;
    for (var doc in bookingsSnapshot.docs) {
      final bookingTime = (doc['bookingTime'] as Timestamp).toDate();
      final endTime = bookingTime.add(const Duration(minutes: 30));
      if (now.isBefore(endTime)) {
        activeBookings++;
      }
    }
    return activeBookings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('ev_stations').doc(widget.stationId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final availablePoints = data['availablePoints'] ?? 0;
              final name = data['name'] ?? 'Station';
              final address = data['location'] ?? 'Location not available';
              final imageUrl = data['imageUrl'] ?? '';
              final rating = (data['rating'] ?? 0).toDouble();
              final openingHours = data['openingHours'] ?? 'Open 24/7';
              final latitude = data['latitude'] ?? 0.0;
              final longitude = data['longitude'] ?? 0.0;

              final amenities = List<String>.from(data['amenities'] ?? []);
              final connectors = (data['connectors'] as List<dynamic>?)
                  ?.map((e) => ConnectorInfo.fromJson(Map<String, dynamic>.from(e)))
                  .toList() ?? [];

              return Stack(
                children: [
                  CustomScrollView(
                    slivers: [
                      SliverAppBar(
                        expandedHeight: 300,
                        pinned: true,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(imageUrl, fit: BoxFit.cover),
                              Positioned(
                                top: 40,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                left: 16,
                                right: 70,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                                    const SizedBox(height: 4),
                                    Text(
                                      cleanAddress(address),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                      ),
                                    ),
                                    Text('Open: $openingHours',
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: GestureDetector(
                                    onTap: () {
                                      final provider = Provider.of<FavoriteProvider>(context, listen: false);
                                      provider.toggleFavorite(widget.stationId);
                                      setState(() => isFavorite = provider.isFavorite(widget.stationId));
                                    },
                                  child: CircleAvatar(
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Amenities", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 20,
                                runSpacing: 16,
                                children: amenities.map((a) {
                                  IconData icon = Icons.local_offer;
                                  if (a.toLowerCase().contains('washroom')) icon = Icons.wc;
                                  if (a.toLowerCase().contains('wifi')) icon = Icons.wifi;
                                  if (a.toLowerCase().contains('sitting')) icon = Icons.event_seat;
                                  if (a.toLowerCase().contains('food')) icon = Icons.restaurant;

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.green.shade100,
                                        child: Icon(icon, color: Colors.green.shade700, size: 28),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(a, style: const TextStyle(fontSize: 14)),
                                    ],
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              const Text("Available Types", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 190,
                                child: SizedBox(
                                  height: 190,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: connectors.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                                    itemBuilder: (context, index) {
                                      final c = connectors[index];
                                      final total = c.totalSlots ?? 0;

                                      // Calculate booked from availablePoints
                                      final booked = (total - availablePoints).clamp(0, total);

                                      return Container(
                                        width: 185,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.electric_car, size: 30, color: Colors.green.shade700),
                                            const SizedBox(height: 6),
                                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                            const SizedBox(height: 4),
                                            Text('⚡ ${c.power} kW'),
                                            Text('💰 ${c.price} PKR/kWh'),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: booked < total ? Colors.green : Colors.red,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                "$booked/$total Booked",
                                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                )

                              ),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EvBookingScreen(
                                      stationId: widget.stationId,
                                      stationName: name,
                                      availableSlots: 0,
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green.shade700,
                                side: BorderSide(color: Colors.green.shade700),
                              ),
                              child: const Text("Book Slot"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final pos = await Geolocator.getCurrentPosition();
                                final url = Uri.parse(
                                  'https://www.google.com/maps/dir/?api=1&origin=\${pos.latitude},\${pos.longitude}&destination=\$latitude,\$longitude',
                                );
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                              ),
                              child: const Text("Get Direction"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
              top: MediaQuery.of(context).padding.top + 10, // For safe area
              left: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              )),
        ],
      ),
    );
  }
}
