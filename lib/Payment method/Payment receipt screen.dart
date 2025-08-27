import 'package:flutter/material.dart';

class PaymentReceiptScreen extends StatelessWidget {
  final String stationName;
  final String stationAddress;
  final String vehicleType;
  final String vehicleModel;
  final String connectionType;
  final DateTime bookingTime;
  final double amount;
  final double chargePercentage;

  const PaymentReceiptScreen({
    super.key,
    required this.chargePercentage,
    required this.stationName,
    required this.stationAddress,
    required this.vehicleType,
    required this.vehicleModel,
    required this.connectionType,
    required this.bookingTime,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final formattedDate = "${bookingTime.day}/${bookingTime.month}/${bookingTime.year}";
    final formattedTime = TimeOfDay.fromDateTime(bookingTime).format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Receipt'),
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("✅ Payment Successful",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 24),

            _infoRow("Station", stationName),
            _infoRow("Address", stationAddress),
            _infoRow("Vehicle", "$vehicleType - $vehicleModel"),
            _infoRow("Connector", connectionType),
            _infoRow("Date", formattedDate),
            _infoRow("Time", formattedTime),
            _infoRow("Amount Paid", "PKR ${amount.toStringAsFixed(0)}"),

            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                icon: const Icon(Icons.home),
                label: const Text("Back to Home"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label:",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
        ],
      ),
    );
  }
}
