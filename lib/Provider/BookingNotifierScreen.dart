
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/constant.dart';

// Called after booking is confirmed
Future<void> createBookingAndNotify({
  required String stationId,
  required String stationName,
  required DateTime dateTime,
}) async {
  final user = FirebaseAuth.instance.currentUser;

  // Create booking
  final bookingDoc = await FirebaseFirestore.instance.collection('bookings').add({
    'stationId': stationId,
    'bookedBy': user!.uid,
    'userName': user.displayName ?? "EV Owner",
    'bookingTime': dateTime,
    'createdAt': FieldValue.serverTimestamp(),
  });

  // Get station and owner details
  final stationSnapshot = await FirebaseFirestore.instance.collection('stations').doc(stationId).get();
  final ownerId = stationSnapshot['ownerId'];

  final ownerSnapshot = await FirebaseFirestore.instance.collection('users').doc(ownerId).get();
  final ownerToken = ownerSnapshot['deviceToken'];

  // Send notification
  await sendBookingNotification(
    deviceToken: ownerToken,
    stationName: stationName,
    bookedBy: user.displayName ?? "EV Owner",
  );
}

Future<void> sendBookingNotification({
  required String deviceToken,
  required String stationName,
  required String bookedBy,
}) async {
  final serverKey = ApiKeys.fcmServer;
  final data = {
    "to": deviceToken,
    "notification": {
      "title": "New Slot Booked",
      "body": "$bookedBy booked a slot at $stationName",
    },
    "data": {
      "click_action": "FLUTTER_NOTIFICATION_CLICK",
      "station": stationName,
    }
  };

  final headers = {
    "Content-Type": "application/json",
    "Authorization": "key=$serverKey",
  };

  final response = await http.post(
    Uri.parse("https://fcm.googleapis.com/fcm/send"),
    headers: headers,
    body: jsonEncode(data),
  );

  if (response.statusCode == 200) {
    print("✅ Notification sent");
  } else {
    print("❌ Failed to send: ${response.body}");
  }
}
