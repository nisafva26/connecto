/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

// exports.helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });


const functions = require("firebase-functions");
const admin = require("firebase-admin");

const axios = require("axios");

admin.initializeApp();
const db = admin.firestore();

// v2 (use this for the new callable with `secrets`, etc.)
const { onCall } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");

// optional defaults for ALL v2 funcs (does not affect v1)
setGlobalOptions({ region: "us-central1", timeoutSeconds: 60, memoryMiB: 512 });

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
          // await activeRef.set({
          //   status: "tracking",
          //   location: gathering.location, // Add lat/lng for arrival check
          //   name: gathering.name,
          //   participants: {} // We'll add participants as they start sending location
          // });
          await activeRef.set({
            status: "tracking",
            dateTime: gathering.dateTime,       // ✅ Required for reminders
            location: gathering.location,        // ✅ Required for ETA & arrival
            name: gathering.name,                // ✅ Used in all notifications
            hostId: gathering.hostId,            // ✅ For arrival alerts
            reminderSent: false,                 // ✅ Used in reminder check
            participants: {}                     // Add participants later
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
// exports.checkUserArrival = functions.pubsub
//   .schedule("every 5 minutes")
//   .onRun(async () => {
//     const snapshot = await db.collection("activeGatherings")
//       .where("status", "==", "tracking")
//       .get();

//     snapshot.forEach(doc => {
//       const data = doc.data();
//       const venue = data.location;
//       const participants = data.participants;

//       for (const uid in participants) {
//         const p = participants[uid];
//         if (p.lat && p.lng && venue) {
//           const distance = getDistance(venue, p);
//           if (distance < 100) {
//             sendPushNotification(uid, "🎉 You have arrived at the venue!");
//           }
//         }
//       }
//     });

//     return null;
//   });

// Helper to calculate haversine distance in meters
function getDistance(loc1, loc2) {
  const R = 6371e3;
  const φ1 = loc1.lat * Math.PI / 180;
  const φ2 = loc2.lat * Math.PI / 180;
  const Δφ = (loc2.lat - loc1.lat) * Math.PI / 180;
  const Δλ = (loc2.lng - loc1.lng) * Math.PI / 180;

  const a =
    Math.sin(Δφ / 2) ** 2 +
    Math.cos(φ1) * Math.cos(φ2) *
    Math.sin(Δλ / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c;
}

// Dummy Push Notification Sender
async function sendPushNotification(userId, message) {
  console.log(`Sending to ${userId}: ${message}`);
}



//version 2

function getBondId(uid1, uid2) {
  return [uid1, uid2].sort().join("_");
}

async function updateBondPoints({ bondId, userId, type, basePoints, bonusMultiplier = 1, otherUserId, text = null, }) {
  const bondRef = db.collection("bonds").doc(bondId);
  const now = admin.firestore.Timestamp.now();
  const totalPointsToAdd = basePoints * bonusMultiplier;

  const bondSnap = await bondRef.get();

  if (!bondSnap.exists) {
    // Bond does not exist — initialize both users
    await bondRef.set({
      userPoints: {
        [userId]: 0,
        [otherUserId]: 0,
      },
      totalPoints: 0,
      level: 1,
      nextLevelThreshold: 1000,
    });
  } else {
    // Bond exists — ensure both userPoints keys exist
    const data = bondSnap.data();
    const userPoints = data.userPoints || {};

    const userPointPatches = {};
    if (!(userId in userPoints)) {
      userPointPatches[userId] = 0;
    }
    if (!(otherUserId in userPoints)) {
      userPointPatches[otherUserId] = 0;
    }

    if (Object.keys(userPointPatches).length > 0) {
      await bondRef.set({
        userPoints: userPointPatches
      }, { merge: true });
    }
  }

  // Increment points for this user
  await bondRef.update({
    [`userPoints.${userId}`]: admin.firestore.FieldValue.increment(totalPointsToAdd),
    totalPoints: admin.firestore.FieldValue.increment(totalPointsToAdd),
  });

  // Log activity
  await bondRef.collection("activities").add({
    type,
    userId,
    text,
    value: totalPointsToAdd,
    bonus: bonusMultiplier > 1 ? bonusMultiplier : null,
    createdAt: now,
  });

  // Recalculate level and next threshold
  const updatedSnap = await bondRef.get();
  const totalPoints = updatedSnap.data().totalPoints || 0;

  const thresholds = [0, 1000, 3000, 6000, 10000, 15000];
  let level = 1;
  let next = 1000;

  for (let i = 0; i < thresholds.length; i++) {
    if (totalPoints >= thresholds[i]) {
      level = i + 1;
      next = thresholds[i + 1] || null;
    }
  }

  await bondRef.update({
    level,
    nextLevelThreshold: next,
  });
}



exports.onPingSent = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    if (!data || !data.pingPattern) return; // only react to ping messages

    const { senderId, receiverId } = data;
    const bondId = getBondId(senderId, receiverId);
    const bondRef = db.collection("bonds").doc(bondId);
    const now = admin.firestore.Timestamp.now();

    const bondSnap = await bondRef.get();
    let streak = bondSnap.exists && bondSnap.data().streak?.ping || {};
    let multiplier = 1;

    if (streak.lastSentAt) {
      const diff = now.toDate() - streak.lastSentAt.toDate();
      if (diff < 1000 * 60 * 60 * 24) {
        streak.count = (streak.count || 1) + 1;
        multiplier = Math.min(1 + streak.count, 5); // max x5
      } else {
        streak = { count: 1, multiplier: 1 };
      }
    } else {
      streak = { count: 1, multiplier: 1 };
    }

    streak.lastSentAt = now;

    await bondRef.set({ "streak.ping": streak }, { merge: true });

    await updateBondPoints({
      bondId,
      userId: senderId,
      type: "ping",
      basePoints: 5,
      bonusMultiplier: multiplier,
      otherUserId: receiverId,
      text: data.text || null,
    });
  });


exports.onGatheringCreated = functions.firestore
  .document("gatherings/{gatheringId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const hostId = data.hostId;
    const invitees = Object.keys(data.invitees || {});
    for (const inviteeId of invitees) {
      if (inviteeId !== hostId) {
        const bondId = getBondId(hostId, inviteeId);
        await updateBondPoints({ bondId, userId: hostId, type: "gathering_created", basePoints: 15, otherUserId: inviteeId });
      }
    }
  });

exports.onOnTimeArrival = functions.firestore
  .document("activeGatherings/{gatheringId}/participants/{userId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    const beforeStatus = before.arrivalStatus ?? null;
    const afterStatus = after.arrivalStatus ?? null;

    if (beforeStatus === "on_time" || afterStatus !== "on_time") return;
    if (afterStatus !== "on_time") return;

    const gatheringSnap = await db.collection("gatherings").doc(context.params.gatheringId).get();
    const gathering = gatheringSnap.data();
    const hostId = gathering.hostId;
    const userId = context.params.userId;

    const invitees = Object.keys(gathering.invitees || {});

    for (const inviteeId of invitees) {
      if (inviteeId !== userId) {
        const bondId = getBondId(userId, inviteeId);
        await updateBondPoints({
          bondId,
          userId,
          type: "on_time_arrival",
          basePoints: 15,
          otherUserId: inviteeId
        });
      }
    }

  });

exports.evaluateBadges = functions.firestore
  .document("bonds/{bondId}/activities/{activityId}")
  .onCreate(async (snap, context) => {
    const activity = snap.data();
    const bondId = context.params.bondId;
    const userId = activity.userId;
    const bondRef = db.collection("bonds").doc(bondId);

    const activitiesSnap = await bondRef
      .collection("activities")
      .where("userId", "==", userId)
      .get();

    const activities = activitiesSnap.docs.map((doc) => doc.data());

    const pingCount = activities.filter((a) => a.type === "ping").length;
    const gatherCount = activities.filter((a) => a.type === "gathering_created").length;
    const onTimeCount = activities.filter((a) => a.type === "on_time_arrival").length;

    // NEW: Good morning ping count
    const goodMorningCount = activities.filter(
      (a) =>
        a.type === "ping" &&
        a.text &&
        typeof a.text === "string" &&
        a.text.toLowerCase().includes("good morning")
    ).length;

    const badgeSet = new Set();
    const progress = {};

    if (pingCount >= 10) badgeSet.add("fast_responder");
    if (gatherCount >= 3) badgeSet.add("event_planner");
    if (onTimeCount >= 3) badgeSet.add("always_on_time");
    if (goodMorningCount >= 20) badgeSet.add("mr_caring");
    progress["mr_caring"] = { count: goodMorningCount, required: 20 };

    progress["fast_responder"] = { count: pingCount, required: 10 };
    progress["event_planner"] = { count: gatherCount, required: 3 };
    progress["always_on_time"] = { count: onTimeCount, required: 3 };

    await bondRef.set(
      {
        [`badges.${userId}`]: Array.from(badgeSet),
        [`badgeProgress.${userId}`]: progress,
      },
      { merge: true }
    );
  });


exports.resetPingStreaks = functions.pubsub.schedule("every 24 hours").onRun(async () => {
  const snapshot = await db.collection("bonds").get();
  const now = Date.now();

  for (const doc of snapshot.docs) {
    const bond = doc.data();
    const lastPing = bond.streak?.ping?.lastSentAt?.toDate();
    if (lastPing && now - lastPing.getTime() > 1000 * 60 * 60 * 24) {
      await doc.ref.update({ "streak.ping": { count: 0, multiplier: 1, lastSentAt: null } });
    }
  }
});

exports.checkOnTimeArrival = functions.pubsub.schedule("every 5 minutes").onRun(async () => {
  const now = new Date();
  const snapshot = await db.collection("activeGatherings").get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const eventId = doc.id;
    const eventTime = data.dateTime ? data.dateTime.toDate() : null;
    if (!eventTime || !data.location) continue;

    const timeDiff = Math.abs(now - eventTime) / 60000;
    if (timeDiff > 15) continue;

    const participantsRef = db.collection("activeGatherings").doc(eventId).collection("participants");
    const participantsSnap = await participantsRef.get();

    for (const pDoc of participantsSnap.docs) {
      const pdata = pDoc.data();
      if (pdata.arrivalStatus) continue;
      if (!pdata.lat || !pdata.lng) continue;

      const distance = getDistance(pdata, data.location);
      if (distance < 100) {
        await pDoc.ref.update({ arrivalStatus: "on_time" });

        // const gatheringSnap = await db.collection("gatherings").doc(eventId).get();

      }
    }
  }
});

const firestore = admin.firestore();

// Scheduled function to run every 30 minutes
exports.updateEndedGatherings = functions.pubsub
  .schedule('every 30 minutes')
  .onRun(async (context) => {
    const now = new Date();

    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(now.getTime() - 60 * 60 * 1000) // 1 hour ago
    );

    try {
      // Fetch gatherings whose dateTime is < now and status is still 'upcoming' or 'confirmed' or 'tracking'
      const snapshot = await firestore
        .collection('gatherings')
        .where('status', 'in', ['upcoming', 'confirmed', 'tracking', 'active'])
        .where('dateTime', '<=', cutoff)
        .get();

      if (snapshot.empty) {
        console.log('No gatherings to update.');
        return null;
      }

      const batch = firestore.batch();

      snapshot.forEach((doc) => {
        const gatheringRef = firestore.collection('gatherings').doc(doc.id);
        batch.update(gatheringRef, { status: 'ended' });
      });

      await batch.commit();
      console.log(`Updated ${snapshot.size} gatherings to 'ended'`);
    } catch (error) {
      console.error('Error updating ended gatherings:', error);
    }

    return null;
  });



// send notification
exports.sendPingNotification = functions.https.onCall(async (data, context) => {
  const { chatId, friendId, friendName, vibrationPattern, userId } = data;

  if (!chatId || !friendId || !friendName || !vibrationPattern) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing one or more required fields."
    );
  }

  try {
    const userDoc = await admin.firestore().collection("users").doc(friendId).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Friend not found");
    }

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      throw new functions.https.HttpsError("failed-precondition", "User has no FCM token");
    }

    const message = {
      token: fcmToken,
      data: {
        type: "ping",
        vibrationPattern: vibrationPattern,
        chatId: chatId,
        friendId: userId,
        friendName: friendName,
      },
      notification: {
        title: "Ping!",
        body: `${friendName} sent you a ping!`,
      },
      android: {
        priority: "high",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: "Ping!",
              body: `${friendName} sent you a ping!`
            },
            sound: "default",
          },
        },
      },
    };

    await admin.messaging().send(message);

    return { success: true };
  } catch (error) {
    console.error("❌ Error sending ping:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

// exports.sendGatheringNotification = functions.https.onCall(async (data, context) => {
//   const gatheringId = data.gatheringId;
//   if (!gatheringId) {
//     throw new functions.https.HttpsError("invalid-argument", "Gathering ID is required.");
//   }

//   const gatheringDoc = await admin.firestore().collection("gatherings").doc(gatheringId).get();
//   if (!gatheringDoc.exists) {
//     throw new functions.https.HttpsError("not-found", "Gathering not found.");
//   }

//   const gathering = gatheringDoc.data();
//   const invitees = gathering.invitees ?? {};
//   const fcmTokens = [];

//   for (const [uid, info] of Object.entries(invitees)) {
//     const userDoc = await admin.firestore().collection("users").doc(uid).get();
//     const token = userDoc.data()?.fcmToken;
//     if (token) fcmTokens.push(token);
//   }

//   const message = {
//     notification: {
//       title: `You're invited to ${gathering.name}`,
//       body: `Event at ${gathering.location?.name ?? 'a location'} on ${new Date(gathering.dateTime._seconds * 1000).toLocaleString()}`
//     },
//     data: {
//       type: "gathering",
//       gatheringId: gatheringId,
//     },
//     tokens: fcmTokens
//   };

//   const responses = await Promise.all(
//     fcmTokens.map(token =>
//       admin.messaging().send({
//         notification: message.notification,
//         data: message.data,
//         token: token,
//       }).then(() => ({ token, success: true }))
//         .catch(err => ({ token, success: false, error: err.message }))
//     )
//   );

//   console.log("FCM Send Results:", responses);

//   return { success: true, sent: fcmTokens.length };
// });

// Updated Cloud Function for sending gathering notifications
exports.sendGatheringNotification = functions.https.onCall(async (data, context) => {
  const gatheringId = data.gatheringId;
  if (!gatheringId) {
    throw new functions.https.HttpsError("invalid-argument", "Gathering ID is required.");
  }

  const gatheringDoc = await admin.firestore().collection("gatherings").doc(gatheringId).get();
  if (!gatheringDoc.exists) {
    throw new functions.https.HttpsError("not-found", "Gathering not found.");
  }

  const gathering = gatheringDoc.data();
  const hostId = gathering.hostId;
  const invitees = gathering.invitees ?? {};
  const fcmTokens = [];

  // Format gathering date/time using fixed locale + timezone if needed
  const dateTimeMillis = gathering.dateTime?._seconds
    ? gathering.dateTime._seconds * 1000
    : Date.now();
  const formattedDate = new Date(dateTimeMillis).toLocaleString("en-GB", {
    timeZone: "Asia/Dubai",
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "short",
    year: "numeric",
  });

  // Handle normal invitees
  for (const [uid, info] of Object.entries(invitees)) {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const token = userDoc.data()?.fcmToken;
    if (!token) continue;

    let title, body;
    if (uid === hostId) {
      title = `You created a gathering: ${gathering.name}`;
      body = `Scheduled at ${gathering.location?.name ?? 'a location'} on ${formattedDate}`;
    } else {
      title = `You're invited to ${gathering.name}`;
      body = `Event at ${gathering.location?.name ?? 'a location'} on ${formattedDate}`;
    }

    fcmTokens.push({ token, title, body });
  }

  // If gathering is public, notify other users
  if (gathering.isPublic) {
    const usersSnapshot = await admin.firestore().collection("users").get();
    for (const doc of usersSnapshot.docs) {
      const user = doc.data();
      const uid = doc.id;
      if (fcmTokens.find(t => t.token === user.fcmToken)) continue; // Skip already added tokens
      if (uid === hostId) continue; // Skip host again

      fcmTokens.push({
        token: user.fcmToken,
        title: `New public event: ${gathering.name}`,
        body: `Happening at ${gathering.location?.name ?? 'a location'} on ${formattedDate}`,
      });
    }
  }

  const results = await Promise.all(
    fcmTokens.map(({ token, title, body }) =>
      admin.messaging().send({
        token,
        notification: { title, body },
        data: {
          type: "gathering",
          gatheringId: gatheringId,
        },
      }).then(() => ({ token, success: true }))
        .catch(error => ({ token, success: false, error: error.message }))
    )
  );

  console.log("FCM Send Results:", results);

  return { success: true, sent: results.length, results };
});


exports.sendGroupPingNotification = functions.https.onCall(async (data, context) => {
  const { circleId, messageText, senderId, senderName, vibrationPattern } = data;

  if (!circleId || !messageText || !senderId || !senderName || !vibrationPattern) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Missing one or more required fields."
    );
  }

  try {
    const firestore = admin.firestore();

    // 🔹 Fetch the circle document
    const circleDoc = await firestore.collection("circles").doc(circleId).get();
    if (!circleDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Circle not found.");
    }

    const circleData = circleDoc.data();
    const circleName = circleData.circleName || "your circle";
    const registeredUsers = circleData.registeredUsers || [];

    const fcmTokens = [];

    for (const userId of registeredUsers) {
      if (userId === senderId) continue; // 🔁 Don't notify the sender

      const userDoc = await firestore.collection("users").doc(userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (fcmToken) {
        fcmTokens.push({
          token: fcmToken,
          userId,
        });
      }
    }

    const notification = {
      title: `${senderName} pinged in ${circleName}`,
      body: messageText,
    };

    const dataPayload = {
      type: "groupPing",
      circleId,
      messageText,
      vibrationPattern, // 🟢 Include ping pattern
      senderId,
      senderName,
    };

    // 🔄 Send FCM to each recipient
    const results = await Promise.all(
      fcmTokens.map(({ token }) =>
        admin
          .messaging()
          .send({
            token,
            notification,
            data: dataPayload,
            android: {
              priority: "high",
            },
            apns: {
              headers: {
                "apns-priority": "10",
              },
              payload: {
                aps: {
                  alert: {
                    title: notification.title,
                    body: notification.body,
                  },
                  sound: "default",
                },
              },
            },
          })
          .then(() => ({ token, success: true }))
          .catch((err) => ({ token, success: false, error: err.message }))
      )
    );

    console.log("✅ Group ping notification results:", results);

    return { success: true, sent: fcmTokens.length };
  } catch (error) {
    console.error("❌ Error sending group ping:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

exports.notifyHostOnRSVP = functions.firestore
  .document("gatherings/{gatheringId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const gatheringId = context.params.gatheringId;

    const beforeInvitees = before.invitees || {};
    const afterInvitees = after.invitees || {};

    const hostId = after.hostId;
    if (!hostId) return null;

    for (const [uid, afterInfo] of Object.entries(afterInvitees)) {
      const beforeInfo = beforeInvitees[uid];

      // Skip if no change in status
      if (
        beforeInfo?.status === afterInfo?.status ||
        !["accepted", "declined"].includes(afterInfo?.status)
      ) continue;

      // 🔔 Invitee has responded with accepted/declined
      const inviteeDoc = await admin.firestore().collection("users").doc(uid).get();
      const inviteeName = inviteeDoc.exists ? inviteeDoc.data().fullName ?? "Someone 1" : "Someone 2";

      const hostDoc = await admin.firestore().collection("users").doc(hostId).get();
      const fcmToken = hostDoc.data()?.fcmToken;
      if (!fcmToken) return null;

      const statusText = afterInfo.status === "accepted" ? "accepted" : "declined";

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: `${inviteeName} ${statusText} your invite`,
          body: `For gathering: ${after.name || "your event"}`,
        },
        data: {
          type: "gathering",
          gatheringId: gatheringId,
          inviteeId: uid,
          response: statusText,
        },
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              alert: {
                title: `${inviteeName} ${statusText} your invite`,
                body: `For gathering: ${after.name || "your event"}`,
              },
              sound: "default",
            },
          },
        },
      });

      console.log(`🔔 Sent RSVP ${statusText} notification from ${uid} to host ${hostId}`);
    }

    return null;
  });



// notify host on public join
exports.notifyHostOnPublicJoin = functions.firestore
  .document("gatherings/{gatheringId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const gatheringId = context.params.gatheringId;

    const beforeUsers = before.joinedPublicUsers || {};
    const afterUsers = after.joinedPublicUsers || {};
    const hostId = after.hostId;

    if (!hostId) return null;

    for (const [uid, userInfo] of Object.entries(afterUsers)) {
      const wasThereBefore = beforeUsers[uid];
      const isNew = !wasThereBefore && userInfo.status === 'pending';

      if (!isNew) continue;

      const hostDoc = await admin.firestore().collection('users').doc(hostId).get();
      const fcmToken = hostDoc.data()?.fcmToken;
      if (!fcmToken) continue;

      const name = userInfo.name || "Someone";

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: `${name} requested to join your public event`,
          body: `Tap to review the request for: ${after.name ?? 'your gathering'}`,
        },
        data: {
          type: "gathering",
          gatheringId: gatheringId,
          userId: uid,
        },
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              alert: {
                title: `${name} requested to join your public event`,
                body: `Tap to review the request for: ${after.name ?? 'your gathering'}`,
              },
              sound: "default",
            },
          },
        },
      });

      console.log(`📩 Sent public join request notification from ${uid} to host ${hostId}`);
    }

    return null;
  });


//notiify user on public join

exports.notifyPublicUserOnHostResponse = functions.firestore
  .document("gatherings/{gatheringId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const gatheringId = context.params.gatheringId;

    const beforeUsers = before.joinedPublicUsers || {};
    const afterUsers = after.joinedPublicUsers || {};

    for (const [uid, afterInfo] of Object.entries(afterUsers)) {
      const beforeInfo = beforeUsers[uid];

      if (
        !beforeInfo ||
        beforeInfo.status === afterInfo.status ||
        !["accepted", "declined"].includes(afterInfo.status)
      ) {
        continue;
      }

      const userDoc = await admin.firestore().collection("users").doc(uid).get();
      const fcmToken = userDoc.data()?.fcmToken;
      if (!fcmToken) continue;

      const status = afterInfo.status;
      const gatheringName = after.name || "the event";

      let title = "";
      let body = "";

      if (status === "accepted") {
        title = "🎉 Request Approved!";
        body = `You've been accepted to join "${gatheringName}". See you there!`;
      } else if (status === "declined") {
        title = "Request Declined";
        body = `Your request to join "${gatheringName}" was declined by the host.`;
      }

      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data: {
          type: "gathering",
          gatheringId: gatheringId,
          status,
        },
        android: { priority: "high" },
        apns: {
          headers: { "apns-priority": "10" },
          payload: {
            aps: {
              alert: { title, body },
              sound: "default",
            },
          },
        },
      });

      console.log(`🔔 Sent host response (${status}) to ${uid} for gathering ${gatheringId}`);
    }

    return null;
  });


//   // ------------------ 1. One Hour Before Reminder ------------------
// exports.sendPreEventReminders = functions.pubsub
// .schedule("every 5 minutes")
// .onRun(async () => {
//   const now = new Date();
//   const snapshot = await db.collection("activeGatherings").get();

//   for (const doc of snapshot.docs) {
//     const gatheringId = doc.id;
//     const gatheringRef = db.collection("gatherings").doc(gatheringId);
//     const gatheringSnap = await gatheringRef.get();
//     const gatheringData = gatheringSnap.data();

//     if (!gatheringData?.dateTime) continue;

//     const eventTime = gatheringData.dateTime.toDate();
//     const diffMins = (eventTime - now) / 60000;

//     if (diffMins < 60 && diffMins > 55 && !doc.data().reminderSent) {
//       await notifyParticipants(gatheringId, `🕐 Your event "${gatheringData.name}" starts in 1 hour!`);
//       await doc.ref.update({ reminderSent: true });
//     }
//   }
// });

// // ------------------ 2. Leave Now ETA-based Reminder ------------------
// exports.sendLeaveNowReminders = functions.pubsub
// .schedule("every 5 minutes")
// .onRun(async () => {
//   const now = new Date();
//   const snapshot = await db.collection("activeGatherings").get();

//   for (const doc of snapshot.docs) {
//     const gatheringId = doc.id;
//     const gatheringRef = db.collection("gatherings").doc(gatheringId);
//     const gatheringSnap = await gatheringRef.get();
//     const gatheringData = gatheringSnap.data();

//     if (!gatheringData?.dateTime || !gatheringData?.location) continue;

//     const eventTime = gatheringData.dateTime.toDate();
//     const diffMins = (eventTime - now) / 60000;

//     if (diffMins < 40 && diffMins > 10) {
//       const participantsSnap = await doc.ref.collection("participants").get();
//       for (const userDoc of participantsSnap.docs) {
//         const { lat, lng } = userDoc.data();
//         if (!lat || !lng) continue;

//         const etaMins = await getETA(lat, lng, gatheringData.location.lat, gatheringData.location.lng);
//         if (etaMins && etaMins + 5 >= diffMins) {
//           await notifyUser(userDoc.id, `🚗 Leave now to reach "${gatheringData.name}" on time.`);
//         }
//       }
//     }
//   }
// });

// // ------------------ 3. Arrival Notifications ------------------
// exports.sendArrivalNotifications = functions.pubsub
// .schedule("every 5 minutes")
// .onRun(async () => {
//   const snapshot = await db.collection("activeGatherings").get();

//   for (const doc of snapshot.docs) {
//     const gatheringId = doc.id;
//     const gatheringRef = db.collection("gatherings").doc(gatheringId);
//     const gatheringSnap = await gatheringRef.get();
//     const gatheringData = gatheringSnap.data();

//     const hostId = gatheringData?.hostId;
//     const eventName = gatheringData?.name;
//     const location = gatheringData?.location;
//     if (!eventName || !location?.lat || !location?.lng) continue;

//     const participantsSnap = await doc.ref.collection("participants").get();
//     for (const userDoc of participantsSnap.docs) {
//       const userId = userDoc.id;
//       const data = userDoc.data();
//       if (data.arrived || !data.lat || !data.lng) continue;

//       const distance = getDistanceFromLatLonInMeters(location.lat, location.lng, data.lat, data.lng);
//       if (distance <= 100) {
//         const name = data.name || "A participant";

//         // Mark as arrived
//         await userDoc.ref.update({ arrived: true });

//         // Notify the arriving user
//         await notifyUser(userId, `🎉 You have arrived at "${eventName}"!`);

//         // Notify other participants (excluding current user)
//         for (const otherDoc of participantsSnap.docs) {
//           const otherId = otherDoc.id;
//           if (otherId !== userId) {
//             await notifyUser(otherId, `✅ ${name} has arrived at the event.`);
//           }
//         }

//         // Notify the host (if not the one who arrived)
//         if (hostId && hostId !== userId) {
//           await notifyUser(hostId, `✅ ${name} has arrived at the event.`);
//         }
//       }
//     }
//   }
// });

// ------------------ 1. One Hour Before Reminder ------------------
exports.sendPreEventReminders = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const now = new Date();
    const snapshot = await db
      .collection("gatherings")
      .where("status", "in", ["confirmed", "tracking"])
      .get();

    for (const doc of snapshot.docs) {
      const gatheringId = doc.id;
      const { dateTime, name, reminderSent } = doc.data();

      if (!dateTime || reminderSent) continue;

      const eventTime = dateTime.toDate();
      const diffMins = (eventTime - now) / 60000;

      if (diffMins < 60 && diffMins > 55) {
        console.log(`⏰ Sending 1-hour reminder for "${name}" (${gatheringId})`);
        await notifyParticipants(gatheringId, `🕐 Your event "${name}" starts in 1 hour!`, "reminder");
        await doc.ref.update({ reminderSent: true });
      }
    }
  });

// ------------------ 2. Leave Now ETA-based Reminder ------------------
exports.sendLeaveNowReminders = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const now = new Date();
    const snapshot = await db
      .collection("gatherings")
      .where("status", "in", ["confirmed", "tracking"])
      .get();

    for (const doc of snapshot.docs) {
      const gatheringId = doc.id;
      const { dateTime, name, location } = doc.data();
      if (!dateTime || !location) continue;

      const eventTime = dateTime.toDate();
      const diffMins = (eventTime - now) / 60000;

      if (diffMins < 40 && diffMins > 10) {
        const participantsSnap = await db.collection("gatherings").doc(gatheringId).collection("invitees").get();

        for (const userDoc of participantsSnap.docs) {
          const { lat, lng } = userDoc.data();
          if (!lat || !lng) continue;

          const etaMins = await getETA(lat, lng, location.lat, location.lng);
          if (etaMins && etaMins + 5 >= diffMins) {
            console.log(`🚗 Sending leave-now to ${userDoc.id} for "${name}"`);
            await notifyUser(userDoc.id, `🚗 Leave now to reach "${name}" on time.`, gatheringId, "leave_now");
          }
        }
      }
    }
  });

// ------------------ 3. Arrival Notifications ------------------
exports.sendArrivalNotifications = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const snapshot = await db
      .collection("gatherings")
      .where("status", "==", "tracking")
      .get();

    for (const doc of snapshot.docs) {
      const gatheringId = doc.id;
      const { hostId, name, location } = doc.data();
      if (!name || !location?.lat || !location?.lng) continue;

      const participantsSnap = await db.collection("gatherings").doc(gatheringId).collection("invitees").get();

      for (const userDoc of participantsSnap.docs) {
        const userId = userDoc.id;
        const data = userDoc.data();
        if (data.arrived || !data.lat || !data.lng) continue;

        const distance = getDistanceFromLatLonInMeters(location.lat, location.lng, data.lat, data.lng);
        if (distance <= 100) {
          const displayName = data.name || "A participant";

          console.log(`🎯 ${displayName} has arrived at "${name}"`);

          await userDoc.ref.update({ arrived: true });

          await notifyUser(userId, `🎉 You have arrived at "${name}"!`, gatheringId, "arrival");

          for (const otherDoc of participantsSnap.docs) {
            const otherId = otherDoc.id;
            if (otherId !== userId) {
              await notifyUser(otherId, `✅ ${displayName} has arrived at the event.`, gatheringId, "arrival");
            }
          }

          if (hostId && hostId !== userId) {
            await notifyUser(hostId, `✅ ${displayName} has arrived at the event.`, gatheringId, "arrival");
          }
        }
      }
    }
  });

exports.sendArrivalNotificationsGathering = functions.firestore
  .document('gatherings/{gatheringId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const previousData = change.before.data();
    const { gatheringId } = context.params;

    const newInvitees = newData.invitees || {};
    const oldInvitees = previousData.invitees || {};

    let arrivingUser = null;
    let arrivingUserId = null;

    // Iterate through invitees to find the one who just arrived
    for (const userId in newInvitees) {
      if (newInvitees[userId].arrivalStatus === 'arrived' && oldInvitees[userId]?.arrivalStatus !== 'arrived') {
        arrivingUser = newInvitees[userId];
        arrivingUserId = userId;
        break;
      }
    }

    // If no new arrival is found, exit
    if (!arrivingUser) {
      return null;
    }
    
    // Use the event location name for a more useful notification
    const locationName = newData.location?.name || 'the event location'; 
    const displayName = arrivingUser.name || "A participant";

    console.log(`🎯 ${displayName} has arrived at "${locationName}"`);

    // Send notifications to all other invitees
    for (const otherId in newInvitees) {
      if (otherId !== arrivingUserId) {
        await notifyUser(otherId, `✅ ${displayName} has arrived at "${locationName}".`, gatheringId, "arrival");
      }
    }
    
    // Notify the user who just arrived
    await notifyUser(arrivingUserId, `🎉 You have arrived at "${locationName}"!`, gatheringId, "arrival");
    
    return null;
  });


// // ------------------ Utility Functions ------------------


async function notifyParticipants(gatheringId, message, status = "reminder") {
  const participantsSnap = await db.collection("gatherings").doc(gatheringId).collection("invitees").get();
  for (const userDoc of participantsSnap.docs) {
    await notifyUser(userDoc.id, message, gatheringId, status);
  }
}

async function notifyUser(userId, body, gatheringId = "", status = "reminder") {
  const userSnap = await db.collection("users").doc(userId).get();
  const fcmToken = userSnap.data()?.fcmToken;
  if (!fcmToken) return;

  let title = "📍 Connecto";
  switch (status) {
    case "reminder":
      title = "⏰ Upcoming Event Reminder";
      break;
    case "leave_now":
      title = "🚗 Time to Leave!";
      break;
    case "arrival":
      title = "🎉 Arrival Update";
      break;
    default:
      title = "📍 Connecto";
  }

  await admin.messaging().send({
    token: fcmToken,
    notification: { title, body },
    data: {
      type: "gathering",
      gatheringId,
      status,
    },
    android: { priority: "high" },
    apns: {
      headers: { "apns-priority": "10" },
      payload: {
        aps: {
          alert: { title, body },
          sound: "default",
        },
      },
    },
  });
}




// async function notifyParticipants(gatheringId, message) {
// const participantsSnap = await db.collection("activeGatherings").doc(gatheringId).collection("participants").get();
// for (const userDoc of participantsSnap.docs) {
//   await notifyUser(userDoc.id, message);
// }
// }

// async function notifyUser(userId, message) {
// const userRef = await db.collection("users").doc(userId).get();
// const token = userRef.data()?.fcmToken;
// if (!token) return;

// await admin.messaging().send({
//   token,
//   notification: {
//     title: "📍 Gathering Alert",
//     body: message,
//   },
//   data: {
//     type: "gathering_reminder"
//   }
// });
// }

async function getETA(fromLat, fromLng, toLat, toLng) {
  try {
    const MAPBOX_TOKEN = await functions.config().mapbox.token;
    const res = await axios.get(`https://api.mapbox.com/directions/v5/mapbox/driving/${fromLng},${fromLat};${toLng},${toLat}`, {
      params: {
        access_token: MAPBOX_TOKEN
      }
    });
    const durationSec = res.data.routes[0].duration;
    return Math.round(durationSec / 60);
  } catch (err) {
    console.error("Mapbox ETA error:", err);
    return null;
  }
}

function getDistanceFromLatLonInMeters(lat1, lon1, lat2, lon2) {
  function deg2rad(deg) {
    return deg * (Math.PI / 180);
  }

  const R = 6371000; // meters
  const dLat = deg2rad(lat2 - lat1);
  const dLon = deg2rad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}


exports.notifyAdminsOnAccessRequest = functions.firestore
  .document("accessRequests/{phone}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    if (!data?.phoneNumber || !data?.fullName || !data?.email) return;

    // Save to centralized admin notification collection
    await db.collection("notifications_admin").add({
      type: "accessRequest",
      requesterPhone: data.phoneNumber,
      fullName: data.fullName,
      email: data.email,
      status: "pending",
      requestedAt: data.requestedAt || admin.firestore.FieldValue.serverTimestamp(),
    });

    // List of hardcoded admin phone numbers
    const adminPhoneNumbers = ["+971559533272", "+916282745946"];

    const tokens = [];

    // Fetch FCM tokens from users collection
    for (const phone of adminPhoneNumbers) {
      const userQuery = await db.collection("users").where("phoneNumber", "==", phone).get();
      if (!userQuery.empty) {
        const userDoc = userQuery.docs[0];
        const token = userDoc.data().fcmToken;
        console.log(`✅ Found FCM token for ${phone}: ${token}`);
        if (token) tokens.push(token);
      } else {
        console.log(`❌ No user found for phone: ${phone}`);
      }
    }
    

    // Send FCM if tokens exist
    if (tokens.length > 0) {
      const payload = {
        notification: {
          title: "🔐 New Access Request",
          body: `${data.fullName} requested access to Connecto`,
        },
        data: {
          type: "accessRequest",
          phoneNumber: data.phoneNumber,
        },
      };

      await admin.messaging().sendEachForMulticast({
        tokens,
        ...payload,
      });

      console.log('FCM response:', JSON.stringify(response));
    }
  });






  // poll functions 

  /** pick a winner id from a {id: count} map (tie → alphabetical) */
function pickWinner(counts) {
  let max = -1;
  let candidates = [];
  for (const [id, v] of Object.entries(counts || {})) {
    if (v > max) {
      max = v;
      candidates = [id];
    } else if (v === max) {
      candidates.push(id);
    }
  }
  if (candidates.length === 0) return null;
  if (candidates.length === 1) return candidates[0];
  return candidates.sort()[0];
}

/** idempotent transactional close */
async function closePollTX(circleId, pollId) {
  const pollRef = db.doc(`circles/${circleId}/polls/${pollId}`);
  const msgQuery = db
    .collection(`groupChats/${circleId}/messages`)
    .where("type", "==", "poll")
    .where("pollId", "==", pollId)
    .limit(1);

  await db.runTransaction(async (tx) => {
    const pollSnap = await tx.get(pollRef);
    if (!pollSnap.exists) return;
    const poll = pollSnap.data();
    if (poll.status === "closed") return; // already closed

    const countsLoc = (poll.counts && poll.counts.location) || {};
    const countsTim = (poll.counts && poll.counts.time) || {};

    const locationId = pickWinner(countsLoc);
    const timeSlotId = pickWinner(countsTim);

    tx.update(pollRef, {
      status: "closed",
      closedAt: admin.firestore.FieldValue.serverTimestamp(),
      "winners.locationId": locationId || null,
      "winners.timeSlotId": timeSlotId || null,
    });

    const msgSnap = await tx.get(msgQuery);
    if (!msgSnap.empty) {
      tx.update(msgSnap.docs[0].ref, { pollStatus: "closed" });
    }
  });
}

/** ------------ triggers ------------ **/

// On vote write: update counts + check early close
exports.onVoteWrite = functions.firestore
  .document("circles/{circleId}/polls/{pollId}/votes/{uid}")
  .onWrite(async (change, context) => {
    const { circleId, pollId } = context.params;
    const pollRef = db.doc(`circles/${circleId}/polls/${pollId}`);

    // if vote doc was deleted, do nothing (keep it simple)
    if (!change.after.exists) return;

    const before = change.before.exists ? change.before.data() : null;
    const after  = change.after.data();

    const prevLoc = before && before.selectedLocationId;
    const nextLoc = after  && after.selectedLocationId;
    const prevTim = before && before.selectedTimeSlotId;
    const nextTim = after  && after.selectedTimeSlotId;

    const pollSnap = await pollRef.get();
    if (!pollSnap.exists) return;
    const poll = pollSnap.data();
    if (poll.status !== "open") return;

    // update counts inside a TX (only when changed)
    await db.runTransaction(async (tx) => {
      const fresh = await tx.get(pollRef);
      if (!fresh.exists) return;
      const p = fresh.data();
      if (p.status !== "open") return;

      const loc = (p.counts && p.counts.location) || {};
      const tim = (p.counts && p.counts.time) || {};

      // LOCATION
      if (prevLoc && nextLoc && prevLoc !== nextLoc && loc[prevLoc] != null) {
        loc[prevLoc] = Math.max(0, (loc[prevLoc] || 0) - 1);
      }
      if ((!prevLoc && nextLoc) || (prevLoc && nextLoc && prevLoc !== nextLoc)) {
        loc[nextLoc] = (loc[nextLoc] || 0) + 1;
      }

      // TIME
      if (prevTim && nextTim && prevTim !== nextTim && tim[prevTim] != null) {
        tim[prevTim] = Math.max(0, (tim[prevTim] || 0) - 1);
      }
      if ((!prevTim && nextTim) || (prevTim && nextTim && prevTim !== nextTim)) {
        tim[nextTim] = (tim[nextTim] || 0) + 1;
      }

      tx.update(pollRef, {
        "counts.location": loc,
        "counts.time": tim,
      });
    });

    // Early-close: everyone or quorum
    const required = poll.requiredVoters || [];
    const minQuorum = typeof poll.minQuorum === "number" ? poll.minQuorum : null;

    const votesSnap = await db
      .collection(`circles/${circleId}/polls/${pollId}/votes`)
      .get();

    const votedCount =
      required.length > 0
        ? votesSnap.docs.filter((d) => required.includes(d.id)).length
        : votesSnap.size;

    const everyoneVoted = required.length > 0 && votedCount >= required.length;
    const quorumReached =
      minQuorum != null &&
      required.length > 0 &&
      votedCount / required.length >= minQuorum;

    if (everyoneVoted || quorumReached) {
      await closePollTX(circleId, pollId);
    }
  });


// Scheduled auto-close for overdue polls
exports.autoCloseOverduePolls = functions.pubsub
  .schedule("every 5 minutes")
  .onRun(async () => {
    const now = admin.firestore.Timestamp.now();

    const q = await db
      .collectionGroup("polls")
      .where("status", "==", "open")
      .where("closesAt", "<=", now)
      .limit(50)
      .get();

    const tasks = q.docs.map((d) => {
      // d.ref path: circles/{circleId}/polls/{pollId}
      const circleId = d.ref.parent.parent.id; // parent = polls, parent.parent = circles/{circleId}
      const pollId = d.id;
      return closePollTX(circleId, pollId);
    });

    await Promise.all(tasks);
    return null;
  });

// Manual callable (creator-only)
exports.closePollCallable = functions.https.onCall(async (data, context) => {
  const uid = context.auth && context.auth.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "Login required");
  }
  const circleId = data.circleId;
  const pollId = data.pollId;
  if (!circleId || !pollId) {
    throw new functions.https.HttpsError("invalid-argument", "Missing args");
  }

  const pollRef = db.doc(`circles/${circleId}/polls/${pollId}`);
  const snap = await pollRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError("not-found", "Poll not found");
  }
  const poll = snap.data();
  if (poll.createdBy !== uid) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only the poll creator can close the poll"
    );
  }

  await closePollTX(circleId, pollId);
  return { ok: true };
});




const { CloudTasksClient } = require("@google-cloud/tasks");



exports.startReelJob = onCall(
  { secrets: ["REELS_RUN_URL"] },     // ✅ v2 supports secrets
  async (req) => {
    const db = admin.firestore();
    const uid = (req.auth && req.auth.uid) || "system";

    const {
      gatheringId,
      targetSeconds = 60,
      crossfade = 0.5,
      fitMode = "cover",
      maxPerVideo = 5,
    } = req.data || {};
    if (!gatheringId) throw new Error("gatheringId is required");

    const runUrl = process.env.REELS_RUN_URL;
    if (!runUrl) throw new Error("REELS_RUN_URL secret not set");

    // Load media (no orderBy so we don’t need a composite index)
    const qs = await db
      .collection(`gatherings/${gatheringId}/media`)
      .where("status", "==", "active")
      .get();
    if (qs.empty) throw new Error("No active media.");

    const docs = qs.docs.sort((a, b) => {
      const at = a.get("createdAt"), bt = b.get("createdAt");
      const ams = at?.toMillis?.() ?? 0, bms = bt?.toMillis?.() ?? 0;
      return ams - bms; // oldest → newest
    });

    const MAX_ITEMS = 80;
    const clips = [];
    for (const d of docs.slice(0, MAX_ITEMS)) {
      const m = d.data();
      if (!m.storagePath || !m.type) continue;
      clips.push({
        gcsPath: m.storagePath,
        type: m.type,                               // "image" | "video"
        maxLen: m.type === "video" ? Number(maxPerVideo) || 5 : undefined,
      });
    }
    if (!clips.length) throw new Error("No usable clips.");

    // Create job doc (UI watches this)
    const jobRef = db.collection(`gatherings/${gatheringId}/reelsJobs`).doc();
    await jobRef.set({
      status: "queued",
      progress: 0,
      gatheringId,
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetSeconds,
      crossfade,
      fitMode,
    });

    // Ensure Cloud Tasks queue exists, then enqueue
    const project = process.env.GCLOUD_PROJECT || admin.app().options.projectId;
    const location = "us-central1";
    const queueId = "reels-queue";

    const client = new CloudTasksClient();
    const queuePath = client.queuePath(project, location, queueId);

    try {
      await client.getQueue({ name: queuePath });
    } catch (e) {
      if (e && e.code === 5) {
        await client.createQueue({
          parent: client.locationPath(project, location),
          queue: { name: queuePath },
        });
      } else {
        throw new Error(`Cloud Tasks getQueue: ${e.message || e}`);
      }
    }

    const serviceAccountEmail = `${project}@appspot.gserviceaccount.com`;
    const payload = {
      gatheringId,
      targetSeconds,
      crossfade,
      fitMode,
      clips,
      jobDocPath: jobRef.path,               // Cloud Run will write progress here
      video: { width: 1080, height: 1920, fps: 30 },
    };

    const task = {
      httpRequest: {
        httpMethod: "POST",
        url: runUrl,                          // must include /render
        headers: { "Content-Type": "application/json" },
        body: Buffer.from(JSON.stringify(payload)).toString("base64"),
        oidcToken: { serviceAccountEmail },
      },
    };

    await client.createTask({ parent: queuePath, task });
    return { ok: true, jobDocPath: jobRef.path };
  }
);













