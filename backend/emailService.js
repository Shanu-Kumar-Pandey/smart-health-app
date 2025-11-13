
import nodemailer from 'nodemailer';
import { db } from './index.js';
import { createMeetEvent } from './googleCalendarOAuth.js'; //  Add this import

// Create a transporter object using the default SMTP transport
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASSWORD,
  },
});

/**
 * Sends an email with a Google Meet link to both doctor and patient
 */
export const sendAppointmentEmails = async (appointment, doctor, patient) => {
  try {
    const appointmentDate = appointment.dateTime.toDate();
    const formattedDate = appointmentDate.toLocaleString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'Asia/Kolkata',
    });

    //  Use the actual meet link (from Firestore or newly created event)
    const meetLink = appointment.meetLink || 'https://meet.google.com/new?hs=181&authuser=0';

    // Email for patient
    const patientMailOptions = {
      from: `"Smart Health" <${process.env.EMAIL_USER}>`,
      to: patient.email,
      subject: `Your Upcoming Appointment with Dr. ${doctor.name}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2>Your Upcoming Appointment</h2>
          <p>Hello ${patient.name || 'there'},</p>
          <p>This is a reminder for your upcoming appointment with Dr. ${doctor.name}.</p>
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p><strong>Date & Time:</strong> ${formattedDate}</p>
            <p><strong>Doctor:</strong> Dr. ${doctor.name} </p>
            <p><strong>Appointment ID:</strong> ${appointment.id}</p>
            ${appointment.reason ? `<p><strong>Reason:</strong> ${appointment.reason}</p>` : ''}
          </div>
          <p>Click the button below to join your video consultation at the scheduled time:</p>
          <a href="${meetLink}" style="display: inline-block; background-color: #4285F4; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; margin: 15px 0;">Join Video Consultation</a>
          <p>If the button doesn't work, copy and paste this link:</p>
          <p>${meetLink}</p>
          <p>Best regards,<br>The Smart Health Team</p>
        </div>
      `,
    };

    // Email for doctor
    const doctorMailOptions = {
      from: `"Smart Health" <${process.env.EMAIL_USER}>`,
      to: doctor.email,
      subject: `Upcoming Appointment with ${patient.name}`,
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
          <h2>Upcoming Patient Appointment</h2>
          <p>Hello Dr. ${doctor.name},</p>
          <p>This is a reminder for your appointment with ${patient.name}.</p>
          <div style="background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <p><strong>Date & Time:</strong> ${formattedDate}</p>
            <p><strong>Patient:</strong> ${patient.name}</p>
            <p><strong>Appointment ID:</strong> ${appointment.id}</p>
            ${appointment.reason ? `<p><strong>Reason:</strong> ${appointment.reason}</p>` : ''}
            ${patient.contact ? `<p><strong>Patient Phone:</strong> ${patient.contact}</p>` : ''}
          </div>
          <p>Click below to join the video consultation:</p>
          <a href="${meetLink}" style="display: inline-block; background-color: #4285F4; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px;">Join Video Consultation</a>
          <p>If the button doesn't work, copy and paste this link:</p>
          <p>${meetLink}</p>
          <p>Best regards,<br>The Smart Health Team</p>
        </div>
      `,
    };

    await Promise.all([
      transporter.sendMail(patientMailOptions),
      transporter.sendMail(doctorMailOptions)
    ]);

    console.log(`Emails sent for appointment ${appointment.id}`);
    return true;
  } catch (error) {
    console.error('Error sending appointment emails:', error);
    return false;
  }
};

/**
 * Sends appointment reminders for upcoming appointments
 */
export const sendAppointmentReminders = async () => {
  console.log(' Starting appointment reminder check...');
  try {
    const now = new Date();
    const oneMinuteFromNow = new Date(now.getTime() + 60 * 1000);// send mail 1 minute before meeting time

    const appointmentsRef = db.collection('appointments');
    const snapshot = await appointmentsRef
      .where('dateTime', '>=', now)
      .where('dateTime', '<=', oneMinuteFromNow)
      .where('reminderSent', '==', false)
      .get();

    console.log(` Found ${snapshot.size} appointments`);

    if (snapshot.empty) return 0;
    let remindersSent = 0;

    for (const doc of snapshot.docs) {
      const appointment = { id: doc.id, ...doc.data() };
      const [doctorDoc, patientDoc] = await Promise.all([
        db.collection('users').doc(appointment.doctorId).get(),
        db.collection('users').doc(appointment.userId).get()
      ]);

      if (!doctorDoc.exists || !patientDoc.exists) continue;

      const doctor = { id: doctorDoc.id, ...doctorDoc.data() };
      const patient = { id: patientDoc.id, ...patientDoc.data() };

      //  Create Meet link if not already there
      const appointmentDate = appointment.dateTime?.toDate ? appointment.dateTime.toDate() : new Date(appointment.dateTime);
      let meetLink = appointment.meetLink || null;
      let googleEventId = appointment.googleEventId || null;

      if (!meetLink) {
        try {
          const { meetLink: createdLink, eventId } = await createMeetEvent({
            appointmentDate,
            doctorEmail: doctor.email,
            patientEmail: patient.email,
            summary: `Appointment: ${patient.name} with Dr. ${doctor.name}`,
            description: appointment.reason || 'Teleconsultation'
          });

          if (createdLink) {
            meetLink = createdLink;
            googleEventId = eventId;
            await doc.ref.update({ meetLink, googleEventId });
            console.log(` Created Meet link for appointment ${appointment.id}`);
          }
        } catch (err) {
          console.error('Error creating Meet event:', err);
          meetLink = 'https://meet.google.com/new';
        }
      }

      //  Pass meet link to email sender
      const emailSent = await sendAppointmentEmails({ ...appointment, meetLink }, doctor, patient);

      if (emailSent) {
        await doc.ref.update({ reminderSent: true });
        remindersSent++;
      }
    }

    console.log(` Sent ${remindersSent} reminders.`);
    return remindersSent;
  } catch (error) {
    console.error(' Error in sendAppointmentReminders:', error);
    return 0;
  }
};
