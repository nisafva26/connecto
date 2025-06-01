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
  const { chatId, friendId, friendName, vibrationPattern , userId } = data;

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
  const invitees = gathering.invitees ?? {};
  const fcmTokens = [];

  for (const [uid, info] of Object.entries(invitees)) {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const token = userDoc.data()?.fcmToken;
    if (token) fcmTokens.push(token);
  }

  const message = {
    notification: {
      title: `You're invited to ${gathering.name}`,
      body: `Event at ${gathering.location?.name ?? 'a location'} on ${new Date(gathering.dateTime._seconds * 1000).toLocaleString()}`
    },
    data: {
      type: "gathering",
      gatheringId: gatheringId,
    },
    tokens: fcmTokens
  };

  const responses = await Promise.all(
    fcmTokens.map(token =>
      admin.messaging().send({
        notification: message.notification,
        data: message.data,
        token: token,
      }).then(() => ({ token, success: true }))
        .catch(err => ({ token, success: false, error: err.message }))
    )
  );

  console.log("FCM Send Results:", responses);

  return { success: true, sent: fcmTokens.length };
});


