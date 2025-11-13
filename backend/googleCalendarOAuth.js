
import { google } from 'googleapis';
import dotenv from 'dotenv';
dotenv.config();

/**
 * Initialize OAuth2 client with your credentials
 */
function getOAuthClient() {
  const oauth2Client = new google.auth.OAuth2(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET
  );

  // ✅ Set the refresh token — this keeps your app authenticated even after the access token expires
  oauth2Client.setCredentials({
    refresh_token: process.env.GOOGLE_REFRESH_TOKEN,
  });

  return oauth2Client;
}

/**
 * Creates a Google Calendar event with a Meet link and invites both doctor & patient.
 * @param {Date} appointmentDate - JavaScript Date object
 * @param {string} doctorEmail
 * @param {string} patientEmail
 * @param {string} summary
 * @param {string} description
 * @returns {Promise<{meetLink: string, eventId: string}>}
 */
export async function createMeetEvent({
  appointmentDate,
  doctorEmail,
  patientEmail,
  summary,
  description,
}) {
  try {
    const auth = getOAuthClient();
    const calendar = google.calendar({ version: 'v3', auth });

    const event = {
      summary: summary || 'Online Appointment',
      description: description || 'Video consultation via Google Meet',
      start: {
        dateTime: appointmentDate.toISOString(),
        timeZone: 'Asia/Kolkata',
      },
      end: {
        dateTime: new Date(appointmentDate.getTime() + 60 * 60000).toISOString(), // +60 mins
        timeZone: 'Asia/Kolkata',
      },
      attendees: [
        { email: doctorEmail },
        { email: patientEmail },
      ],
      conferenceData: {
        createRequest: {
          requestId: `meet-${Date.now()}`, // unique request ID
          conferenceSolutionKey: { type: 'hangoutsMeet' },
        },
      },
      reminders: {
        useDefault: false,
        overrides: [
          { method: 'email', minutes: 30 },
          { method: 'popup', minutes: 10 },
        ],
      },
    };

    // ✅ Insert event into primary calendar
    const res = await calendar.events.insert({
      calendarId: 'primary',
      requestBody: event,
      conferenceDataVersion: 1,
      sendUpdates: 'all', // automatically emails attendees
    });

    const created = res.data;

    // ✅ Safely extract Meet link (handles different API response formats)
    const meetLink =
      created.hangoutLink ||
      created.conferenceData?.entryPoints?.find((e) => e.entryPointType === 'video')?.uri ||
      null;

    console.log(`📅 Google Meet event created: ${meetLink}`);

    return {
      meetLink,
      eventId: created.id,
      raw: created,
    };
  } catch (error) {
    console.error(' Error creating Google Meet event:', error.message);
    throw error;
  }
}
