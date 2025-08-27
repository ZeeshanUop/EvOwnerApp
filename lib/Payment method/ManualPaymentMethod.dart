import 'dart:io';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Screens/MainScreens/Dashboard/dashboard.dart';

class BookingWithImagePaymentScreen extends StatefulWidget {
  final String stationId;
  final String stationName;
  final String stationAddress;
  final String stationImageUrl;
  final String vehicleType;
  final String vehicleModel;
  final String connectionType;
  final DateTime bookingTime;
  final double chargePercentage;
  final double amount;
  final int availableSlots;
  final double distanceKm;

  const BookingWithImagePaymentScreen({
    super.key,
    required this.stationId,
    required this.stationName,
    required this.stationAddress,
    required this.stationImageUrl,
    required this.vehicleType,
    required this.vehicleModel,
    required this.connectionType,
    required this.bookingTime,
    required this.chargePercentage,
    required this.amount,
    required this.availableSlots,
    required this.distanceKm,
  });

  @override
  State<BookingWithImagePaymentScreen> createState() =>
      _BookingWithImagePaymentScreenState();
}

class _BookingWithImagePaymentScreenState
    extends State<BookingWithImagePaymentScreen> {
  File? _paymentImage;
  bool isProcessing = false;
  String? stationOwnerId;
  String? stationOwnerFcmToken;
  String? stationOwnerPhone;

  @override
  void initState() {
    super.initState();
    _fetchStationOwner();
  }

  void _fetchStationOwner() async {
    final doc = await FirebaseFirestore.instance
        .collection('ev_stations')
        .doc(widget.stationId)
        .get();
    final data = doc.data();
    if (data != null) {
      setState(() {
        stationOwnerId = data['ownerId'];
        stationOwnerFcmToken = data['fcmToken'];
      });

      if (stationOwnerId != null) {
        final ownerDoc = await FirebaseFirestore.instance
            .collection('ev_station_owners')
            .doc(stationOwnerId)
            .get();
        if (ownerDoc.exists) {
          setState(() {
            stationOwnerPhone = ownerDoc['phone'];
          });
        }
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _paymentImage = File(picked.path));
  }

  Future<void> _submitBooking() async {
    if (_paymentImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload payment screenshot.')),
      );
      return;
    }
    if (stationOwnerId == null) return;

    setState(() => isProcessing = true);
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc =
    await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final fcmToken = await FirebaseMessaging.instance.getToken();

    // 📤 Upload payment screenshot
    final ref = FirebaseStorage.instance
        .ref()
        .child('payments/${DateTime.now().millisecondsSinceEpoch}.jpg');
    await ref.putFile(_paymentImage!);
    final imageUrl = await ref.getDownloadURL();

    final bookingRef = FirebaseFirestore.instance.collection('bookings').doc();

    await bookingRef.set({
      'bookingId': bookingRef.id,
      'stationId': widget.stationId,
      'stationOwnerId': stationOwnerId,
      'stationName': widget.stationName,
      'stationAddress': widget.stationAddress,
      'stationImageUrl': widget.stationImageUrl,
      'userId': user.uid,
      'userName': userDoc['name'],
      'userPhone': userDoc['phone'],
      'userFcmToken': fcmToken,
      'vehicleType': widget.vehicleType,
      'vehicleModel': widget.vehicleModel,
      'connectionType': widget.connectionType,
      'bookingTime': Timestamp.fromDate(widget.bookingTime),
      'chargePercentage': widget.chargePercentage,
      'amount': widget.amount,
      'paymentScreenshotUrl': imageUrl,
      'status': 'pending',
      'createdAt': Timestamp.now(),
    });

    // 🔔 Notifications
    await FirebaseFirestore.instance.collection('notifications').add({
      'to': stationOwnerId,
      'from': user.uid,
      'bookingId': bookingRef.id,
      'type': 'stationBooking',
      'message':
      'New booking request from ${userDoc['name']} at ${widget.stationName}',
      'status': 'unread',
      'timestamp': Timestamp.now(),
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'to': user.uid,
      'bookingId': bookingRef.id,
      'type': 'evOwnerBooking',
      'message': 'You sent a booking request to ${widget.stationName}',
      'status': 'unread',
      'timestamp': Timestamp.now(),
    });

    // 📡 Push notification
    if (stationOwnerFcmToken != null) {
      await FirebaseFirestore.instance.collection('notifications_to_send').add({
        'token': stationOwnerFcmToken,
        'title': 'New Booking Request',
        'body':
        'Booking request from ${userDoc['name']} at ${widget.stationName}',
        'bookingId': bookingRef.id,
        'stationId': widget.stationId,
        'userId': user.uid,
        'createdAt': Timestamp.now(),
      });
    }

    setState(() => isProcessing = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => Dashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🌟 Modern Gradient AppBar with rounded bottom
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          title: const Text('Payment & Booking',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade800, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 💳 Debit Card Glassmorphic Placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1.5),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Text("💳 Debit Card Image Here",
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📋 Booking Details
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              shadowColor: Colors.green.shade200,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.stationName,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.redAccent),
                        const SizedBox(width: 6),
                        Expanded(child: Text(widget.stationAddress)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.directions_car, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text("${widget.vehicleType} - ${widget.vehicleModel}"),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.power, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text("Connection: ${widget.connectionType}"),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.green),
                        const SizedBox(width: 6),
                        Text("Time: ${widget.bookingTime}"),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.battery_charging_full,
                            color: Colors.green),
                        const SizedBox(width: 6),
                        Text("Charge: ${widget.chargePercentage}%"),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.attach_money,
                            color: Colors.deepPurple),
                        const SizedBox(width: 6),
                        Text("Amount: Rs. ${widget.amount}"),
                      ],
                    ),
                    if (stationOwnerPhone != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.teal),
                          const SizedBox(width: 6),
                          Text("Owner: $stationOwnerPhone"),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 📤 Payment Screenshot Upload
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 6,
              shadowColor: Colors.green.shade200,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text("Upload Payment Screenshot",
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _paymentImage != null
                        ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_paymentImage!, height: 200))
                        : Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey.shade400,
                          style: BorderStyle.solid,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text("📷 No screenshot selected",
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Upload Screenshot'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 🚀 Modern Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isProcessing ? null : _submitBooking,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 6,
                  shadowColor: Colors.greenAccent,
                ),
                child: isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "🚀 Send Booking Request",
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
