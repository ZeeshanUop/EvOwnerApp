import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../../core/constant.dart';
import 'confirmbookingscreen.dart';

class EvBookingScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final int availableSlots;

  // Optional prefill
  final String? stationImageUrl;
  final String? vehicleType;
  final String? vehicleModel;
  final String? connectionType;
  final double? chargePercentage;

  const EvBookingScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.availableSlots,
    this.stationImageUrl,
    this.vehicleType,
    this.vehicleModel,
    this.connectionType,
    this.chargePercentage,
  });

  @override
  State<EvBookingScreen> createState() => _EvBookingScreenState();
}

class _EvBookingScreenState extends State<EvBookingScreen> {
  String? vehicleType;
  String? vehicleModel;
  String? connectionType;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  double? amount;
  double chargePercentage = 100;

  final vehicleTypes = ['Car', 'Bike', 'Van'];
  final vehicleModels = ['Tesla Model 3', 'Nissan Leaf', 'Hyundai Kona', 'BMW'];
  final connectionTypes = ['CCS', 'Type2', 'CHAdeMO', 'CCS2', 'Mennekes'];

  @override
  void initState() {
    super.initState();
    chargePercentage = widget.chargePercentage ?? 100;
    _loadConnectorBasedAmount();
  }

  Future<double?> getRoadDistanceInKm(
      double originLat, double originLng, double destLat, double destLng) async {
    final String _googleApiKey = ApiKeys.googleMaps;

    final url =
        'https://maps.googleapis.com/maps/api/distancematrix/json?units=metric'
        '&origins=$originLat,$originLng'
        '&destinations=$destLat,$destLng'
        '&key=$_googleApiKey';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final rows = data['rows'];
        if (rows != null && rows.length > 0) {
          final elements = rows[0]['elements'];
          if (elements != null &&
              elements.length > 0 &&
              elements[0]['status'] == 'OK') {
            final distanceInMeters = elements[0]['distance']['value'];
            return distanceInMeters / 1000; // ✅ Road distance
          }
        }
      }
    } catch (e) {
      debugPrint("Distance Matrix API error: $e");
    }

    // ⚡ Fallback: Straight line distance
    const double R = 6371; // Earth radius in km
    double dLat = (destLat - originLat) * (3.14159 / 180);
    double dLon = (destLng - originLng) * (3.14159 / 180);
    double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
            cos(originLat * (3.14159 / 180)) *
                cos(destLat * (3.14159 / 180)) *
                (sin(dLon / 2) * sin(dLon / 2));
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // ✅ Straight line km
  }

  Future<void> _loadConnectorBasedAmount() async {
    if (connectionType == null) return;
    setState(() => amount = null); // show loader

    try {
      final doc = await FirebaseFirestore.instance
          .collection('ev_stations')
          .doc(widget.stationId)
          .get();

      final data = doc.data();
      if (data == null || !data.containsKey('connectors')) return;

      final connectors = List<Map<String, dynamic>>.from(data['connectors']);
      Map<String, dynamic>? selected;
      for (final c in connectors) {
        if (c['name'].toString().toLowerCase() ==
            connectionType!.toLowerCase()) {
          selected = c;
          break;
        }
      }

      if (selected == null) return;

      final powerString = selected['power']?.toString() ?? '';
      final priceString = selected['price']?.toString() ?? '';
      final kw =
          double.tryParse(RegExp(r'[\d.]+').stringMatch(powerString) ?? '') ??
              0;
      final pricePerKw =
          double.tryParse(RegExp(r'[\d.]+').stringMatch(priceString) ?? '') ??
              0;

      final calculatedAmount = (kw * pricePerKw) * (chargePercentage / 100);
      setState(() => amount = calculatedAmount);
    } catch (e) {
      debugPrint("Error parsing connector: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error calculating amount: $e')),
      );
    }
  }
  void printApiKey() {
    if (kDebugMode) {
      debugPrint("🔑 Google Maps API Key: ${ApiKeys.googleMaps}");
    }
  }
  Future<void> _submitBooking() async {
    if (vehicleType == null ||
        vehicleModel == null ||
        connectionType == null ||
        selectedDate == null ||
        selectedTime == null ||
        amount == null) {
      // Randomized error messages
      final messages = [
        "Please fill all the fields",
        "Please fill all the field",
      ];
      final randomMessage = (messages..shuffle()).first;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(randomMessage),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    final bookingTime = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );

    try {
      // Processing snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Processing your booking...")),
      );

      final stationDoc = await FirebaseFirestore.instance
          .collection('ev_stations')
          .doc(widget.stationId)
          .get();

      final data = stationDoc.data();
      if (data == null) throw Exception("Station not found");

      final stationAddress = (data['address'] ??
          data['stationAddress'] ??
          data['location'] ??
          'Address not available')
          .toString()
          .trim();

      final stationImageUrl = data['imageUrl'] ?? '';
      final stationRating = (data['rating'] ?? 0).toDouble();
      final stationLat = data['latitude'];
      final stationLng = data['longitude'];

      final currentPosition = await Geolocator.getCurrentPosition();
      double? distanceKm = await getRoadDistanceInKm(
        currentPosition.latitude,
        currentPosition.longitude,
        stationLat,
        stationLng,
      );

      if (distanceKm == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
              Text('Unable to calculate road distance. Please try again.')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmBookingScreen(
            stationId: widget.stationId,
            stationName: widget.stationName,
            stationAddress: stationAddress,
            stationImageUrl: stationImageUrl,
            rating: stationRating,
            totalSlots: widget.availableSlots,
            distanceKm: distanceKm,
            vehicleType: vehicleType!,
            vehicleModel: vehicleModel!,
            connectionType: connectionType!,
            bookingTime: bookingTime,
            amount: amount!,
            chargePercentage: chargePercentage,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Booking failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------- UI ---------------- //
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120), // taller height
        child: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: true,
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
              child: Stack(
                children: [
                  Positioned(
                    bottom: -30,
                    left: -40,
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    right: -30,
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.ev_station, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Text(
                          "Book EV Slot",
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
                ],
              ),
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.stationImageUrl != null &&
              widget.stationImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(widget.stationImageUrl!,
                  height: 160, width: double.infinity, fit: BoxFit.cover),
            ),
          const SizedBox(height: 20),

          _buildPickerCard(
              icon: Icons.directions_car,
              label: "Vehicle Type",
              value: vehicleType,
              onTap: () => _showOptionsDialog(
                  "Select Vehicle Type", vehicleTypes,
                      (val) => setState(() => vehicleType = val))),
          _buildPickerCard(
              icon: Icons.electric_car,
              label: "Vehicle Model",
              value: vehicleModel,
              onTap: () => _showOptionsDialog(
                  "Select Vehicle Model", vehicleModels,
                      (val) => setState(() => vehicleModel = val))),
          _buildPickerCard(
              icon: Icons.power,
              label: "Connector Type",
              value: connectionType,
              onTap: () => _showOptionsDialog(
                "Select Connector Type",
                connectionTypes,
                    (val) {
                  setState(() => connectionType = val);
                  _loadConnectorBasedAmount();
                },
              )),
          _buildPickerCard(
              icon: Icons.calendar_today,
              label: "Booking Date",
              value: selectedDate != null
                  ? "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"
                  : null,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (date != null) setState(() => selectedDate = date);
              }),
          _buildPickerCard(
              icon: Icons.access_time,
              label: "Booking Time",
              value: selectedTime?.format(context),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) setState(() => selectedTime = time);
              }),

          const SizedBox(height: 20),
          connectionType == null
              ? _buildInfoMessage(
              "⚡ Please select a connector type to calculate cost.")
              : _buildChargeAndAmount(),
          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: _submitBooking,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              backgroundColor: Colors.green.shade700,
              elevation: 3,
            ),
            child: const Text("Proceed to Confirmation",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerCard(
      {required IconData icon,
        required String label,
        String? value,
        required VoidCallback onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade100,
          child: Icon(icon, color: Colors.green.shade800),
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(value ?? "Choose $label",
            style: TextStyle(
                color: value == null ? Colors.grey : Colors.black,
                fontWeight:
                value == null ? FontWeight.normal : FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    );
  }

  Widget _buildChargeAndAmount() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Charge Level (%)",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Slider.adaptive(
            value: chargePercentage,
            min: 10,
            max: 100,
            divisions: 9,
            label: "${chargePercentage.toInt()}%",
            activeColor: Colors.green.shade700,
            onChanged: (value) {
              setState(() {
                chargePercentage = value;
                amount = null;
              });
              _loadConnectorBasedAmount();
            },
          ),
          const SizedBox(height: 12),
          amount == null
              ? const Text("Calculating price...",
              style: TextStyle(color: Colors.grey))
              : Text("💰 Estimated Price: PKR ${amount!.toStringAsFixed(0)}",
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.green)),
        ]),
      ),
    );
  }

  Widget _buildInfoMessage(String msg) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [
        Icon(Icons.info_outline, color: Colors.orange.shade600),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500)))
      ]),
    );
  }

  void _showOptionsDialog(
      String title, List<String> options, Function(String) onSelected) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold))),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => ListTile(
              title: Text(options[index]),
              onTap: () {
                Navigator.pop(context);
                onSelected(options[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
