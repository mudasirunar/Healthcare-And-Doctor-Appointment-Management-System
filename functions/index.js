const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Triggers on any new notification document created in Cloud Firestore.
 * Automatically resolves the recipient user's device FCM Token and
 * dispatches native iOS (APNs) and Android push notifications.
 */
exports.sendPushNotification = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data) return null;

    const targetUserId = data.userId;
    const title = data.title || "MediCare Update";
    const body = data.body || "";
    const type = data.type || "general";
    const targetId = data.targetId || data.appointmentId || "";

    if (!targetUserId) {
      console.log("No recipient userId specified, skipping push.");
      return null;
    }

    try {
      // 1. Fetch recipient's FCM Device Push Token from Firestore
      const userDoc = await admin.firestore().collection("users").doc(targetUserId).get();
      if (!userDoc.exists) {
        console.log(`Recipient user ${targetUserId} not found in Firestore.`);
        return null;
      }

      const fcmToken = userDoc.data()?.fcmToken;
      if (!fcmToken) {
        console.log(`No active FCM token registered for user ${targetUserId}.`);
        return null;
      }

      // 2. Build multi-platform push payload (Optimized for iOS APNs & Android)
      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: String(type),
          targetId: String(targetId),
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          payload: `user_notification:${type}:${targetId}`,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "healthcare_appointment_channel",
            sound: "default",
            priority: "max",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              badge: 1,
              sound: "default",
              contentAvailable: true,
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      console.log(`Push notification sent successfully to ${targetUserId}:`, response);
      return response;
    } catch (error) {
      console.error(`Error sending push notification to user ${targetUserId}:`, error);
      return null;
    }
  });

/**
 * Sends push alerts to administrators when new appointments are booked
 */
exports.sendAdminAppointmentAlert = functions.firestore
  .document("appointments/{appointmentId}")
  .onCreate(async (snap, context) => {
    const apt = snap.data();
    if (!apt) return null;

    const patientName = apt.patientName || "A patient";
    const doctorName = apt.doctorName || "Doctor";
    const appointmentId = context.params.appointmentId;

    try {
      const message = {
        topic: "admin_notifications",
        notification: {
          title: "New Appointment Request",
          body: `${patientName} booked a consultation with ${doctorName}.`,
        },
        data: {
          type: "admin_appointment",
          targetId: String(appointmentId),
          payload: `admin_appointment:${appointmentId}`,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      console.log("Admin appointment push alert sent successfully:", response);
      return response;
    } catch (error) {
      console.error("Error sending admin appointment push alert:", error);
      return null;
    }
  });

