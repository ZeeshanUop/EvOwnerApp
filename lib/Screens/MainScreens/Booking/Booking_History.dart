import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'Booking_Detail_Screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // Firestore Queries
  Stream<QuerySnapshot> _ongoingBookings() => FirebaseFirestore.instance
      .collection('bookings')
      .where('userId', isEqualTo: uid)
      .where('status', isEqualTo: 'accepted')
      .snapshots();

  Stream<QuerySnapshot> _historyBookings() => FirebaseFirestore.instance
      .collection('bookings')
      .where('userId', isEqualTo: uid)
      .where('status', whereIn: ['completed', 'cancelled'])
      .snapshots();

  // Update Available Points
  Future<void> _updateAvailablePoints({
    required String stationId,
    required String connectorType,
    required bool increment,
  }) async {
    final stationRef =
    FirebaseFirestore.instance.collection('ev_stations').doc(stationId);

    await FirebaseFirestore.instance.runTransaction((txn) async {
      final snap = await txn.get(stationRef);
      if (!snap.exists) throw Exception("Station does not exist");

      int stationPoints = (snap.data()?['availablePoints'] ?? 0) as int;
      stationPoints = increment ? stationPoints + 1 : stationPoints - 1;

      List connectors = List.from(snap.data()?['connectors'] ?? []);
      connectors = connectors.map((c) {
        if (c['name'] == connectorType) {
          int connPoints = (c['availablePoints'] ?? 0) as int;
          c['availablePoints'] =
          increment ? connPoints + 1 : connPoints - 1;
        }
        return c;
      }).toList();

      txn.update(
          stationRef, {'availablePoints': stationPoints, 'connectors': connectors});
    });
  }

  // Cancel Booking
  Future<void> _cancelBooking(
      BuildContext context, Map<String, dynamic> bookingData, String bookingId) async {
    try {
      final stationId = bookingData['stationId'];
      final stationOwnerId = bookingData['stationOwnerId'];
      if (stationId == null || stationOwnerId == null) {
        throw Exception("Station or Owner ID missing");
      }

      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final imageFile = File(picked.path);

      final ref =
      FirebaseStorage.instance.ref().child("cancelScreenshots/$bookingId.jpg");
      await ref.putFile(imageFile);
      final screenshotUrl = await ref.getDownloadURL();

      await _updateAvailablePoints(
          stationId: stationId,
          connectorType: bookingData['connectionType'],
          increment: true);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'status': 'cancelled',
        'cancelScreenshot': screenshotUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking cancelled & slot released.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error cancelling booking: $e")));
    }
  }

  // Complete Booking
  Future<void> _completeBooking(
      BuildContext context, Map<String, dynamic> bookingData, String bookingId) async {
    try {
      final stationId = bookingData['stationId'];
      if (stationId == null) throw Exception("Station ID missing");

      await _updateAvailablePoints(
          stationId: stationId,
          connectorType: bookingData['connectionType'],
          increment: true);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({'status': 'completed'});

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Booking marked as completed.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error completing booking: $e")));
    }
  }

  // Booking Card
  Widget _buildBookingCard(DocumentSnapshot booking, bool isOngoing) {
    final data = booking.data() as Map<String, dynamic>;
    final status = (data['status'] ?? '').toString().toLowerCase();
    final bookingTime = data['bookingTime'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: data['stationImageUrl'] != null
              ? Image.network(
            data['stationImageUrl'],
            width: 70,
            height: 70,
            fit: BoxFit.cover,
          )
              : Container(
            width: 70,
            height: 70,
            color: Colors.green.shade100,
            child: const Icon(Icons.ev_station, color: Colors.green),
          ),
        ),
        title: Text(
          data['stationName'] ?? 'EV Station',
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Chip(
              label: Text(
                status[0].toUpperCase() + status.substring(1),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              backgroundColor: status == "accepted"
                  ? Colors.green
                  : status == "completed"
                  ? Colors.blue
                  : Colors.red,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 6),
            if (bookingTime != null)
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    bookingTime is Timestamp
                        ? DateFormat('dd MMM yyyy, hh:mm a')
                        .format(bookingTime.toDate())
                        : bookingTime.toString(),
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookingDetailScreen(
                bookingId: booking.id,
                onCancelBooking: _cancelBooking,
                onCompleteBooking: _completeBooking,
              ),
            ),
          );
        },
      ),
    );
  }

  // Layout
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 80,
        centerTitle: true,
        title: const Text(
          "📅 My Bookings",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: LinearGradient(
                  colors: [Colors.green.shade600, Colors.green.shade400],
                ),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.green,
              tabs: const [
                Tab(icon: Icon(Icons.play_circle_fill), text: "Ongoing"),
                Tab(icon: Icon(Icons.history), text: "History"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Ongoing Bookings
          StreamBuilder<QuerySnapshot>(
            stream: _ongoingBookings(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text("✨ No ongoing bookings",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                );
              }
              return ListView(
                children: docs.map((b) => _buildBookingCard(b, true)).toList(),
              );
            },
          ),
          // Booking History
          StreamBuilder<QuerySnapshot>(
            stream: _historyBookings(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text("📜 No booking history",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                );
              }
              return ListView(
                children: docs.map((b) => _buildBookingCard(b, false)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
