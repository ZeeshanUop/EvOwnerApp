import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../PAyment method/ManualPaymentMethod.dart';

class ConfirmBookingScreen extends StatefulWidget {
  final double chargePercentage;
  final String stationId;
  final String stationName;
  final String stationAddress;
  final String stationImageUrl;
  final double rating;
  final int totalSlots;
  final double distanceKm;
  final String vehicleType;
  final String vehicleModel;
  final String connectionType;
  final DateTime bookingTime;
  final double amount;

  const ConfirmBookingScreen({
    super.key,
    required this.chargePercentage,
    required this.stationId,
    required this.stationName,
    required this.stationAddress,
    required this.stationImageUrl,
    required this.rating,
    required this.totalSlots,
    required this.distanceKm,
    required this.vehicleType,
    required this.vehicleModel,
    required this.connectionType,
    required this.bookingTime,
    required this.amount,
  });

  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  bool stationExists = true;
  bool checkingStation = true;

  final Map<String, String> vehicleImageMap = {
    'Tesla Model 3': 'Assets/Tesla.jpeg',
    'Nissan Leaf': 'Assets/Nissan.jpeg',
    'Hyundai Kona': 'Assets/Hyundai.jpeg',
    'Bmw': 'Assets/bmw.jpeg',
  };

  String getVehicleAsset() {
    return vehicleImageMap[widget.vehicleModel] ?? 'Assets/low_battery.png';
  }

  @override
  void initState() {
    super.initState();
    _checkStationExists();
  }

  Future<void> _checkStationExists() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ev_stations')
          .doc(widget.stationId)
          .get();

      setState(() {
        stationExists = doc.exists;
        checkingStation = false;
      });
    } catch (e) {
      setState(() {
        stationExists = false;
        checkingStation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checkingStation) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
          flexibleSpace: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade800, Colors.green.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.ev_station, color: Colors.white, size: 34),
                  SizedBox(height: 6),
                  Text(
                    "Confirm Booking",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle("🚉 Charging Station"),
          _buildStationCard(),
          const SizedBox(height: 20),
          _buildSectionTitle("🚗 Your Vehicle"),
          _buildVehicleCard(),
          const SizedBox(height: 20),
          _buildSectionTitle("📅 Booking Details"),
          _buildBookingDetails(),
          const SizedBox(height: 20),
          _buildSectionTitle("💳 Payment Summary"),
          _buildAmountSummary(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: stationExists
                ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingWithImagePaymentScreen(
                    stationId: widget.stationId,
                    stationName: widget.stationName,
                    stationAddress: widget.stationAddress,
                    stationImageUrl: widget.stationImageUrl,
                    availableSlots: widget.totalSlots,
                    distanceKm: widget.distanceKm,
                    vehicleType: widget.vehicleType,
                    vehicleModel: widget.vehicleModel,
                    connectionType: widget.connectionType,
                    bookingTime: widget.bookingTime,
                    chargePercentage: widget.chargePercentage,
                    amount: widget.amount,
                  ),
                ),
              );
            }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
              stationExists ? Colors.green.shade700 : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 8,
            ),
            child: Text(
              stationExists
                  ? '✅ Confirm & Upload Payment'
                  : '❌ Station Not Available',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _buildStationCard() {
    return _glassCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              widget.stationImageUrl,
              height: 80,
              width: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.ev_station, size: 80);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.stationName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(widget.stationAddress,
                    style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(widget.rating.toStringAsFixed(1)),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildVehicleCard() {
    return _glassCard(
      child: Row(
        children: [
          Image.asset(
            getVehicleAsset(),
            height: 70,
            width: 100,
            fit: BoxFit.cover,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.vehicleModel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              Text(widget.vehicleType,
                  style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetails() {
    final bookingDate =
        "${widget.bookingTime.day}/${widget.bookingTime.month}/${widget.bookingTime.year}";
    final bookingSlot =
    TimeOfDay.fromDateTime(widget.bookingTime).format(context);

    return _glassCard(
      child: Column(
        children: [
          _DetailRow(
              icon: Icons.location_on,
              label: 'Address',
              value: widget.stationAddress),
          const Divider(),
          _DetailRow(icon: Icons.date_range, label: 'Date', value: bookingDate),
          const Divider(),
          _DetailRow(icon: Icons.access_time, label: 'Slot Time', value: bookingSlot),
          const Divider(),
          _DetailRow(
              icon: Icons.power, label: 'Connection', value: widget.connectionType),
          const Divider(),
          _DetailRow(
              icon: Icons.battery_charging_full,
              label: 'Battery',
              value: '${widget.chargePercentage.toInt()}%'),
        ],
      ),
    );
  }

  Widget _buildAmountSummary() {
    return _glassCard(
      bgColor: Colors.green.shade50,
      child: Center(
        child: Text(
          '💵 Estimated Amount: PKR ${widget.amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.green,
          ),
        ),
      ),
    );
  }

  Widget _glassCard({required Widget child, Color? bgColor}) {
    return Card(
      elevation: 6,
      color: bgColor ?? Colors.white.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.green.withOpacity(0.2),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black87)),
          ),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
