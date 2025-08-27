import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fyp_project/Model/Connector_info_Model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Screens/MainScreens/StationDetailScreen/Charging_station_info.dart';

class ChargingCard extends StatelessWidget {
  final String stationId;
  final String name;
  final String location;
  final double rating;
  final String status;
  final String imagePath;
  final String? distance;
  final double? width;
  final double? height;
  final bool isImageLeft;
  final List<ConnectorInfo>? connectors;
  final String? openingHours;
  final String? pricing;
  final List<String>? amenities;
  final double? latitude;
  final double? longitude;

  ChargingCard({
    super.key,
    required this.stationId,
    required this.name,
    required this.location,
    required this.rating,
    required this.status,
    required this.imagePath,
    this.distance,
    this.width,
    this.height,
    this.isImageLeft = false,
    this.connectors,
    this.openingHours,
    this.pricing,
    this.amenities,
    this.latitude,
    this.longitude,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChargingStationDetailScreen(stationId: stationId),
        ),
      ),
      child: Container(
        width: width ?? 260,
        height: height ?? 260,
        margin: const EdgeInsets.only(right: 12, bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(blurRadius: 6, color: Colors.grey.shade300)],
        ),
        child: isImageLeft ? _buildHorizontalLayout(context) : _buildVerticalLayout(context),
      ),
    );
  }

  Widget _buildVerticalLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageBanner(isHorizontal: false),
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildCardDetails(context),
        ),
      ],
    );
  }

  Widget _buildHorizontalLayout(BuildContext context) {
    return Row(
      children: [
        _buildImageBanner(isHorizontal: true),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildCardDetails(context),
          ),
        ),
      ],
    );
  }

  Widget _buildImageBanner({required bool isHorizontal}) {
    return Hero(
      tag: name,
      child: Stack(
        children: [
          // Station Image
          ClipRRect(
            borderRadius: isHorizontal
                ? const BorderRadius.horizontal(left: Radius.circular(16))
                : const BorderRadius.vertical(top: Radius.circular(16)),
            child: imagePath.startsWith('http')
                ? Image.network(
              imagePath,
              height: isHorizontal ? double.infinity : 100,
              width: isHorizontal ? 120 : double.infinity,
              fit: BoxFit.cover,
            )
                : Image.asset(
              imagePath,
              height: isHorizontal ? double.infinity : 100,
              width: isHorizontal ? 120 : double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Status Badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'Open'
                    ? Colors.green
                    : status == 'Closed'
                    ? Colors.red
                    : Colors.orange, // under maintenance
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCardDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(location,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        if (distance != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              "$distance away",
              style: const TextStyle(color: Colors.blueGrey, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 5),
            Text("${rating.toStringAsFixed(1)}", style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),

        /// 🔁 Replace bookings query with this station doc stream
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ev_stations') // use your collection name
              .doc(stationId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const SizedBox.shrink();
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final available = data['availablePoints'] ?? 0;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$available",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                    const Text('Charging Points', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _launchDirections(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Get Direction", style: TextStyle(fontSize: 13, color: Colors.white)),
                ),
              ],
            );
          },
        ),
      ],
    );
  }


  Future<void> _launchDirections(BuildContext context) async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
      return;
    }

    try {
      final current = await Geolocator.getCurrentPosition();
      final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
            '&origin=${current.latitude},${current.longitude}'
            '&destination=$latitude,$longitude'
            '&travelmode=driving',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
    }
  }
}
