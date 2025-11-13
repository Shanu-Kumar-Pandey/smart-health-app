import functions from 'firebase-functions';
import admin from 'firebase-admin';

// Initialize Admin SDK only once
try {
  admin.app();
} catch (e) {
  admin.initializeApp();
}

const db = admin.firestore();
const messaging = admin.messaging();

// Helper: compute if a given minute-of-day is within window and aligned to interval
function isDueNow(totalMinutes, startTotal, endTotal, interval) {
  if (interval <= 0) return false;
  if (startTotal === endTotal) {
    // single time per day
    return totalMinutes === startTotal;
  }
  if (endTotal > startTotal) {
    // normal window
    if (totalMinutes < startTotal || totalMinutes > endTotal) return false;
    return ((totalMinutes - startTotal) % interval) === 0;
  } else {
    // wraps midnight: start..1439 and 0..end
    if (totalMinutes >= startTotal) {
      return ((totalMinutes - startTotal) % interval) === 0;
    } else if (totalMinutes <= endTotal) {
      const distance = (24 * 60 - startTotal) + totalMinutes;
      return (distance % interval) === 0;
    }
    return false;
  }
}

function pad2(n) { return n.toString().padStart(2, '0'); }

export const sendReminderPushes = functions.pubsub.schedule('* * * * *').onRun(async () => {
  const nowUtc = new Date();
  const snapshot = await db.collection('reminder')
    .where('enabled', '==', true)
    .get();

  if (snapshot.empty) return null;

  const batch = db.batch();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const token = data.fcmToken;
    const name = data.name || 'Reminder';
    const startHour = Number(data.startHour ?? 8);
    const startMinute = Number(data.startMinute ?? 0);
    const endHour = Number(data.endHour ?? 20);
    const endMinute = Number(data.endMinute ?? 0);
    const intervalMinutes = Number(data.intervalMinutes ?? 60);
    const tzOffsetMinutes = Number(data.tzOffsetMinutes ?? 0);

    if (!token) continue;

    // Compute user's local time using stored tz offset (minutes from UTC)
    // nowUtcMinutesOfDay in UTC
    const utcTotal = nowUtc.getUTCHours() * 60 + nowUtc.getUTCMinutes();
    let localTotal = utcTotal + tzOffsetMinutes;
    // Normalize to [0, 1440)
    localTotal = ((localTotal % (24 * 60)) + (24 * 60)) % (24 * 60);

    const startTotal = startHour * 60 + startMinute;
    const endTotal = endHour * 60 + endMinute;

    const due = isDueNow(localTotal, startTotal, endTotal, intervalMinutes);
    if (!due) continue;

    // Dedup by minute key in user local date
    // Build local date for the key too
    const localMillis = nowUtc.getTime() + tzOffsetMinutes * 60 * 1000;
    const localDate = new Date(localMillis);
    const minuteKey = `${localDate.getUTCFullYear()}-${pad2(localDate.getUTCMonth()+1)}-${pad2(localDate.getUTCDate())} ${pad2(localDate.getUTCHours())}:${pad2(localDate.getUTCMinutes())}`;

    if (data.lastMinuteSent === minuteKey) continue; // already sent this minute

    // Send push
    try {
      await messaging.send({
        token,
        notification: {
          title: name,
          body: "It's time!",
        },
        android: {
          notification: {
            channelId: 'hydration_channel',
          },
        },
      });

      // Update lastMinuteSent in batch
      batch.update(doc.ref, {
        lastMinuteSent: minuteKey,
        lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Log and continue
      console.error('FCM send error for reminder', doc.id, e);
    }
  }

  await batch.commit();
  return null;
});
