import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'Booking_Detail_Screen.dart';
import 'RatingScreen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

    @override
    State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with SingleTickerProviderStateMixin {
    late TabController _tabController;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    @override
    void initState() {
        super.initState();
        _tabController = TabController(length: 2, vsync: this);
    }

    Stream<QuerySnapshot> _ongoingBookings() {
        return FirebaseFirestore.instance
                .collection('bookings')
                .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots();
    }

    Stream<QuerySnapshot> _historyBookings() {
        return FirebaseFirestore.instance
                .collection('bookings')
                .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['completed', 'cancelled'])
        .snapshots();
    }

    Future<void> _cancelBooking(BuildContext context, Map<String, dynamic> bookingData, String bookingId) async {
        try {
            final stationId = bookingData['stationId'];
            final stationOwnerId = bookingData['stationOwnerId'];

            if (stationId == null || stationOwnerId == null) {
                throw Exception("Station or Owner ID missing");
            }

            File? imageFile;
            final picker = ImagePicker();
            final picked = await picker.pickImage(source: ImageSource.gallery);
            if (picked == null) return; // user cancelled

            imageFile = File(picked.path);

            // Upload screenshot
            final ref = FirebaseStorage.instance.ref().child("cancelScreenshots/$bookingId.jpg");
            await ref.putFile(imageFile);
            final screenshotUrl = await ref.getDownloadURL();

            // Update available slot safely
            final stationRef = FirebaseFirestore.instance.collection('stations').doc(stationId);
            await FirebaseFirestore.instance.runTransaction((txn) async {
                final snap = await txn.get(stationRef);
                if (!snap.exists) throw Exception("Station does not exist");
                final connectors = Map<String, dynamic>.from(snap.data()?['connectors'] ?? {});
                final connectorType = bookingData['connectionType'];
                if (!connectors.containsKey(connectorType)) {
                    connectors[connectorType] = {'availablePoints': 0};
                }
                connectors[connectorType]['availablePoints'] = (connectors[connectorType]['availablePoints'] ?? 0) + 1;
                txn.update(stationRef, {'connectors': connectors});
            });

            // Update booking
            await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
                    'status': 'cancelled',
                    'cancelScreenshot': screenshotUrl,
      });

            // Notifications
            await FirebaseFirestore.instance.collection('notifications').add({
                    'to': stationOwnerId,
                    'bookingId': bookingId,
                    'stationId': stationId,
                    'type': 'bookingCancelled',
                    'message': "Booking cancelled by user. Screenshot uploaded.",
                    'screenshotUrl': screenshotUrl,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'unread',
      });

            await FirebaseFirestore.instance.collection('notifications').add({
                    'to': uid,
                    'bookingId': bookingId,
                    'stationId': stationId,
                    'type': 'bookingCancelled',
                    'message': "You cancelled your booking. Screenshot uploaded.",
                    'screenshotUrl': screenshotUrl,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'unread',
      });

            ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking cancelled & slot released.")),
      );
            Navigator.pop(context, true);

        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error cancelling booking: $e")),
      );
        }
    }

    Future<void> _completeBooking(BuildContext context, Map<String, dynamic> bookingData, String bookingId) async {
        try {
            final stationId = bookingData['stationId'];
            if (stationId == null) throw Exception("Station ID missing");

            // Release slot
            final stationRef = FirebaseFirestore.instance.collection('stations').doc(stationId);
            await FirebaseFirestore.instance.runTransaction((txn) async {
                final snap = await txn.get(stationRef);
                if (!snap.exists) throw Exception("Station does not exist");
                final connectors = Map<String, dynamic>.from(snap.data()?['connectors'] ?? {});
                final connectorType = bookingData['connectionType'];
                if (!connectors.containsKey(connectorType)) {
                    connectors[connectorType] = {'availablePoints': 0};
                }
                connectors[connectorType]['availablePoints'] = (connectors[connectorType]['availablePoints'] ?? 0) + 1;
                txn.update(stationRef, {'connectors': connectors});
            });

            await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
                    'status': 'completed',
      });

            // Notify user
            await FirebaseFirestore.instance.collection('notifications').add({
                    'to': uid,
                    'bookingId': bookingId,
                    'stationId': stationId,
                    'type': 'bookingCompleted',
                    'message': "Your booking has been completed.",
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'unread',
      });

            ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking marked as completed.")),
      );
            Navigator.pop(context, true);

        } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error completing booking: $e")),
      );
        }
    }

    Future<void> _deleteBooking(String bookingId) async {
        await FirebaseFirestore.instance.collection('bookings').doc(bookingId).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking deleted")));
    }

    Widget _buildBookingCard(DocumentSnapshot booking, bool isOngoing) {
        final status = (booking['status'] ?? '').toString().toLowerCase();
        return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: ListTile(
                title: Text(booking['stationName'] ?? 'Station'),
                subtitle: Text("Status: ${status[0].toUpperCase()}${status.substring(1)}"),
                trailing: isOngoing
                ? IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.teal),
        onPressed: () {
            Navigator.push(
                    context,
                    MaterialPageRoute(
                            builder: (_) => BookingDetailScreen(
                    bookingId: booking.id,
                    onCancelBooking: _cancelBooking,
                    onCompleteBooking: _completeBooking,
                      ),
                    ),
                  ).then((value) {
            if (value == true) setState(() {}); // refresh after cancel/complete
                  });
        },
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
        IconButton(
                icon: const Icon(Icons.visibility, color: Colors.blue),
        tooltip: 'View Detail',
                onPressed: () {
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
        IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
        tooltip: 'Delete',
                onPressed: () => _deleteBooking(booking.id),
                  ),
        if (status == 'completed')
            IconButton(
                    icon: const Icon(Icons.star, color: Colors.orange),
        tooltip: 'Rate Now',
                onPressed: () {
            Navigator.push(
                    context,
                    MaterialPageRoute(
                            builder: (_) => RatingScreen(
                    bookingId: booking.id,
                    stationId: booking['stationId'],
                            ),
                          ),
                        );
        },
                    ),
                ],
              ),
      ),
    );
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
                appBar: AppBar(
                title: const Text("My Bookings"),
                bottom: TabBar(
                controller: _tabController,
                tabs: const [
        Tab(text: "Ongoing"),
        Tab(text: "History"),
          ],
        ),
      ),
        body: TabBarView(
                controller: _tabController,
                children: [
        StreamBuilder<QuerySnapshot>(
                stream: _ongoingBookings(),
                builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text("No ongoing bookings"));
            return ListView(children: docs.map((b) => _buildBookingCard(b, true)).toList());
        },
          ),
        StreamBuilder<QuerySnapshot>(
                stream: _historyBookings(),
                builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) return const Center(child: Text("No booking history"));
            return ListView(children: docs.map((b) => _buildBookingCard(b, false)).toList());
        },
          ),
        ],
      ),
    );
    }
}
