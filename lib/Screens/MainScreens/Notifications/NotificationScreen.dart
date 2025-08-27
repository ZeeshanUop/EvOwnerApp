import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:just_audio/just_audio.dart';

import '../Booking/BookingSlip.dart';

class NotificationScreen extends StatefulWidget {
  final String? notifId; // comes from FCM payload
  const NotificationScreen({super.key, this.notifId});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _player = AudioPlayer();

  String? _highlightedId;
  bool _didScroll = false;

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.notifId;

    if (_highlightedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerFeedback();
      });

      Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedId = null);
      });
    }
  }

  Future<void> _triggerFeedback() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 150);
    }
    try {
      await _player.setAsset("assets/bell.wav");
      await _player.play();
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _scrollToNotification(List<QueryDocumentSnapshot> notifs) {
    if (_didScroll || widget.notifId == null) return;

    final index = notifs.indexWhere((n) => n.id == widget.notifId);
    if (index != -1) {
      _didScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          index * 110.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "accepted":
        return Colors.green.shade600;
      case "rejected":
        return Colors.red.shade600;
      case "cancelled":
        return Colors.grey.shade600;
      default:
        return Colors.orange.shade600;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case "accepted":
        return Icons.check_circle;
      case "rejected":
        return Icons.cancel;
      case "cancelled":
        return Icons.remove_circle;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "accepted":
        return "Accepted";
      case "rejected":
        return "Rejected";
      case "cancelled":
        return "Cancelled";
      default:
        return "Pending";
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.teal,
        elevation: 2,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications_to_send')
            .where('to', isEqualTo: currentUserId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    "No notifications yet",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "You’ll see updates about your bookings here",
                    style: TextStyle(color: Colors.grey.shade500),
                  )
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;
          _scrollToNotification(notifications);

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index].data() as Map<String, dynamic>;
              final docId = notifications[index].id;
              final isHighlighted = _highlightedId == docId;

              final bookingStatus = (notif['bookingStatus'] ?? "pending").toString();
              final statusColor = _statusColor(bookingStatus);

              return Dismissible(
                key: Key(docId),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) async {
                  await FirebaseFirestore.instance
                      .collection('notifications_to_send')
                      .doc(docId)
                      .delete();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Notification deleted")),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isHighlighted
                          ? Colors.teal.shade300
                          : Colors.grey.shade200,
                      width: isHighlighted ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 26,
                      backgroundColor: statusColor.withOpacity(0.15),
                      child: Icon(
                        _statusIcon(bookingStatus),
                        color: statusColor,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      notif['title'] ?? "No Title",
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          notif['message'] ?? "",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 10),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _statusLabel(bookingStatus),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: bookingStatus == "accepted"
                        ? Icon(Icons.arrow_forward_ios,
                        size: 18, color: Colors.grey.shade600)
                        : null,
                    onTap: () async {
                      final bookingId = notif['bookingId'];
                      if (bookingId == null) return;

                      try {
                        final snap = await FirebaseFirestore.instance
                            .collection('bookings')
                            .doc(bookingId)
                            .get();

                        if (!snap.exists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Booking no longer exists.")),
                          );
                          return;
                        }

                        final booking = snap.data()!;
                        final status = booking['status'];

                        if (status == "accepted") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BookingSlipScreen(bookingId: bookingId),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                status == "rejected"
                                    ? "This booking was rejected."
                                    : status == "cancelled"
                                    ? "This booking was cancelled."
                                    : "Booking is still pending.",
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Error fetching booking: $e")),
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}