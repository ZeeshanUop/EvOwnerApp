import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class BookingSlipScreen extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic>? bookingData;

  const BookingSlipScreen({
    super.key,
    required this.bookingId,
    this.bookingData,
  });

  @override
  Widget build(BuildContext context) {
    if (bookingData != null) {
      return _buildSlip(context, bookingData!);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
              body: Center(child: Text("Booking not found.")));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        return _buildSlip(context, data);
      },
    );
  }

  Widget _buildSlip(BuildContext context, Map<String, dynamic> data) {
    final double powerKw = (data['batteryCapacity'] ?? 0.0).toDouble();
    final double chargeTimeHr = 0.5;
    final String energyEstimate = (powerKw * chargeTimeHr).toStringAsFixed(2);

    final DateTime? bookingTime =
    (data['bookingTime'] != null && data['bookingTime'] is Timestamp)
        ? (data['bookingTime'] as Timestamp).toDate()
        : null;

    final formattedTime = bookingTime != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(bookingTime)
        : "Unknown";

    final status =
    (data['status'] ?? "Pending").toString().toUpperCase(); // uppercase

    return Scaffold(
      appBar: AppBar(title: const Text("Booking Slip")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'EV Booking Slip',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.confirmation_number, "Booking ID", bookingId),
                    const Divider(),
                    _buildInfoRow(Icons.ev_station, "Station", data['stationName'] ?? "Unknown"),
                    _buildInfoRow(Icons.location_on, "Address", data['stationAddress'] ?? "Unknown"),
                    _buildInfoRow(Icons.directions_car, "Vehicle",
                        "${data['vehicleModel'] ?? 'Unknown'} (${data['vehicleType'] ?? ''})"),
                    _buildInfoRow(Icons.electrical_services, "Connector",
                        data['connectionType'] ?? "N/A"),
                    _buildInfoRow(Icons.access_time, "Time", formattedTime),
                    _buildInfoRow(Icons.attach_money, "Amount Paid",
                        "Rs. ${data['amount'] ?? 0}"),
                    const Divider(),
                    _buildInfoRow(Icons.timer, "Charging Time", "30 minutes"),
                    _buildInfoRow(Icons.bolt, "Energy Estimated",
                        "$energyEstimate kWh"),
                    const Divider(),
                    Row(
                      children: [
                        const Icon(Icons.info, size: 20, color: Colors.teal),
                        const SizedBox(width: 10),
                        Text("Booking Status",
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey)),
                        const SizedBox(width: 10),
                        Chip(
                          label: Text(status),
                          backgroundColor: status == "ACCEPTED"
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          labelStyle: TextStyle(
                            color: status == "ACCEPTED"
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text("Scan QR on arrival:",
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data:
                "booking:$bookingId;station:${data['stationName'] ?? ''};uid:${data['userId'] ?? ''}",
                version: QrVersions.auto,
                size: 150.0,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Download PDF"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _generatePdf(context, data, formattedTime, status),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text("Share Slip"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _sharePdf(context, data, formattedTime, status),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, Map<String, dynamic> data,
      String formattedTime, String status) async {
    final pdf = pw.Document();

    // Generate QR for PDF
    final qrPainter = QrPainter(
      data: "booking:$bookingId;station:${data['stationName']};uid:${data['userId']}",
      version: QrVersions.auto,
      gapless: false,
    );
    final qrImageData = await qrPainter.toImageData(200);
    final Uint8List qrBytes = qrImageData!.buffer.asUint8List();
    final qr = pw.MemoryImage(qrBytes);

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('EV Booking Slip',
                style:
                pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Booking ID: $bookingId'),
            pw.Text('Station: ${data['stationName'] ?? ''}'),
            pw.Text('Address: ${data['stationAddress'] ?? ''}'),
            pw.Text(
                'Vehicle: ${data['vehicleModel'] ?? 'Unknown'} (${data['vehicleType'] ?? ''})'),
            pw.Text('Connector: ${data['connectionType'] ?? 'N/A'}'),
            pw.Text('Time: $formattedTime'),
            pw.Text('Amount Paid: Rs. ${data['amount'] ?? 0}'),
            pw.Text('Status: $status'),
            pw.SizedBox(height: 20),
            pw.Text("Scan QR on arrival:"),
            pw.SizedBox(height: 10),
            pw.Image(qr, width: 120, height: 120),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdf.save());
  }

  Future<void> _sharePdf(BuildContext context, Map<String, dynamic> data,
      String formattedTime, String status) async {
    final pdf = pw.Document();

    // QR for PDF
    final qrPainter = QrPainter(
      data: "booking:$bookingId;station:${data['stationName']};uid:${data['userId']}",
      version: QrVersions.auto,
      gapless: false,
    );
    final qrImageData = await qrPainter.toImageData(200);
    final Uint8List qrBytes = qrImageData!.buffer.asUint8List();
    final qr = pw.MemoryImage(qrBytes);

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('EV Booking Slip',
                style:
                pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('Booking ID: $bookingId'),
            pw.Text('Station: ${data['stationName'] ?? ''}'),
            pw.Text('Address: ${data['stationAddress'] ?? ''}'),
            pw.Text(
                'Vehicle: ${data['vehicleModel'] ?? 'Unknown'} (${data['vehicleType'] ?? ''})'),
            pw.Text('Connector: ${data['connectionType'] ?? 'N/A'}'),
            pw.Text('Time: $formattedTime'),
            pw.Text('Amount Paid: Rs. ${data['amount'] ?? 0}'),
            pw.Text('Status: $status'),
            pw.SizedBox(height: 20),
            pw.Text("Scan QR on arrival:"),
            pw.SizedBox(height: 10),
            pw.Image(qr, width: 120, height: 120),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/booking_slip_$bookingId.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'EV Booking Slip');
  }
}
