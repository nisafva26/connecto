/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });


const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

//// 1. Confirm Gathering When At Least One Invitee Accepts
exports.confirmGatheringOnInvite = functions.firestore
  .document("gatherings/{gatheringId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (after.status !== "upcoming") return null;

    const invitees = after.invitees || {};
    const hasAccepted = Object.values(invitees).some(i => i.status === "accepted");

    if (hasAccepted) {
      await change.after.ref.update({ status: "confirmed" });
    }

    return null;
  });

//// 2. Start Tracking 1 Hour Before Event
// exports.startTrackingGathering = functions.pubsub
//   .schedule("every 5 minutes")
//   .onRun(async () => {
//     const now = admin.firestore.Timestamp.now();
//     const snapshot = await db
//       .collection("gatherings")
//       .where("status", "==", "confirmed")
//       .get();

//     snapshot.forEach(doc => {
//       const data = doc.data();
//       const trackingStart = new Date(data.dateTime.toDate());
//       trackingStart.setHours(trackingStart.getHours() - 1);

//       if (now.toDate() >= trackingStart) {
//         doc.ref.update({ status: "tracking" });
//       }
//     });

//     return null;
//   });

exports.startTrackingGathering = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const gatheringsRef = admin.firestore().collection("gatherings");

    const snapshot = await gatheringsRef
      .where("status", "==", "confirmed")
      .get();

    snapshot.forEach(async (doc) => {
      const gathering = doc.data();
      const gatheringId = doc.id;

      const trackingStartTime = new Date(gathering.dateTime.toDate());
      trackingStartTime.setHours(trackingStartTime.getHours() - 1); // 1 hour before event

      if (now.toDate() >= trackingStartTime) {
        // 1. Update the status
        await doc.ref.update({ status: "tracking" });

        // 2. Add to activeGatherings if not already there
        const activeRef = admin.firestore().collection("activeGatherings").doc(gatheringId);
        const activeDoc = await activeRef.get();

        if (!activeDoc.exists) {
          await activeRef.set({
            status: "tracking",
            location: gathering.location, // Add lat/lng for arrival check
            name: gathering.name,
            participants: {} // We'll add participants as they start sending location
          });
        }
      }
    });

    return null;
  });


//// 3. Activate Gathering At Event Time
exports.activateGathering = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db
      .collection("gatherings")
      .where("status", "==", "tracking")
      .where("dateTime", "<=", now)
      .get();

    snapshot.forEach(doc => {
      doc.ref.update({ status: "active" });
    });

    return null;
  });

//// 4. Send Push Notification When Tracking Starts
exports.sendTrackingNotification = functions.firestore
  .document("gatherings/{gatheringId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status !== "tracking" && after.status === "tracking") {
      const invitees = Object.keys(after.invitees || {});
      for (const uid of invitees) {
        await sendPushNotification(uid, `📍 Tracking started for ${after.name}`);
      }
    }

    return null;
  });

//// 5. Callable Function: Update User Live Location
exports.updateUserLocation = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated");

  const { gatheringId, lat, lng } = data;
  const userId = context.auth.uid;

  const ref = db.collection("activeGatherings").doc(gatheringId);

  await ref.set({
    participants: {
      [userId]: {
        lat,
        lng,
        lastUpdated: admin.firestore.Timestamp.now(),
      }
    }
  }, { merge: true });

  return { success: true };
});

//// 6. Notify When User Reaches Venue (Every 5 Min)
exports.checkUserArrival = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const snapshot = await db.collection("activeGatherings")
      .where("status", "==", "tracking")
      .get();

    snapshot.forEach(doc => {
      const data = doc.data();
      const venue = data.location;
      const participants = data.participants;

      for (const uid in participants) {
        const p = participants[uid];
        if (p.lat && p.lng && venue) {
          const distance = getDistance(venue, p);
          if (distance < 100) {
            sendPushNotification(uid, "🎉 You have arrived at the venue!");
          }
        }
      }
    });

    return null;
  });

// Helper to calculate haversine distance in meters
function getDistance(loc1, loc2) {
  const R = 6371e3;
  const φ1 = loc1.lat * Math.PI/180;
  const φ2 = loc2.lat * Math.PI/180;
  const Δφ = (loc2.lat - loc1.lat) * Math.PI/180;
  const Δλ = (loc2.lng - loc1.lng) * Math.PI/180;

  const a =
    Math.sin(Δφ/2) ** 2 +
    Math.cos(φ1) * Math.cos(φ2) *
    Math.sin(Δλ/2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

  return R * c;
}

// Dummy Push Notification Sender
async function sendPushNotification(userId, message) {
  console.log(`Sending to ${userId}: ${message}`);
}
