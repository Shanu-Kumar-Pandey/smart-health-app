/* eslint-disable no-console */
import 'dotenv/config';
import express from 'express';
import admin from 'firebase-admin';
import cron from 'node-cron';
import { sendAppointmentReminders } from './emailService.js';

// Init Firebase Admin
if (!admin.apps.length) {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    const svc = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    admin.initializeApp({ credential: admin.credential.cert(svc) });
  } else {
    admin.initializeApp(); // expects GOOGLE_APPLICATION_CREDENTIALS
  }
}

const db = admin.firestore();
const messaging = admin.messaging();

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;
const REMINDERS_COLLECTION = process.env.REMINDERS_COLLECTION || 'reminder';

function minutesSinceMidnight(date) {
  return date.getHours() * 60 + date.getMinutes();
}
function toUserLocal(now, tzOffsetMinutes = 0) {
  // Convert server local time to UTC, then apply user's offset minutes.
  // This avoids double-applying the server's own timezone offset.
  const utcMs = now.getTime() + now.getTimezoneOffset() * 60000;
  return new Date(utcMs + (tzOffsetMinutes || 0) * 60000);
}
function isWithinWindow(userLocal, startMins, endMins) {
  const cur = minutesSinceMidnight(userLocal);
  if (startMins <= endMins) return cur >= startMins && cur <= endMins;
  return cur >= startMins || cur <= endMins; // overnight
}
function shouldFireNow(userLocal, startMins, intervalMinutes) {
  const cur = minutesSinceMidnight(userLocal);
  const diff = (cur - startMins + 1440) % 1440;
  return intervalMinutes > 0 && diff % intervalMinutes === 0;
}

async function sendFCM(token, title, body, data = {}) {
  const msg = {
    token,
    notification: { title, body },
    data,
    android: {
      priority: 'high',
      notification: {
        channelId: 'reminder_channel',
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
      },
    },
  };
  return messaging.send(msg);
}

// Health check
app.get('/', (req, res) => res.send('Smart health reminder cron running'));

// Cron to check for appointments every minute
cron.schedule('* * * * *', async () => {
  const nowUtc = new Date();
  const istTime = nowUtc.toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  console.log(`[${istTime}] Checking for appointments...`);
  await sendAppointmentReminders();
});

// Cron every minute for other reminders
cron.schedule('* * * * *', async () => {
  const nowUtc = new Date();
  console.log(`[${nowUtc.toISOString()}] Cron tick`);
  try {
    const snap = await db
      .collection(REMINDERS_COLLECTION)
      .where('enabled', '==', true)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    const sends = [];

    for (const doc of snap.docs) {
      const r = doc.data();
      const {
        fcmToken,
        name,
        message,
        startHour,
        startMinute,
        endHour,
        endMinute,
        intervalMinutes,
        tzOffsetMinutes,
      } = r;
      const token = r.fcmToken || fcmToken;
      const hasToken = !!token;
      if (!hasToken) {
        console.warn(`[${doc.id}] skip: missing fcmToken`);
        continue; // guard
      }
      const tz = Number.isFinite(tzOffsetMinutes) ? tzOffsetMinutes : 0;
      const userLocal = toUserLocal(nowUtc, tz);

      const start = (startHour || 0) * 60 + (startMinute || 0);
      const end = (endHour || 0) * 60 + (endMinute || 0);
      const within = isWithinWindow(userLocal, start, end);
      const onBoundary = shouldFireNow(userLocal, start, intervalMinutes || 0);
      const humanLocal = userLocal.toTimeString().slice(0,5);
      if (!within) {
        console.log(`[${doc.id}] ${humanLocal} outside window start=${Math.floor(start/60)}:${(start%60).toString().padStart(2,'0')} end=${Math.floor(end/60)}:${(end%60).toString().padStart(2,'0')}`);
        continue;
      }
      if (!onBoundary) {
        console.log(`[${doc.id}] ${humanLocal} not on interval boundary (interval=${intervalMinutes})`);
        continue;
      }

      const last = r.lastTriggeredAt?.toDate?.() || r.lastTriggeredAt;
      const lastBucket = last ? Math.floor(new Date(last).getTime() / 60000) : -1;
      const nowBucket = Math.floor(nowUtc.getTime() / 60000);
      if (lastBucket === nowBucket) continue; // prevent duplicates

      sends.push(
        sendFCM(token, name || 'Reminder', message || "It's time!", {
          deeplink: 'notifications',
          reminderId: doc.id,
        })
          .then(() => batch.update(doc.ref, { lastTriggeredAt: admin.firestore.FieldValue.serverTimestamp() }))
          .catch((e) => console.error('Send failed for', doc.id, e.code || e.message))
      );
    }

    await Promise.all(sends);
    await batch.commit();
  } catch (e) {
    console.error('Cron error', e);
  }
});


// Disable user account using Firebase Auth Admin SDK (HTTP endpoint)
app.post('/disableUserAccount', async (req, res) => {
  const { userEmail, idToken } = req.body;

  if (!userEmail || typeof userEmail !== 'string') {
    return res.status(400).json({ error: 'User email is required' });
  }

  try {
    // Verify the admin is authenticated by checking the ID token
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      return res.status(401).json({ error: 'Unauthorized: Invalid token' });
    }

    // Get user by email
    const userRecord = await admin.auth().getUserByEmail(userEmail);

    // Disable the user account using Firebase Auth Admin SDK (built-in disable functionality)
    await admin.auth().updateUser(userRecord.uid, {
      disabled: true
    });

    // Update verification status to blocked (without adding custom disabled fields)
    await db.collection('users').doc(userRecord.uid).update({

      disabled: 'true',

    });

    res.json({
      success: true,
      message: `User ${userEmail} has been disabled successfully`,
      userId: userRecord.uid
    });

  } catch (error) {
    console.error('Error disabling user:', error);
    res.status(500).json({ error: `Failed to disable user: ${error.message}` });
  }
});

// Enable user account using Firebase Auth Admin SDK (HTTP endpoint)
app.post('/enableUserAccount', async (req, res) => {
  const { userEmail, idToken } = req.body;

  if (!userEmail || typeof userEmail !== 'string') {
    return res.status(400).json({ error: 'User email is required' });
  }

  try {
    // Verify the admin is authenticated by checking the ID token
    let decodedToken;
    try {
      decodedToken = await admin.auth().verifyIdToken(idToken);
    } catch (error) {
      return res.status(401).json({ error: 'Unauthorized: Invalid token' });
    }

    // Get user by email
    const userRecord = await admin.auth().getUserByEmail(userEmail);

    // Enable the user account using Firebase Auth Admin SDK (built-in enable functionality)
    await admin.auth().updateUser(userRecord.uid, {
      disabled: false
    });

    // Update the user's document in Firestore to mark as enabled
    await db.collection('users').doc(userRecord.uid).update({
      disabled: 'false',
    });

    res.json({
      success: true,
      message: `User ${userEmail} has been enabled successfully`,
      userId: userRecord.uid
    });

  } catch (error) {
    console.error('Error enabling user:', error);
    res.status(500).json({ error: `Failed to enable user: ${error.message}` });
  }
});

// Start the server
app.listen(PORT, () => {
  console.log(`🚀 Smart health Backend Server is running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/`);
  console.log(`🔒 Disable user: POST http://localhost:${PORT}/disableUserAccount`);
  console.log(`🔓 Enable user: POST http://localhost:${PORT}/enableUserAccount`);
});

export { db };