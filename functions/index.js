import admin from "firebase-admin";
import { initializeApp } from "firebase-admin/app";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";

initializeApp();
const db = admin.firestore();
const fcm = admin.messaging();


// 1️⃣ EV Owner → Station Owner (New Booking Created)
// Stored in `notifications`
export const notifyStationOwnerOnBooking = onDocumentCreated(
  "bookings/{bookingId}",
  async (event) => {
    const booking = event.data?.data();
    if (!booking) return;

    const stationOwnerId = booking.stationOwnerId;
    const bookingId = event.params.bookingId;

    try {
      const ownerSnap = await db.collection("ev_station_owners").doc(stationOwnerId).get();
      const token = ownerSnap.data()?.fcmToken;

      // 🔹 Store in notifications collection
      const notifRef = await db.collection("notifications").add({
        to: stationOwnerId,
        title: "New Booking",
        message: `New booking request from ${booking.userName} at ${booking.stationName}`,
        bookingId,
        stationId: booking.stationId,
        status: "unread",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 🔹 Send FCM (data-only, no "notification" block)
      if (token) {
        await fcm.send({
          token,
          data: {
            notifId: notifRef.id,
            bookingId,
            stationId: booking.stationId,
            title: "New Booking Request",
            message: `From ${booking.userName} at ${booking.stationName}`,
            type: "booking_new",
          },
        });
      }

    } catch (err) {
      console.error("❌ Error notifying station owner:", err);
    }
  }
);


// 2️⃣ Station Owner → EV Owner (Booking Status Update)
// Stored in `notifications_to_send`
export const notifyEvOwnerOnBookingStatus = onDocumentUpdated(
  "bookings/{bookingId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!after) return;

    // Only trigger if status changed
    if (before?.status === after.status) return;

    const bookingId = event.params.bookingId;
    const evOwnerId = after.userId;

    let title = "Booking Update";
    let message = "";

    if (after.status === "accepted") {
      message = "Your booking has been accepted!";
    } else if (after.status === "rejected") {
      message = "Your booking has been rejected.";
    } else if (after.status === "cancelled") {
      message = "Your booking has been cancelled.";
    } else {
      return;
    }

    try {
      const userSnap = await db.collection("users").doc(evOwnerId).get();
      const token = userSnap.data()?.fcmToken;

      // 🔹 Store in notifications_to_send collection
      const notifRef = await db.collection("notifications_to_send").add({
        to: evOwnerId,
        title,
        message,
        bookingId,
        stationId: after.stationId,
        bookingStatus: after.status,
        status: "unread",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 🔹 Send FCM (data-only)
      if (token) {
        await fcm.send({
          token,
          data: {
            notifId: notifRef.id,
            bookingId,
            stationId: after.stationId,
            title,
            message,
            bookingStatus: after.status,
            type: "booking_update",
          },
        });
      }

    } catch (err) {
      console.error("❌ Error notifying EV owner:", err);
    }
  }
);
