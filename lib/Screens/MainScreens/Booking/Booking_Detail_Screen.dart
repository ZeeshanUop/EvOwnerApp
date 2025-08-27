import 'dart:convert'; // for jsonEncode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BookingDetailScreen extends StatefulWidget {
  final String bookingId;
  final Future<void> Function(BuildContext, Map<String, dynamic>, String) onCancelBooking;
  final Future<void> Function(BuildContext, Map<String, dynamic>, String) onCompleteBooking;

  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    required this.onCancelBooking,
    required this.onCompleteBooking,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  Map<String, dynamic>? bookingData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBooking();
  }

  Future<void> _loadBooking() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (!doc.exists) throw Exception("Booking not found");
      if (!mounted) return;

      setState(() {
        bookingData = doc.data()!;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading booking: $e")),
      );
      Navigator.pop(context);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'completed':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      default:
        return Icons.hourglass_empty;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Booking Slip")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (bookingData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Booking Slip")),
        body: const Center(child: Text("Booking not found")),
      );
    }

    final status = (bookingData!['status'] ?? '').toString().toLowerCase();
    final bookingTime = bookingData!['bookingTime'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a')
        .format((bookingData!['bookingTime'] as Timestamp).toDate())
        : 'Unknown';

    // Encode booking info into QR JSON
    final qrPayload = jsonEncode({
      "bookingId": widget.bookingId,
      "stationName": bookingData!['stationName'] ?? '',
      "userName": bookingData!['userName'] ?? '',
      "userPhone": bookingData!['userPhone'] ?? '',
      "vehicleType": bookingData!['vehicleType'] ?? '',
      "amount": "${bookingData!['amount'] ?? ''} PKR",
      "bookingTime": bookingTime,
    });

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Booking Slip"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFf5f7fa), Color(0xFFc3cfe2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Station Image
                if (bookingData!['stationImageUrl'] != null)
                  ClipRRect(
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(
                      bookingData!['stationImageUrl'],
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),

                // Title + Status
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        bookingData!['stationName'] ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Chip(
                        avatar: Icon(
                          _statusIcon(status),
                          color: Colors.white,
                          size: 18,
                        ),
                        backgroundColor: _statusColor(status),
                        label: Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Station Info
                _infoSection("📍 Station Info", [
                  {
                    "icon": Icons.location_on,
                    "text": bookingData!['stationAddress'] ?? ''
                  },
                  {
                    "icon": Icons.power,
                    "text": "Connection: ${bookingData!['connectionType'] ?? ''}"
                  },
                ]),

                // Vehicle Info
                _infoSection("🚗 Vehicle Info", [
                  {
                    "icon": Icons.electric_car,
                    "text": "Type: ${bookingData!['vehicleType'] ?? ''}"
                  },
                  {
                    "icon": Icons.directions_car,
                    "text": "Model: ${bookingData!['vehicleModel'] ?? ''}"
                  },
                ]),

                // Booking Info
                _infoSection("⏰ Booking Info", [
                  {
                    "icon": Icons.calendar_today,
                    "text": "Booking Time: $bookingTime"
                  },
                  {
                    "icon": Icons.local_parking_sharp,
                    "text": "Amount: ${bookingData!['amount'] ?? ''} PKR"
                  },
                  {
                    "icon": Icons.person,
                    "text":
                    "User: ${bookingData!['userName'] ?? ''} (${bookingData!['userPhone'] ?? ''})"
                  },
                ]),

                const Divider(),

                // QR Code Section
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      const Text(
                        "📲 Scan QR to Verify Booking",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: qrPayload,
                          version: QrVersions.auto,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),

                // Footer
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: (status == 'accepted')
          ? Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await widget.onCancelBooking(
                      context, bookingData!, widget.bookingId);
                  if (mounted) Navigator.pop(context, true);
                },
                icon: const Icon(Icons.cancel),
                label: const Text("Cancel"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await widget.onCompleteBooking(
                      context, bookingData!, widget.bookingId);
                  if (mounted) Navigator.pop(context, true);
                },
                icon: const Icon(Icons.check_circle),
                label: const Text("Complete"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                ),
              ),
            ),
          ],
        ),
      )
          : null,
    );
  }

  Widget _infoSection(String title, List<Map<String, dynamic>> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          ...items.map(
                (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(item["icon"], color: Colors.blueGrey, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(item["text"],
                          style: const TextStyle(
                              fontSize: 15, color: Colors.black87))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
