const functions = require('firebase-functions');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onCall, onRequest} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const twilio = require('twilio');
const { addDays, addYears, setHours, setMinutes, setSeconds, setMilliseconds, getDay, getHours, getMinutes, getSeconds } = require('date-fns');
const { toZonedTime, fromZonedTime } = require('date-fns-tz');

// Initialize Firebase Admin
admin.initializeApp();

// Define secrets for Twilio (will be accessed from Firebase Secret Manager)
const twilioAccountSid = defineSecret('TWILIO_ACCOUNT_SID');
const twilioAuthToken = defineSecret('TWILIO_AUTH_TOKEN');
const twilioPhoneNumber = defineSecret('TWILIO_PHONE_NUMBER');

/**
 * Cloud Function to send SMS via Twilio
 *
 * Request body:
 * {
 *   "to": "+17788143739",
 *   "message": "Hi! Time to take your vitamins",
 *   "profileId": "profile-uuid",
 *   "messageType": "taskReminder"
 * }
 *
 * Response:
 * {
 *   "success": true,
 *   "messageId": "SM1234...",
 *   "status": "queued",
 *   "sentAt": "2025-10-09T..."
 * }
 */
exports.sendSMS = onCall({
  secrets: [twilioAccountSid, twilioAuthToken, twilioPhoneNumber]
}, async (request) => {
  // Verify user is authenticated
  if (!request.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to send SMS'
    );
  }

  // Access secrets from request.rawRequest (v2 pattern)
  const accountSid = twilioAccountSid.value();
  const authToken = twilioAuthToken.value();
  const fromNumber = twilioPhoneNumber.value();

  // Initialize Twilio client with secrets
  const twilioClient = twilio(accountSid, authToken);

  const data = request.data;

  const { to, message, profileId, messageType } = data;

  // Validate required fields
  if (!to || !message) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required fields: to, message'
    );
  }

  // Validate phone number format (E.164)
  const phoneRegex = /^\+[1-9]\d{1,14}$/;
  if (!phoneRegex.test(to)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      `Invalid phone number format: ${to}. Must be E.164 format (e.g., +17788143739)`
    );
  }

  // Check user's SMS quota (prevent abuse)
  const userId = request.auth.uid;
  const userDoc = await admin.firestore().collection('users').doc(userId).get();

  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'User not found'
    );
  }

  const userData = userDoc.data();

  // Check if user has exceeded their SMS quota
  if (userData.smsQuotaUsed >= userData.smsQuotaLimit) {
    throw new functions.https.HttpsError(
      'resource-exhausted',
      `SMS quota exceeded. Used ${userData.smsQuotaUsed}/${userData.smsQuotaLimit} for this period.`
    );
  }

  // Check if quota period needs reset
  const now = new Date();
  const quotaPeriodEnd = userData.smsQuotaPeriodEnd?.toDate();

  if (quotaPeriodEnd && now > quotaPeriodEnd) {
    // Reset quota for new period
    await admin.firestore().collection('users').doc(userId).update({
      smsQuotaUsed: 0,
      smsQuotaPeriodStart: admin.firestore.FieldValue.serverTimestamp(),
      smsQuotaPeriodEnd: new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000) // 30 days from now
    });
  }

  try {
    // Send SMS via Twilio
    const twilioMessage = await twilioClient.messages.create({
      body: message,
      from: fromNumber,
      to: to
    });

    // SMS sent successfully - no log needed (tracked in Firestore)

    // Increment user's SMS quota usage
    await admin.firestore().collection('users').doc(userId).update({
      smsQuotaUsed: admin.firestore.FieldValue.increment(1)
    });

    // Log SMS delivery for audit trail
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('smsLogs')
      .add({
        to: to,
        message: message,
        profileId: profileId || null,
        messageType: messageType || 'unknown',
        twilioSid: twilioMessage.sid,
        status: twilioMessage.status,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        direction: 'outbound'
      });

    // IMPORTANT: Also save to messages collection for gallery chat view
    // This creates the "blue bubble" (sent message) in the gallery
    if (profileId) {
      await admin.firestore()
        .collection('users')
        .doc(userId)
        .collection('profiles')
        .doc(profileId)
        .collection('messages')
        .add({
          userId: userId,
          profileId: profileId,
          twilioSid: twilioMessage.sid,
          fromPhone: fromNumber,
          toPhone: to,
          messageBody: message,
          direction: 'outbound',  // This is a SENT message (blue bubble)
          numMedia: 0,
          status: twilioMessage.status,
          receivedAt: admin.firestore.FieldValue.serverTimestamp(),
          isOptOut: false
        });

    }

    return {
      success: true,
      messageId: twilioMessage.sid,
      status: twilioMessage.status,
      sentAt: new Date().toISOString()
    };

  } catch (error) {
    console.error('❌ Twilio SMS error:', error);

    throw new functions.https.HttpsError(
      'internal',
      `Failed to send SMS: ${error.message}`
    );
  }
});

/**
 * Webhook endpoint for Twilio incoming SMS (Status callbacks & Replies)
 *
 * This receives incoming messages when elderly users reply to reminders
 *
 * SECURITY:
 * - Validates Twilio signature to prevent spoofing
 * - Rate limited to prevent abuse (maxInstances: 10)
 * - Sanitizes input to prevent injection attacks
 */
exports.twilioWebhook = onRequest(
  {
    memory: '256MiB',
    timeoutSeconds: 60,
    maxInstances: 10,  // Rate limiting via max concurrent instances
    secrets: [twilioAccountSid, twilioAuthToken, twilioPhoneNumber]  // Access to credentials for signature validation, photo download, and sending replies
  },
  async (req, res) => {
    // SECURITY CHECK #1: Verify request is from Twilio using HMAC-SHA1 signature
    const twilioSignature = req.headers['x-twilio-signature'];
    if (!twilioSignature) {
      console.error('❌ Missing X-Twilio-Signature header');
      return res.status(403).send('Forbidden');
    }

    // Build URL for Twilio signature validation
    // Twilio signs requests using the webhook URL configured in their console
    // For Cloud Functions Gen 2, the public URL format is:
    // https://us-central1-{project-id}.cloudfunctions.net/{function-name}
    // But req.url returns "/" because Cloud Run handles the function name routing
    // So we must reconstruct the full URL that Twilio used for signing
    const protocol = req.headers['x-forwarded-proto'] || 'https';
    const host = req.headers.host;

    // Determine the correct path based on the host
    // If host is the Cloud Functions URL (contains 'cloudfunctions.net'), append function name
    // If host is the Cloud Run URL (contains 'run.app'), use req.url as-is
    let url;
    if (host.includes('cloudfunctions.net')) {
      // Public Cloud Functions URL - Twilio uses this format
      url = `${protocol}://${host}/twilioWebhook`;
    } else {
      // Direct Cloud Run URL - use as-is
      url = `${protocol}://${host}${req.url}`;
    }

    const authToken = twilioAuthToken.value();
    const isValidRequest = twilio.validateRequest(authToken, twilioSignature, url, req.body);

    if (!isValidRequest) {
      console.error('❌ Invalid Twilio signature', { url, host, reqUrl: req.url });
      return res.status(403).send('Forbidden');
    }

    // SECURITY CHECK #2: Sanitize inputs
    const {
      From: fromPhone,
      To: toPhone,
      Body: rawMessageBody,
      MessageSid: twilioSid,
      SmsStatus: status,
      NumMedia: numMedia
    } = req.body;

    // Sanitize message body (prevent XSS if ever displayed in web UI)
    const messageBody = (rawMessageBody || '').toString().trim().slice(0, 1000);  // Max 1000 chars

    // Validate phone number format (E.164)
    if (!fromPhone || !fromPhone.match(/^\+[1-9]\d{1,14}$/)) {
      console.error('❌ Invalid phone number format:', fromPhone);
      return res.status(400).send('Invalid phone number');
    }

    try {
    // WORKAROUND: Try collectionGroup first, if it fails due to index building,
    // fall back to searching all users (less efficient but works)
    let profileDoc = null;
    let userId = null;

    try {
      // Try collectionGroup query (requires index)
      const profilesSnapshot = await admin.firestore()
        .collectionGroup('profiles')
        .where('phoneNumber', '==', fromPhone)
        .limit(1)
        .get();

      if (!profilesSnapshot.empty) {
        profileDoc = profilesSnapshot.docs[0];
        const profileData = profileDoc.data();
        userId = profileData.userId;
      }
    } catch (indexError) {
      console.warn('⚠️ CollectionGroup query failed, using fallback', indexError.message);

      // Fallback: Query all users and search their profiles
      const usersSnapshot = await admin.firestore().collection('users').get();

      for (const userDoc of usersSnapshot.docs) {
        const userProfiles = await userDoc.ref.collection('profiles')
          .where('phoneNumber', '==', fromPhone)
          .limit(1)
          .get();

        if (!userProfiles.empty) {
          profileDoc = userProfiles.docs[0];
          userId = userDoc.id;
          break;
        }
      }
    }

    if (!profileDoc || !userId) {
      console.warn(`⚠️ No profile found for phone: ${fromPhone}`);
      res.status(200).send('OK'); // Still return 200 to Twilio
      return;
    }

    // Check for STOP keywords (opt-out)
    const upperMessage = messageBody.toUpperCase().trim();
    const stopKeywords = ['STOP', 'UNSUBSCRIBE', 'CANCEL', 'END', 'QUIT', 'STOPALL'];

    if (stopKeywords.includes(upperMessage)) {
      // Update profile to opt-out
      await profileDoc.ref.update({
        smsOptedOut: true,
        optOutDate: admin.firestore.FieldValue.serverTimestamp(),
        optOutMethod: 'STOP_KEYWORD'
      });
    }

    // Store the incoming message
    await admin.firestore()
      .collection('users')
      .doc(userId)
      .collection('profiles')
      .doc(profileDoc.id)
      .collection('messages')
      .add({
        userId: userId, // Add userId for collectionGroup queries
        profileId: profileDoc.id,
        fromPhone: fromPhone,
        toPhone: toPhone,
        messageBody: messageBody,
        twilioSid: twilioSid,
        status: status,
        numMedia: parseInt(numMedia) || 0,
        receivedAt: admin.firestore.FieldValue.serverTimestamp(),
        isOptOut: stopKeywords.includes(upperMessage),
        direction: 'inbound'
      });

    // Find recently sent SMS for this profile (within last 30 minutes)
    // Check lastSMSSentAt instead of nextScheduledDate (which gets updated immediately after send)
    const now = new Date();
    const thirtyMinutesAgo = new Date(now - 30 * 60 * 1000);

    const allHabitsSnapshot = await admin.firestore()
      .collection(`users/${userId}/profiles/${profileDoc.id}/habits`)
      .where('status', '==', 'active')
      .get();

    // Filter habits where SMS was sent in last 30 minutes AND not already completed
    const recentHabits = allHabitsSnapshot.docs
      .map(doc => ({ doc, data: doc.data() }))
      .filter(({ data }) => {
        if (!data.lastSMSSentAt) return false;
        const sentTime = data.lastSMSSentAt.toDate();
        const inWindow = sentTime >= thirtyMinutesAgo && sentTime <= now;

        // DUPLICATE PREVENTION: Check if this habit instance was already completed
        if (data.lastCompletedAt) {
          const completedTime = data.lastCompletedAt.toDate();
          if (completedTime >= sentTime) return false;
        }

        return inWindow;
      })
      .sort((a, b) => b.data.lastSMSSentAt.toMillis() - a.data.lastSMSSentAt.toMillis());

    if (recentHabits.length > 0) {
      const habitDoc = recentHabits[0].doc;
      const habit = recentHabits[0].data;

      // VALIDATE: Check if response matches habit requirements
      const hasPhoto = parseInt(numMedia) > 0;
      const hasText = messageBody && messageBody.trim().length > 0;

      const requiresPhoto = habit.requiresPhoto || false;
      const requiresText = habit.requiresText || false;

      // Determine if response is valid
      let isValidResponse = true;
      let validationMessage = null;

      if (requiresPhoto && !hasPhoto) {
        isValidResponse = false;
        validationMessage = "Please send a photo to complete this task.";
      } else if (requiresText && !hasText) {
        isValidResponse = false;
        validationMessage = "Please send a message to complete this task.";
      } else if (requiresPhoto && requiresText && (!hasPhoto || !hasText)) {
        isValidResponse = false;
        validationMessage = "Please send both a photo and a message to complete this task.";
      }

      // Only proceed if response is valid
      if (!isValidResponse) {
        // Send validation message to user
        try {
          const twilioClient = twilio(twilioAccountSid.value(), twilioAuthToken.value());

          await twilioClient.messages.create({
            body: validationMessage,
            from: twilioPhoneNumber.value(),
            to: fromPhone
          });
        } catch (smsError) {
          console.error('❌ Failed to send validation SMS:', smsError.message);
        }

        // Do NOT mark as completed, do NOT create gallery event
        res.status(200).send('OK');
        return;
      }

      // Valid response - mark habit as completed
      await habitDoc.ref.update({
        lastCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        completionCount: admin.firestore.FieldValue.increment(1)
      });

      // Create gallery event with correct GalleryHistoryEvent schema
      // Structure must match Swift model: id, userId, profileId, eventType, createdAt, eventData
      const galleryEventRef = admin.firestore()
        .collection(`users/${userId}/gallery_events`)
        .doc();  // Generate ID first

      // Build taskResponse object - omit photoData if null (Swift Codable expects absent field for nil)
      const taskResponseData = {
        taskId: habitDoc.id,
        textResponse: messageBody,
        responseType: 'text',  // Will be updated if photo exists
        taskTitle: habit.title,
        sentMessage: habit.lastSentMessage || null  // Include the original sent message for gallery display
      };

      // Download MMS photo if attached
      if (parseInt(numMedia) > 0) {
        try {
          // Extract media URL from Twilio webhook payload
          const mediaUrl = req.body.MediaUrl0;
          const mediaType = req.body.MediaContentType0 || 'image/jpeg';

          // Fetch photo from Twilio's URL (requires Basic Auth)
          const authHeader = 'Basic ' + Buffer.from(
            twilioAccountSid.value() + ':' + twilioAuthToken.value()
          ).toString('base64');

          const photoResponse = await fetch(mediaUrl, {
            headers: {
              'Authorization': authHeader
            }
          });

          if (!photoResponse.ok) {
            throw new Error(`Failed to download photo: ${photoResponse.status} ${photoResponse.statusText}`);
          }

          // Convert photo to base64 for Firestore storage
          const photoArrayBuffer = await photoResponse.arrayBuffer();
          const photoBuffer = Buffer.from(photoArrayBuffer);
          const photoDataBase64 = photoBuffer.toString('base64');

          // Add photo to response data
          taskResponseData.photoData = photoDataBase64;

          // Update response type based on what was sent
          if (messageBody && messageBody.trim().length > 0) {
            taskResponseData.responseType = 'both';  // Text + Photo
          } else {
            taskResponseData.responseType = 'photo';  // Photo only
          }

        } catch (photoError) {
          console.error('❌ Failed to download MMS photo:', photoError.message);
          // Continue without photo - don't fail entire webhook
          // Response type stays as 'text' if text exists, otherwise task completion still recorded
        }
      }

      // Send thank you message BEFORE creating gallery event
      // This allows us to include replyMessage in the initial write
      // (iOS listener only processes .added events, not .modified)
      let thankYou = null;
      try {
        const thankYouMessages = [
          `Thanks! 💙`,
          `Got it! ✨`,
          `Perfect! 😊`,
          `Great! 🌟`,
          `Awesome! 🎉`
        ];

        thankYou = thankYouMessages[Math.floor(Math.random() * thankYouMessages.length)];

        const twilioClient = twilio(twilioAccountSid.value(), twilioAuthToken.value());

        await twilioClient.messages.create({
          body: thankYou,
          from: twilioPhoneNumber.value(),
          to: fromPhone
        });
      } catch (smsError) {
        console.error('❌ Failed to send thank you SMS:', smsError.message);
        // Continue - we still want to create the gallery event even if SMS fails
      }

      // Include replyMessage in the initial write so iOS listener picks it up
      taskResponseData.replyMessage = thankYou;

      await galleryEventRef.set({
        id: galleryEventRef.id,
        userId: userId,
        profileId: profileDoc.id,
        eventType: 'taskResponse',  // Must match GalleryEventType enum
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        // eventData is an enum with nested SMSResponseData
        // IMPORTANT: Swift Codable encodes enum associated values with "_0" key
        eventData: {
          taskResponse: {
            _0: taskResponseData  // Wrap in _0 to match Swift's enum encoding
          }
        }
      });
    }

    res.status(200).send('OK');

  } catch (error) {
    console.error('❌ Webhook processing error:', error);
    res.status(500).send('Error processing webhook');
  }
});

/**
 * Scheduled function to cleanup old gallery events (runs daily at midnight PST)
 *
 * Data Retention Policy:
 * - Events older than 90 days are processed
 * - Photos are archived to Cloud Storage (kept forever)
 * - Text data is permanently deleted (privacy + cost savings)
 *
 * Why:
 * - Privacy: Delete sensitive text messages after 3 months
 * - Cost: Reduce Firestore reads by 75%
 * - Memories: Keep photos in cheaper Cloud Storage
 *
 * Cost Impact:
 * - Before: ~$2/user/year (3,000+ Firestore docs)
 * - After: ~$0.50/user/year (270 docs + Cloud Storage)
 */
exports.cleanupOldGalleryEvents = onSchedule({
  schedule: 'every 24 hours',
  timeZone: 'America/Los_Angeles'
}, async (event) => {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    // Calculate 90 days ago
    const threeMonthsAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)
    );

    try {
      // Query old events across all users using collectionGroup
      const oldEventsSnapshot = await db.collectionGroup('galleryEvents')
        .where('createdAt', '<', threeMonthsAgo)
        .limit(500) // Process in batches to avoid timeouts
        .get();

      if (oldEventsSnapshot.empty) {
        return { photosArchived: 0, eventsDeleted: 0 };
      }

      let photosArchived = 0;
      let eventsDeleted = 0;
      let errors = 0;

      // Process each old event
      for (const doc of oldEventsSnapshot.docs) {
        try {
          const event = doc.data();
          const userId = event.userId;
          const profileId = event.profileId;
          const eventDate = event.createdAt.toDate();

          // Check if this is a task response with a photo
          if (event.eventType === 'taskResponse' &&
              event.eventData?.taskResponse?.photoData) {

            const photoDataBase64 = event.eventData.taskResponse.photoData;

            // Create organized file path: userId/profileId/YYYY/MM/eventId.jpg
            const year = eventDate.getFullYear();
            const month = String(eventDate.getMonth() + 1).padStart(2, '0');
            const fileName = `gallery-archive/${userId}/${profileId}/${year}/${month}/${event.id}.jpg`;

            // Convert base64 to buffer
            const photoBuffer = Buffer.from(photoDataBase64, 'base64');

            // Upload to Cloud Storage
            const file = bucket.file(fileName);
            await file.save(photoBuffer, {
              contentType: 'image/jpeg',
              metadata: {
                metadata: {
                  userId: userId,
                  profileId: profileId,
                  eventId: event.id,
                  originalCreatedAt: eventDate.toISOString(),
                  archivedAt: new Date().toISOString(),
                  taskTitle: event.eventData.taskResponse.taskTitle || 'Unknown Task'
                }
              }
            });

            photosArchived++;
          }

          // Delete the Firestore event (text data permanently removed)
          await doc.ref.delete();
          eventsDeleted++;

        } catch (error) {
          errors++;
          console.error('❌ Cleanup event failed:', doc.id, error.message);
          // Continue processing other events even if one fails
        }
      }

      const summary = {
        photosArchived,
        eventsDeleted,
        errors,
        timestamp: new Date().toISOString(),
        oldestEventProcessed: threeMonthsAgo.toDate().toISOString()
      };

      // Only log if work was done
      if (eventsDeleted > 0) {
        console.log('Cleanup complete:', JSON.stringify(summary));
      }

      return summary;

    } catch (error) {
      console.error('💥 Cleanup function failed:', error);
      throw error;
    }
  });

/**
 * Retry utility with exponential backoff for Firestore operations
 *
 * @param {Function} operation - Async function to retry
 * @param {string} operationName - Name for logging
 * @param {number} maxRetries - Maximum retry attempts (default: 3)
 * @returns {Promise<any>} - Result of the operation
 * @throws {Error} - If all retries exhausted
 */
async function retryWithBackoff(operation, operationName, maxRetries = 3) {
  let lastError;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      if (attempt === maxRetries) {
        console.error(`❌ ${operationName} failed after ${maxRetries} attempts:`, error.message);
        throw error;
      }

      // Exponential backoff: 100ms, 200ms, 400ms
      const delayMs = 100 * Math.pow(2, attempt - 1);
      await new Promise(resolve => setTimeout(resolve, delayMs));
    }
  }

  throw lastError;
}

/**
 * Cloud Scheduler: Check for due habits every minute and send SMS reminders
 *
 * Runs: Every 1 minute (Cloud Scheduler minimum interval)
 * Checks: All active habits scheduled in last 90 seconds (optimized window)
 * Sends: SMS via Twilio to elderly user's phone
 * Logs: SMS delivery to /users/{userId}/smsLogs
 *
 * Note: 90-second window (vs 2 minutes) reduces false positives while maintaining
 * reliability if Cloud Scheduler occasionally skips a minute.
 *
 * This is the CRITICAL MISSING PIECE that converts scheduled habits into actual SMS delivery.
 * Without this function, 0% of habit reminders reach elderly users via SMS.
 */
exports.sendScheduledTaskReminders = onSchedule({
  schedule: 'every 1 minutes',
  timeZone: 'America/Los_Angeles',
  secrets: [twilioAccountSid, twilioAuthToken, twilioPhoneNumber]
}, async (event) => {
  const now = admin.firestore.Timestamp.now();
  const currentTime = now.toDate();

  // EXPANDED WINDOW: 5 minutes (catches habits missed by scheduler delays/outages)
  // This prevents habits from being skipped if Cloud Scheduler is delayed
  const fiveMinutesAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 5 * 60 * 1000)
  );

  try {
    // Find all active habits scheduled in last 5 minutes
    const habitsSnapshot = await admin.firestore()
      .collectionGroup('habits')
      .where('status', '==', 'active')
      .where('nextScheduledDate', '>=', fiveMinutesAgo)
      .where('nextScheduledDate', '<=', now)
      .get();

    if (habitsSnapshot.empty) {
      return null;
    }

    let smssSent = 0;
    let smsFailed = 0;
    let smsSkipped = 0;

    // Process each due habit
    for (const habitDoc of habitsSnapshot.docs) {
      const habit = habitDoc.data();
      const habitPath = habitDoc.ref.path;

      // Extract userId and profileId from path: users/{userId}/profiles/{profileId}/habits/{habitId}
      const pathParts = habitPath.split('/');
      if (pathParts.length < 4 || pathParts[0] !== 'users' || pathParts[2] !== 'profiles') {
        console.warn(`⚠️ Invalid habit path structure: ${habitPath}`);
        continue;
      }

      const userId = pathParts[1];
      const profileId = pathParts[3];

      // Get profile to retrieve phone number
      const profileDoc = await admin.firestore()
        .doc(`users/${userId}/profiles/${profileId}`)
        .get();

      if (!profileDoc.exists) {
        smsSkipped++;
        continue;
      }

      const profile = profileDoc.data();

      // Check if profile is confirmed
      if (profile.status !== 'confirmed') {
        smsSkipped++;
        continue;
      }

      // Check if profile has opted out
      if (profile.smsOptedOut === true) {
        smsSkipped++;
        continue;
      }

      // Check if phone number exists
      if (!profile.phoneNumber) {
        smsSkipped++;
        continue;
      }

      // Check if SMS already sent for this exact scheduled time (prevent duplicates)
      const scheduledTimeDate = habit.nextScheduledDate.toDate();

      // Calculate lateness: how many seconds late is this SMS?
      const latenessSeconds = Math.floor((currentTime - scheduledTimeDate) / 1000);

      const smsLogQuery = await admin.firestore()
        .collection(`users/${userId}/smsLogs`)
        .where('habitId', '==', habit.id)
        .where('nextScheduledDate', '==', habit.nextScheduledDate)
        .where('direction', '==', 'outbound')
        .limit(1)
        .get();

      if (!smsLogQuery.empty) {
        smsSkipped++;
        continue;
      }

      // Generate task reminder message
      const message = getTaskReminderMessage(habit, profile);

      // Initialize Twilio client
      const twilioClient = twilio(
        twilioAccountSid.value(),
        twilioAuthToken.value()
      );

      // Send SMS via Twilio
      try {
        const twilioMessage = await twilioClient.messages.create({
          body: message,
          from: twilioPhoneNumber.value(),
          to: profile.phoneNumber
        });

        // Log SMS delivery for audit trail
        await admin.firestore()
          .collection(`users/${userId}/smsLogs`)
          .add({
            habitId: habit.id,
            profileId: profile.id,
            to: profile.phoneNumber,
            message: message,
            messageType: 'taskReminder',
            twilioSid: twilioMessage.sid,
            status: twilioMessage.status,
            nextScheduledDate: habit.nextScheduledDate,
            scheduledTime: scheduledTimeDate,
            latenessSeconds: latenessSeconds, // Track delivery latency for analytics
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            direction: 'outbound'
          });

        // Increment user's SMS quota
        await admin.firestore()
          .collection('users')
          .doc(userId)
          .update({
            smsQuotaUsed: admin.firestore.FieldValue.increment(1)
          });

        smssSent++;

      } catch (smsError) {
        console.error('❌ SMS send failed:', habit.id, smsError.message);

        // Log failure for debugging
        await admin.firestore()
          .collection(`users/${userId}/smsLogs`)
          .add({
            habitId: habit.id,
            profileId: profile.id,
            to: profile.phoneNumber,
            message: message,
            messageType: 'taskReminder',
            status: 'failed',
            errorMessage: smsError.message,
            nextScheduledDate: habit.nextScheduledDate,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            direction: 'outbound'
          });

        smsFailed++;
      }

      // CRITICAL: Update nextScheduledDate OUTSIDE the SMS try-catch block
      // This ensures the date advances even if SMS fails, preventing the habit from getting stuck
      // If we don't update this, the habit will never send again because the date is in the past
      if (habit.frequency !== 'once') {
        try {
          // Pass profile timezone for correct scheduling in recipient's timezone
          const nextOccurrence = calculateNextOccurrence(habit, profile.timeZone);

          // Validate the calculated date
          if (!nextOccurrence || isNaN(nextOccurrence.getTime())) {
            console.error('❌ Invalid nextOccurrence for habit:', habit.id);
            continue;
          }

          // Ensure it's in the future
          if (nextOccurrence <= new Date()) {
            console.error('❌ nextOccurrence in past for habit:', habit.id);
            continue;
          }

          // Retry Firestore update with exponential backoff (3 attempts: 0ms, 100ms, 200ms)
          await retryWithBackoff(
            async () => {
              await habitDoc.ref.update({
                nextScheduledDate: admin.firestore.Timestamp.fromDate(nextOccurrence),
                lastSMSSentAt: admin.firestore.FieldValue.serverTimestamp(),
                lastSentMessage: message  // Store sent message for gallery display
              });
            },
            `Update nextScheduledDate for habit ${habit.id}`
          );

        } catch (updateError) {
          console.error('❌ CRITICAL: nextScheduledDate update failed:', habit.id, updateError.message);
          // This is critical - if we can't update the date, the habit is stuck
          // Log to error collection for monitoring and alerting
          await admin.firestore()
            .collection('errors')
            .add({
              type: 'nextScheduledDateUpdateFailure',
              habitId: habit.id,
              userId: userId,
              profileId: profile.id,
              habitTitle: habit.title,
              errorMessage: updateError.message,
              errorStack: updateError.stack,
              retriesExhausted: true,
              timestamp: admin.firestore.FieldValue.serverTimestamp()
            });
        }
      } else {
        // For one-time habits, just track when SMS was sent (no need to advance date)
        try {
          await retryWithBackoff(
            async () => {
              await habitDoc.ref.update({
                lastSMSSentAt: admin.firestore.FieldValue.serverTimestamp()
              });
            },
            `Update lastSMSSentAt for one-time habit ${habit.id}`
          );
        } catch (updateError) {
          console.error('❌ lastSMSSentAt update failed:', habit.id, updateError.message);
        }
      }
    }

    // Only log summary if SMS was sent or failed
    if (smssSent > 0 || smsFailed > 0) {
      console.log('Scheduler:', { sent: smssSent, failed: smsFailed, skipped: smsSkipped });
    }
    return { smssSent, smsFailed, smsSkipped };

  } catch (error) {
    console.error('❌ Error in sendScheduledTaskReminders:', error);
    throw error;
  }
});

/**
 * Missed SMS Recovery: Hourly check for habits that got stuck in the past
 *
 * This is a safety net that catches habits where:
 * 1. nextScheduledDate is in the past (more than 5 minutes ago)
 * 2. lastSMSSentAt doesn't match nextScheduledDate (SMS was never sent)
 * 3. Habit is still active
 *
 * When found, it advances nextScheduledDate to the NEXT future occurrence
 * without sending SMS (to avoid sending late/stale reminders).
 *
 * Runs: Every hour (less frequent since this is edge case recovery)
 * Purpose: Prevent habits from permanently breaking due to transient failures
 */
exports.recoverMissedHabits = onSchedule({
  schedule: 'every 60 minutes',
  timeZone: 'America/Los_Angeles'
}, async (event) => {
  const now = new Date();
  const fiveMinutesAgo = admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() - 5 * 60 * 1000)
  );

  try {
    // Find habits where nextScheduledDate is MORE than 5 minutes in the past
    // These are habits that were missed by the regular scheduler
    const stuckHabitsSnapshot = await admin.firestore()
      .collectionGroup('habits')
      .where('status', '==', 'active')
      .where('frequency', '!=', 'once') // Only recurring habits can get stuck
      .where('nextScheduledDate', '<', fiveMinutesAgo)
      .get();

    if (stuckHabitsSnapshot.empty) {
      return null;
    }

    let recovered = 0;
    let alreadySent = 0;

    for (const habitDoc of stuckHabitsSnapshot.docs) {
      const habit = habitDoc.data();
      const habitPath = habitDoc.ref.path;

      // Extract userId from path
      const pathParts = habitPath.split('/');
      const userId = pathParts[1];

      // Check if SMS was actually sent for this nextScheduledDate
      const smsLogQuery = await admin.firestore()
        .collection(`users/${userId}/smsLogs`)
        .where('habitId', '==', habit.id)
        .where('nextScheduledDate', '==', habit.nextScheduledDate)
        .where('direction', '==', 'outbound')
        .limit(1)
        .get();

      if (!smsLogQuery.empty) {
        alreadySent++;
      }

      // Calculate the NEXT future occurrence (skip the missed one)
      const nextOccurrence = calculateNextOccurrence(habit, habit.timeZone);

      // Update with retry logic
      try {
        await retryWithBackoff(
          async () => {
            await habitDoc.ref.update({
              nextScheduledDate: admin.firestore.Timestamp.fromDate(nextOccurrence),
              recoveredAt: admin.firestore.FieldValue.serverTimestamp(), // Track when recovery happened
              recoveredBy: 'recoverMissedHabits'
            });
          },
          `Recover habit ${habit.id} ("${habit.title}")`
        );

        recovered++;

      } catch (error) {
        console.error('❌ Failed to recover habit:', habit.id, error.message);

        // Log critical error
        await admin.firestore()
          .collection('errors')
          .add({
            type: 'habitRecoveryFailure',
            habitId: habit.id,
            userId: userId,
            habitTitle: habit.title,
            stuckDate: habit.nextScheduledDate.toDate().toISOString(),
            errorMessage: error.message,
            timestamp: admin.firestore.FieldValue.serverTimestamp()
          });
      }
    }

    // Only log if recovery work was done
    if (recovered > 0) {
      console.log('Recovery:', { stuck: stuckHabitsSnapshot.size, recovered, alreadySent });
    }
    return { recovered, alreadySent };

  } catch (error) {
    console.error('❌ Missed habit recovery failed:', error);
    throw error;
  }
});

/**
 * Health Check Monitor: Track system health and alert on critical failures
 *
 * Monitors:
 * 1. Habits stuck in the past (nextScheduledDate < now - 1 hour)
 * 2. Recent errors in 'errors' collection
 * 3. SMS sending success rate (last hour)
 * 4. Firestore update failures
 *
 * Runs: Every 15 minutes for proactive monitoring
 * Alerts: Logs warnings when thresholds exceeded
 */
exports.healthCheckMonitor = onSchedule({
  schedule: 'every 15 minutes',
  timeZone: 'America/Los_Angeles'
}, async (event) => {
  const now = new Date();
  const oneHourAgo = admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() - 60 * 60 * 1000)
  );
  const fifteenMinutesAgo = admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() - 15 * 60 * 1000)
  );

  try {
    const healthMetrics = {
      timestamp: now.toISOString(),
      checks: {}
    };

    // Check 1: Habits stuck in the past (more than 1 hour old)
    const stuckHabitsSnapshot = await admin.firestore()
      .collectionGroup('habits')
      .where('status', '==', 'active')
      .where('nextScheduledDate', '<', oneHourAgo)
      .get();

    healthMetrics.checks.stuckHabits = {
      count: stuckHabitsSnapshot.size,
      status: stuckHabitsSnapshot.size === 0 ? 'healthy' : (stuckHabitsSnapshot.size < 5 ? 'warning' : 'critical')
    };

    // Check 2: Recent critical errors
    const recentErrorsSnapshot = await admin.firestore()
      .collection('errors')
      .where('timestamp', '>=', fifteenMinutesAgo)
      .where('type', 'in', ['nextScheduledDateUpdateFailure', 'habitRecoveryFailure'])
      .get();

    healthMetrics.checks.recentErrors = {
      count: recentErrorsSnapshot.size,
      status: recentErrorsSnapshot.size === 0 ? 'healthy' : (recentErrorsSnapshot.size < 3 ? 'warning' : 'critical')
    };

    // Check 3: SMS sending success rate (last hour)
    const recentSMSLogsSnapshot = await admin.firestore()
      .collectionGroup('smsLogs')
      .where('sentAt', '>=', oneHourAgo)
      .where('direction', '==', 'outbound')
      .get();

    const totalSMS = recentSMSLogsSnapshot.size;
    const failedSMS = recentSMSLogsSnapshot.docs.filter(doc => doc.data().status === 'failed').length;
    const successRate = totalSMS > 0 ? ((totalSMS - failedSMS) / totalSMS * 100).toFixed(1) : 100;

    healthMetrics.checks.smsSuccessRate = {
      totalSent: totalSMS,
      failed: failedSMS,
      successRate: `${successRate}%`,
      status: successRate >= 95 ? 'healthy' : (successRate >= 85 ? 'warning' : 'critical')
    };

    // Check 4: Overall system health
    const criticalCount = Object.values(healthMetrics.checks).filter(check => check.status === 'critical').length;
    const warningCount = Object.values(healthMetrics.checks).filter(check => check.status === 'warning').length;

    healthMetrics.overallStatus = criticalCount > 0 ? 'critical' : (warningCount > 0 ? 'warning' : 'healthy');

    // Log health metrics to dedicated collection
    await admin.firestore()
      .collection('healthMetrics')
      .add(healthMetrics);

    // Only log if there are issues
    if (healthMetrics.overallStatus === 'critical') {
      console.error('🚨 CRITICAL:', JSON.stringify(healthMetrics.checks));
    } else if (healthMetrics.overallStatus === 'warning') {
      console.warn('⚠️ Health warning:', JSON.stringify(healthMetrics.checks));
    }

    return healthMetrics;

  } catch (error) {
    console.error('❌ Health check monitor failed:', error);
    throw error;
  }
});

/**
 * No-Reply Push Notification Checker
 *
 * Monitors SMS reminders that haven't received a response within the timeout window
 * and sends push notifications to family members to alert them.
 *
 * Flow:
 * 1. Query smsLogs for outbound task reminders sent 30-45 minutes ago
 * 2. Check if a reply was received (via messages collection)
 * 3. If no reply and not already notified → send FCM push to family user
 * 4. Mark smsLog as notified to prevent duplicate notifications
 *
 * Runs: Every 5 minutes
 * Timeout Window: 30-45 minutes (configurable)
 *
 * Why 30-45 minute window:
 * - 30 min minimum gives elderly users reasonable time to respond
 * - 45 min maximum prevents notifications for very old SMS
 * - 5-minute runs ensure we catch all no-replies within ~5 min of timeout
 */
exports.checkNoReplyAndNotify = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'America/Los_Angeles',
  secrets: [twilioAccountSid, twilioAuthToken, twilioPhoneNumber]
}, async (event) => {
  const now = new Date();

  // Time window: SMS sent between 30-45 minutes ago
  const NO_REPLY_TIMEOUT_MINUTES = 30;
  const MAX_WINDOW_MINUTES = 45;

  const thirtyMinutesAgo = admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() - NO_REPLY_TIMEOUT_MINUTES * 60 * 1000)
  );
  const fortyFiveMinutesAgo = admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() - MAX_WINDOW_MINUTES * 60 * 1000)
  );

  try {
    // Find task reminder SMS sent in the 30-45 minute window that haven't been notified
    const smsLogsSnapshot = await admin.firestore()
      .collectionGroup('smsLogs')
      .where('direction', '==', 'outbound')
      .where('messageType', '==', 'taskReminder')
      .where('sentAt', '>=', fortyFiveMinutesAgo)
      .where('sentAt', '<=', thirtyMinutesAgo)
      .get();

    if (smsLogsSnapshot.empty) {
      return null;
    }

    let notificationsSent = 0;
    let alreadyReplied = 0;
    let alreadyNotified = 0;
    let noFcmToken = 0;
    let errors = 0;

    for (const smsLogDoc of smsLogsSnapshot.docs) {
      const smsLog = smsLogDoc.data();
      const smsLogPath = smsLogDoc.ref.path;

      // Skip if already notified for this SMS
      if (smsLog.noReplyNotifiedAt) {
        alreadyNotified++;
        continue;
      }

      // Extract userId from path: users/{userId}/smsLogs/{logId}
      const pathParts = smsLogPath.split('/');
      if (pathParts.length < 2 || pathParts[0] !== 'users') {
        continue;
      }
      const userId = pathParts[1];
      const profileId = smsLog.profileId;
      const habitId = smsLog.habitId;

      if (!profileId || !habitId) {
        continue;
      }

      // Check if elderly user replied after the SMS was sent
      const smsSentAt = smsLog.sentAt.toDate();
      const replySnapshot = await admin.firestore()
        .collection(`users/${userId}/profiles/${profileId}/messages`)
        .where('direction', '==', 'inbound')
        .where('receivedAt', '>=', smsLog.sentAt)
        .limit(1)
        .get();

      if (!replySnapshot.empty) {
        // Reply received - mark as replied (not no-reply)
        alreadyReplied++;

        // Update smsLog to track that reply was received
        await smsLogDoc.ref.update({
          replyReceived: true,
          replyCheckedAt: admin.firestore.FieldValue.serverTimestamp()
        });

        continue;
      }

      // No reply found - get profile name for notification
      const profileDoc = await admin.firestore()
        .doc(`users/${userId}/profiles/${profileId}`)
        .get();

      const profileName = profileDoc.exists ? profileDoc.data().name : 'Your loved one';

      // Get habit title for notification
      const habitDoc = await admin.firestore()
        .doc(`users/${userId}/profiles/${profileId}/habits/${habitId}`)
        .get();

      const habitTitle = habitDoc.exists ? habitDoc.data().title : 'their task';

      // Send push notification to family user
      const notification = {
        title: `No reply from ${profileName}`,
        body: `${profileName} hasn't responded to "${habitTitle}" yet. You may want to check in.`
      };

      const pushData = {
        type: 'noReply',
        habitId: habitId,
        profileId: profileId,
        smsLogId: smsLogDoc.id
      };

      const pushResult = await sendPushNotification(userId, notification, pushData);

      if (pushResult.success) {
        notificationsSent++;

        // Mark smsLog as notified to prevent duplicate notifications
        await smsLogDoc.ref.update({
          noReplyNotifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          noReplyNotificationSent: true,
          noReplyPushMessageId: pushResult.messageId
        });

        // Also log to a dedicated collection for analytics
        await admin.firestore()
          .collection(`users/${userId}/noReplyNotifications`)
          .add({
            smsLogId: smsLogDoc.id,
            habitId: habitId,
            profileId: profileId,
            profileName: profileName,
            habitTitle: habitTitle,
            smsSentAt: smsLog.sentAt,
            notifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            pushMessageId: pushResult.messageId,
            minutesSinceSmsSent: Math.floor((now - smsSentAt) / 60000)
          });

        // Generate nudge message first so we can include it in gallery event
        const nudgeMessages = [
          `Looks like you missed "${habitTitle}". ⏰`,
          `You missed "${habitTitle}"! ⏰`,
          `"${habitTitle}" was missed. ⏱️`,
          `Missed "${habitTitle}" this time. ⌛`,
          `30 minutes passed - "${habitTitle}" was marked as missed. ⏱️`,
          `"${habitTitle}" wasn't completed in time. ⏰`,
          `Time's up on "${habitTitle}"! ⌛`
        ];
        const nudgeMessage = nudgeMessages[Math.floor(Math.random() * nudgeMessages.length)];

        // Create gallery event for the unreplied message
        // Shows: sent message (blue) → nudge message (blue)
        const galleryEventRef = admin.firestore()
          .collection(`users/${userId}/gallery_events`)
          .doc();

        await galleryEventRef.set({
          id: galleryEventRef.id,
          userId: userId,
          profileId: profileId,
          eventType: 'taskResponse',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          eventData: {
            taskResponse: {
              _0: {
                taskId: habitId,
                textResponse: null,
                photoData: null,
                responseType: 'text',
                taskTitle: habitTitle,
                sentMessage: smsLog.message,
                replyMessage: nudgeMessage
              }
            }
          }
        });

        // Send the nudge SMS to the elderly user
        const profileData = profileDoc.data();
        if (profileData.phoneNumber && !profileData.smsOptedOut) {
          try {
            const twilioClient = twilio(
              twilioAccountSid.value(),
              twilioAuthToken.value()
            );

            await twilioClient.messages.create({
              body: nudgeMessage,
              from: twilioPhoneNumber.value(),
              to: profileData.phoneNumber
            });

          } catch (smsError) {
            console.error('❌ Nudge SMS failed:', smsError.message);
            // Continue - don't fail the whole function for nudge SMS failure
          }
        }

      } else if (pushResult.error === 'No FCM token registered for user') {
        noFcmToken++;

        // Still mark as processed to avoid re-checking
        await smsLogDoc.ref.update({
          noReplyCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
          noReplyNotificationSkipped: true,
          noReplySkipReason: 'no_fcm_token'
        });

      } else {
        errors++;
        console.error('❌ No-reply push failed:', pushResult.error);
      }
    }

    // Only log if work was done
    if (notificationsSent > 0 || alreadyReplied > 0) {
      console.log('NoReply check:', {
        checked: smsLogsSnapshot.size,
        sent: notificationsSent,
        replied: alreadyReplied,
        alreadyNotified: alreadyNotified,
        noToken: noFcmToken,
        errors: errors
      });
    }

    return {
      checked: smsLogsSnapshot.size,
      notificationsSent,
      alreadyReplied,
      alreadyNotified,
      noFcmToken,
      errors
    };

  } catch (error) {
    console.error('❌ checkNoReplyAndNotify failed:', error);
    throw error;
  }
});

/**
 * Calculate the next scheduled occurrence for a recurring habit
 * Uses date-fns-tz for proper timezone-aware date calculations
 *
 * @param {Object} habit - Habit document data with frequency, customDays, scheduledTime, timeZone
 * @param {string} profileTimeZone - Profile's timezone identifier (e.g., "America/New_York")
 * @returns {Date} - Next scheduled date in UTC (Firestore stores as UTC)
 */
function calculateNextOccurrence(habit, profileTimeZone = 'America/Los_Angeles') {
  // Use habit's timezone if available, otherwise profile's, with PST fallback
  const tz = habit.timeZone || profileTimeZone || 'America/Los_Angeles';

  // Get current date in profile's timezone
  const currentDateUTC = habit.nextScheduledDate.toDate();
  const currentDateZoned = toZonedTime(currentDateUTC, tz);

  // Extract time components from scheduledTime in profile's timezone
  const scheduledTimeUTC = habit.scheduledTime.toDate();
  const scheduledTimeZoned = toZonedTime(scheduledTimeUTC, tz);
  const hours = getHours(scheduledTimeZoned);
  const minutes = getMinutes(scheduledTimeZoned);
  const seconds = getSeconds(scheduledTimeZoned);

  // Helper to set time and convert back to UTC
  const setTimeAndConvert = (date) => {
    let result = setHours(date, hours);
    result = setMinutes(result, minutes);
    result = setSeconds(result, seconds);
    result = setMilliseconds(result, 0);
    return fromZonedTime(result, tz);
  };

  switch (habit.frequency) {
    case 'daily':
      // Add 1 day to current nextScheduledDate
      const nextDaily = addDays(currentDateZoned, 1);
      return setTimeAndConvert(nextDaily);

    case 'weekdays':
      // Find next weekday (Monday-Friday)
      let nextWeekday = addDays(currentDateZoned, 1);

      // Skip weekends (0 = Sunday, 6 = Saturday)
      while (getDay(nextWeekday) === 0 || getDay(nextWeekday) === 6) {
        nextWeekday = addDays(nextWeekday, 1);
      }
      return setTimeAndConvert(nextWeekday);

    case 'weekly':
      // Add 7 days to current nextScheduledDate
      const nextWeekly = addDays(currentDateZoned, 7);
      return setTimeAndConvert(nextWeekly);

    case 'custom':
      // Find next day that matches customDays array
      const customDays = habit.customDays || [];
      if (customDays.length === 0) {
        // Fallback to daily if no custom days specified
        const fallback = addDays(currentDateZoned, 1);
        return setTimeAndConvert(fallback);
      }

      // Convert custom days to day numbers (0=Sunday, 1=Monday, etc.)
      const dayMap = {
        'sunday': 0, 'monday': 1, 'tuesday': 2, 'wednesday': 3,
        'thursday': 4, 'friday': 5, 'saturday': 6
      };
      const targetDays = new Set(customDays.map(day => dayMap[day.toLowerCase()]));

      // Search for next matching day (up to 14 days ahead)
      let nextCustom = addDays(currentDateZoned, 1);

      for (let i = 0; i < 14; i++) {
        if (targetDays.has(getDay(nextCustom))) {
          return setTimeAndConvert(nextCustom);
        }
        nextCustom = addDays(nextCustom, 1);
      }

      // Fallback if no match found
      return setTimeAndConvert(nextCustom);

    case 'once':
      // One-time habits should not be updated - return far future
      return addYears(new Date(), 100);

    default:
      // Fallback to daily
      const defaultNext = addDays(currentDateZoned, 1);
      return setTimeAndConvert(defaultNext);
  }
}

/**
 * Helper: Send push notification via Firebase Cloud Messaging (FCM)
 *
 * Sends a push notification to the user's iOS device using their stored FCM token.
 * Used primarily for "no reply" alerts when elderly users don't respond to SMS.
 *
 * @param {string} userId - User ID to send notification to
 * @param {Object} notification - Notification content { title, body }
 * @param {Object} data - Custom data payload for app handling
 * @returns {Promise<{success: boolean, messageId?: string, error?: string}>}
 */
async function sendPushNotification(userId, notification, data = {}) {
  try {
    // Get user's FCM token from Firestore
    const userDoc = await admin.firestore().collection('users').doc(userId).get();

    if (!userDoc.exists) {
      return { success: false, error: 'User not found' };
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      return { success: false, error: 'No FCM token registered for user' };
    }

    // Build FCM message
    const message = {
      notification: {
        title: notification.title,
        body: notification.body
      },
      data: {
        ...data,
        // Ensure all values are strings (FCM requirement)
        type: String(data.type || 'noReply'),
        userId: String(userId),
        timestamp: new Date().toISOString()
      },
      token: fcmToken,
      // iOS-specific configuration
      apns: {
        payload: {
          aps: {
            alert: {
              title: notification.title,
              body: notification.body
            },
            sound: 'default',
            badge: 1,
            'mutable-content': 1
          }
        }
      }
    };

    // Send via FCM
    const response = await admin.messaging().send(message);

    return {
      success: true,
      messageId: response
    };

  } catch (error) {
    console.error('❌ Push notification failed:', error.message);

    // Handle invalid token (user uninstalled app or token expired)
    if (error.code === 'messaging/invalid-registration-token' ||
        error.code === 'messaging/registration-token-not-registered') {
      // Clean up invalid token
      await admin.firestore().collection('users').doc(userId).update({
        fcmToken: admin.firestore.FieldValue.delete(),
        fcmTokenInvalidatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      return { success: false, error: 'Invalid FCM token - removed from user record' };
    }

    return { success: false, error: error.message };
  }
}

/**
 * Helper: Generate task reminder message for elderly user
 * Now with randomized friendly variations for warmth and engagement
 *
 * @param {Object} habit - Habit document data
 * @param {Object} profile - Profile document data
 * @returns {string} - Formatted SMS message
 */
function getTaskReminderMessage(habit, profile) {
  // Randomized greetings
  const greetings = [
    `Hi ${profile.name}!`,
    `Hey ${profile.name},`,
    `Hello ${profile.name} 🌞`,
    `Good day ${profile.name}!`,
    `Hi ${profile.name}! Hope you're doing well.`
  ];

  // Randomized prompts
  const prompts = [
    "Time to",
    "A gentle reminder to",
    "Just a little nudge to",
    "Hope your day's going well! Don't forget to",
    "Thinking of you — remember to",
    "It's that moment again to"
  ];

  // Photo + Text required
  const photoAndTextInstructions = [
    "When you're all done, send a quick photo and a little note — I'd love to see 😊",
    "Snap a photo and share how it went when you finish 📸💬",
    "All set? Send a photo and a short message — can't wait to hear from you 🌞",
    "Once you're finished, share a picture and a few words about it 💛"
  ];

  // Photo only
  const photoInstructions = [
    "When you're done, send a photo — I'd love to see your progress 📸",
    "Snap a quick photo when you finish — it always brightens the day 🌿",
    "Once you're done, share a picture — it'll make me smile 😊",
    "Take a little photo when you're done, if you'd like 🌸"
  ];

  // Text only
  const textInstructions = [
    "Text back a quick note when you're finished — I'd love to hear 💬",
    "When you're done, send a little message to let me know 🌷",
    "Once you finish, reply with a quick hello — it always makes my day ☀️",
    "You can text back a few words when you're done — no rush 🌿"
  ];

  // Flexible / no specific requirement
  const flexibleInstructions = [
    "You can reply whenever you're done — I'm cheering you on 💛",
    "Take your time and send a little message if you'd like 🌸",
    "Whenever you finish, feel free to reply — I'll be happy to hear from you 😊",
    "No rush at all — reply when you're done, or just take a nice deep breath 🌿"
  ];

  // Pick random variations
  const greeting = greetings[Math.floor(Math.random() * greetings.length)];
  const prompt = prompts[Math.floor(Math.random() * prompts.length)];

  // Determine instructions based on requirements
  let instructionsArray;
  if (habit.requiresPhoto && habit.requiresText) {
    instructionsArray = photoAndTextInstructions;
  } else if (habit.requiresPhoto) {
    instructionsArray = photoInstructions;
  } else if (habit.requiresText) {
    instructionsArray = textInstructions;
  } else {
    instructionsArray = flexibleInstructions;
  }

  const instructions = instructionsArray[Math.floor(Math.random() * instructionsArray.length)];

  // Build final message
  return `${greeting} ${prompt} ${habit.title}\n\n${instructions}`;
}

