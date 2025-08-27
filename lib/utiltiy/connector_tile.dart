import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Model/Connector_info_Model.dart';

class ConnectorTile extends StatelessWidget {
  final ConnectorInfo connector;
  final String stationId;

  const ConnectorTile({
    super.key,
    required this.connector,
    required this.stationId,
  });

  Future<int> getAvailablePoints(String stationId, String connectorType, int totalSlots) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('stationId', isEqualTo: stationId)
          .where('connectorType', isEqualTo: connectorType)
          .where('status', isEqualTo: 'active') // adjust if using timestamps
          .get();

      final activeBookings = snapshot.docs.length;
      final available = totalSlots - activeBookings;
      return available >= 0 ? available : 0;
    } catch (e) {
      print('Error fetching availability: $e');
      return totalSlots; // fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: getAvailablePoints(stationId, connector.name, connector.totalSlots),
      builder: (context, snapshot) {
        final isLoading = !snapshot.hasData;
        final availablePoints = snapshot.data ?? connector.totalSlots;

        Color availabilityColor;
        String availabilityStatus;
        if (connector.totalSlots == 0) {
          availabilityColor = Colors.grey;
          availabilityStatus = 'Unknown';
        } else if (availablePoints == 0) {
          availabilityColor = Colors.red;
          availabilityStatus = 'Busy';
        } else if (availablePoints < connector.totalSlots) {
          availabilityColor = Colors.orange;
          availabilityStatus = 'Partial';
        } else {
          availabilityColor = Colors.green;
          availabilityStatus = 'Available';
        }

        return Container(
          width: 130,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ev_station, size: 28, color: availabilityColor),
              const SizedBox(height: 6),
              Text(
                connector.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text("Power: ${connector.power}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text("Price: ${connector.price}",
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Text(
                "Available: $availablePoints / ${connector.totalSlots}",
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              Text(
                availabilityStatus,
                style: TextStyle(
                  color: availabilityColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
