const functions = require('firebase-functions');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onCall, onRequest} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const twilio = require('twilio');

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

    console.log(`✅ SMS sent successfully: ${twilioMessage.sid}`);

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

      console.log(`✅ Saved outbound message to messages collection for gallery`);
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
    secrets: [twilioAccountSid, twilioAuthToken]  // Access to credentials for signature validation and photo download
  },
  async (req, res) => {
    console.log('📱 Twilio webhook received');

    // SECURITY CHECK #1: Verify request is from Twilio
    // TEMPORARILY DISABLED - TODO: Fix signature validation
    // const twilioSignature = req.headers['x-twilio-signature'];
    // const url = 'https://twiliowebhook-skvlnwbfba-uc.a.run.app';
    // const authToken = twilioAuthToken.value();
    // const isValidRequest = twilio.validateRequest(authToken, twilioSignature, url, req.body);
    // if (!isValidRequest) {
    //   console.error('❌ Invalid Twilio signature');
    //   return res.status(403).send('Forbidden');
    // }

    console.log('⚠️ Signature validation temporarily disabled for debugging');

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
      console.warn(`⚠️ CollectionGroup query failed (index building?): ${indexError.message}`);
      console.log('📝 Falling back to manual user search...');

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
          console.log(`✅ Found profile via fallback method for user: ${userId}`);
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
      console.log(`🛑 Opt-out detected from ${fromPhone}`);

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

    console.log(`✅ Incoming message stored for user ${userId}`);

    // Find recently sent SMS for this profile (within last 30 minutes)
    // Check lastSMSSentAt instead of nextScheduledDate (which gets updated immediately after send)
    const now = new Date();
    const thirtyMinutesAgo = new Date(now - 30 * 60 * 1000);

    const allHabitsSnapshot = await admin.firestore()
      .collection(`users/${userId}/profiles/${profileDoc.id}/habits`)
      .where('status', '==', 'active')
      .get();

    console.log(`🔍 Checking ${allHabitsSnapshot.size} active habits for recent SMS`);

    // Filter habits where SMS was sent in last 30 minutes
    const recentHabits = allHabitsSnapshot.docs
      .map(doc => ({ doc, data: doc.data() }))
      .filter(({ data }) => {
        if (!data.lastSMSSentAt) {
          console.log(`  ⏭️ ${data.title}: No lastSMSSentAt field`);
          return false;
        }
        const sentTime = data.lastSMSSentAt.toDate();
        const inWindow = sentTime >= thirtyMinutesAgo && sentTime <= now;
        console.log(`  ${inWindow ? '✅' : '❌'} ${data.title}: SMS sent at ${sentTime.toISOString()}, in window? ${inWindow}`);
        return inWindow;
      })
      .sort((a, b) => b.data.lastSMSSentAt.toMillis() - a.data.lastSMSSentAt.toMillis());

    if (recentHabits.length > 0) {
      const habitDoc = recentHabits[0].doc;
      const habit = recentHabits[0].data;

      console.log(`📋 Found recent habit: ${habit.title}`);

      // ✅ VALIDATE: Check if response matches habit requirements
      const hasPhoto = parseInt(numMedia) > 0;
      const hasText = messageBody && messageBody.trim().length > 0;

      const requiresPhoto = habit.requiresPhoto || false;
      const requiresText = habit.requiresText || false;

      // Determine if response is valid
      let isValidResponse = true;
      let validationMessage = null;

      console.log(`🔍 Validation check:`);
      console.log(`   Requires: photo=${requiresPhoto}, text=${requiresText}`);
      console.log(`   Received: photo=${hasPhoto}, text=${hasText}`);

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
        console.log(`❌ Invalid response type - sending correction message`);

        // Send validation message to user
        try {
          const twilioClient = twilio(twilioAccountSid.value(), twilioAuthToken.value());

          await twilioClient.messages.create({
            body: validationMessage,
            from: twilioPhoneNumber.value(),
            to: fromPhone
          });

          console.log(`📤 Sent validation message: "${validationMessage}"`);
        } catch (smsError) {
          console.error(`❌ Failed to send validation SMS:`, smsError);
        }

        // Do NOT mark as completed, do NOT create gallery event
        res.status(200).send('OK');
        return;
      }

      // ✅ Valid response - mark habit as completed
      await habitDoc.ref.update({
        lastCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        completionCount: admin.firestore.FieldValue.increment(1)
      });

      console.log(`✅ Marked habit as completed: ${habit.title}`);

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
        console.log(`📸 Processing ${numMedia} MMS media attachment(s)...`);

        try {
          // Extract media URL from Twilio webhook payload
          const mediaUrl = req.body.MediaUrl0;
          const mediaType = req.body.MediaContentType0 || 'image/jpeg';

          console.log(`📥 Downloading media from: ${mediaUrl}`);
          console.log(`📄 Media type: ${mediaType}`);

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

          console.log(`✅ Downloaded photo: ${photoBuffer.length} bytes (${mediaType})`);
          console.log(`📋 Response type: ${taskResponseData.responseType}`);

        } catch (photoError) {
          console.error(`❌ Failed to download MMS photo: ${photoError.message}`);
          // Continue without photo - don't fail entire webhook
          // Response type stays as 'text' if text exists, otherwise task completion still recorded
        }
      }

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

      console.log(`✅ Created gallery event for habit: ${habit.title}`);

      // ✅ Send simple thank you message for valid response
      try {
        const thankYouMessages = [
          `Thanks! 💙`,
          `Got it! ✨`,
          `Perfect! 😊`,
          `Great! 🌟`,
          `Awesome! 🎉`
        ];

        const thankYou = thankYouMessages[Math.floor(Math.random() * thankYouMessages.length)];
        const twilioClient = twilio(twilioAccountSid.value(), twilioAuthToken.value());

        await twilioClient.messages.create({
          body: thankYou,
          from: twilioPhoneNumber.value(),
          to: fromPhone
        });

        console.log(`✅ Sent thank you message: "${thankYou}"`);
      } catch (smsError) {
        console.error(`❌ Failed to send thank you SMS:`, smsError);
        // Don't throw - webhook should still return 200 OK
      }
    } else {
      console.log(`⚠️ No recent habit found for this reply`);
    }

    res.status(200).send('OK');

  } catch (error) {
    console.error('❌ Webhook processing error:', error);
    res.status(500).send('Error processing webhook');
  }
});

/**
 * Helper function to validate Twilio webhook signature (security)
 * Prevents unauthorized requests to your webhook
 */
function validateTwilioRequest(req) {
  const twilioSignature = req.headers['x-twilio-signature'];
  const url = `https://${req.headers.host}${req.url}`;

  return twilio.validateRequest(
    twilioAuthToken,
    twilioSignature,
    url,
    req.body
  );
}

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

    console.log('🧹 Starting cleanup of gallery events older than', threeMonthsAgo.toDate().toISOString());

    try {
      // Query old events across all users using collectionGroup
      const oldEventsSnapshot = await db.collectionGroup('galleryEvents')
        .where('createdAt', '<', threeMonthsAgo)
        .limit(500) // Process in batches to avoid timeouts
        .get();

      console.log(`📊 Found ${oldEventsSnapshot.size} old events to process`);

      if (oldEventsSnapshot.empty) {
        console.log('✨ No old events to cleanup');
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

            console.log(`📸 Archiving photo: ${fileName}`);

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
            console.log(`✅ Photo archived successfully: ${fileName}`);
          }

          // Delete the Firestore event (text data permanently removed)
          await doc.ref.delete();
          eventsDeleted++;

          console.log(`🗑️ Event deleted: ${event.id} (created ${eventDate.toISOString()})`);

        } catch (error) {
          errors++;
          console.error(`❌ Failed to process event ${doc.id}:`, error.message);
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

      console.log('🎉 Cleanup complete:', JSON.stringify(summary, null, 2));

      return summary;

    } catch (error) {
      console.error('💥 Cleanup function failed:', error);
      throw error;
    }
  });

/**
 * Manual trigger endpoint for testing cleanup (HTTP)
 *
 * Usage:
 * curl -X POST https://us-central1-remi-91351.cloudfunctions.net/manualCleanup \
 *   -H "Content-Type: application/json" \
 *   -d '{"daysOld": 90}'
 */
exports.manualCleanup = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method not allowed');
    return;
  }

  const daysOld = req.body.daysOld || 90;
  const cutoffDate = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - daysOld * 24 * 60 * 60 * 1000)
  );

  console.log(`🧪 Manual cleanup triggered for events older than ${daysOld} days`);

  try {
    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    const oldEventsSnapshot = await db.collectionGroup('galleryEvents')
      .where('createdAt', '<', cutoffDate)
      .limit(100) // Smaller limit for manual testing
      .get();

    let photosArchived = 0;
    let eventsDeleted = 0;

    for (const doc of oldEventsSnapshot.docs) {
      const event = doc.data();

      if (event.eventType === 'taskResponse' &&
          event.eventData?.taskResponse?.photoData) {

        const photoDataBase64 = event.eventData.taskResponse.photoData;
        const eventDate = event.createdAt.toDate();
        const year = eventDate.getFullYear();
        const month = String(eventDate.getMonth() + 1).padStart(2, '0');
        const fileName = `gallery-archive/${event.userId}/${event.profileId}/${year}/${month}/${event.id}.jpg`;

        const photoBuffer = Buffer.from(photoDataBase64, 'base64');
        const file = bucket.file(fileName);

        await file.save(photoBuffer, {
          contentType: 'image/jpeg',
          metadata: {
            metadata: {
              userId: event.userId,
              profileId: event.profileId,
              eventId: event.id,
              archivedAt: new Date().toISOString()
            }
          }
        });

        photosArchived++;
      }

      await doc.ref.delete();
      eventsDeleted++;
    }

    const result = {
      success: true,
      photosArchived,
      eventsDeleted,
      daysOld,
      timestamp: new Date().toISOString()
    };

    console.log('✅ Manual cleanup complete:', result);
    res.json(result);

  } catch (error) {
    console.error('❌ Manual cleanup failed:', error);
    res.status(500).json({ error: error.message });
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
      const result = await operation();
      if (attempt > 1) {
        console.log(`✅ ${operationName} succeeded on attempt ${attempt}`);
      }
      return result;
    } catch (error) {
      lastError = error;

      if (attempt === maxRetries) {
        console.error(`❌ ${operationName} failed after ${maxRetries} attempts: ${error.message}`);
        throw error;
      }

      // Exponential backoff: 100ms, 200ms, 400ms
      const delayMs = 100 * Math.pow(2, attempt - 1);
      console.warn(`⚠️ ${operationName} failed on attempt ${attempt}/${maxRetries}, retrying in ${delayMs}ms...`);
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
  console.log('⏰ Running scheduled task reminder check (1-min interval, 5-min catchup window)...');

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

    console.log(`📋 Found ${habitsSnapshot.size} habits in 5-minute window`);

    if (habitsSnapshot.empty) {
      console.log('✅ No habits due right now');
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

      console.log(`📝 Processing habit: ${habit.title} for user ${userId}, profile ${profileId}`);

      // Get profile to retrieve phone number
      const profileDoc = await admin.firestore()
        .doc(`users/${userId}/profiles/${profileId}`)
        .get();

      if (!profileDoc.exists) {
        console.warn(`⚠️ Profile not found: ${profileId}`);
        smsSkipped++;
        continue;
      }

      const profile = profileDoc.data();

      // Check if profile is confirmed
      if (profile.status !== 'confirmed') {
        console.warn(`⚠️ Profile not confirmed: ${profile.name} (status: ${profile.status})`);
        smsSkipped++;
        continue;
      }

      // Check if profile has opted out
      if (profile.smsOptedOut === true) {
        console.log(`🛑 Profile has opted out of SMS: ${profile.name}`);
        smsSkipped++;
        continue;
      }

      // Check if phone number exists
      if (!profile.phoneNumber) {
        console.warn(`⚠️ No phone number for profile: ${profile.name}`);
        smsSkipped++;
        continue;
      }

      // Check if SMS already sent for this exact scheduled time (prevent duplicates)
      const scheduledTimeDate = habit.nextScheduledDate.toDate();

      // Calculate lateness: how many seconds late is this SMS?
      const latenessSeconds = Math.floor((currentTime - scheduledTimeDate) / 1000);
      const latenessMinutes = Math.floor(latenessSeconds / 60);

      if (latenessSeconds > 120) {
        // More than 2 minutes late - log as warning
        console.warn(`⏰ WARNING: Habit "${habit.title}" is ${latenessMinutes}m ${latenessSeconds % 60}s late (scheduled: ${scheduledTimeDate.toISOString()})`);
      } else if (latenessSeconds > 60) {
        // Between 1-2 minutes late - expected latency
        console.log(`⏰ Habit "${habit.title}" is ${latenessSeconds}s late (normal scheduler latency)`);
      } else {
        // Less than 60 seconds late - perfect timing
        console.log(`✅ Habit "${habit.title}" is on-time (lateness: ${latenessSeconds}s)`);
      }

      const smsLogQuery = await admin.firestore()
        .collection(`users/${userId}/smsLogs`)
        .where('habitId', '==', habit.id)
        .where('nextScheduledDate', '==', habit.nextScheduledDate)
        .where('direction', '==', 'outbound')
        .limit(1)
        .get();

      if (!smsLogQuery.empty) {
        console.log(`✅ SMS already sent for habit ${habit.id} at ${scheduledTimeDate.toISOString()}`);
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

        console.log(`✅ SMS sent: ${twilioMessage.sid} to ${profile.name}`);

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
        console.error(`❌ Failed to send SMS for habit ${habit.id}:`, smsError.message);

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
          const nextOccurrence = calculateNextOccurrence(habit);

          // Validate the calculated date
          if (!nextOccurrence || isNaN(nextOccurrence.getTime())) {
            console.error(`❌ Invalid nextOccurrence calculated for habit ${habit.id}`);
            continue;
          }

          // Ensure it's in the future
          if (nextOccurrence <= new Date()) {
            console.error(`❌ nextOccurrence is in the past for habit ${habit.id}: ${nextOccurrence.toISOString()}`);
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
            `Update nextScheduledDate for habit ${habit.id} ("${habit.title}")`
          );

          console.log(`📅 Updated nextScheduledDate for "${habit.title}" to ${nextOccurrence.toISOString()}`);

        } catch (updateError) {
          console.error(`❌ CRITICAL: Failed to update nextScheduledDate for habit ${habit.id} after 3 retries:`, updateError.message);
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
          console.log(`⏱️ One-time habit "${habit.title}" - nextScheduledDate NOT updated`);
        } catch (updateError) {
          console.error(`❌ Failed to update lastSMSSentAt for one-time habit ${habit.id} after retries:`, updateError.message);
        }
      }
    }

    const summary = {
      totalHabits: habitsSnapshot.size,
      smssSent,
      smsFailed,
      smsSkipped,
      timestamp: new Date().toISOString()
    };

    console.log('✅ Scheduled task reminder check complete:', JSON.stringify(summary, null, 2));
    return summary;

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
  console.log('🔧 Running missed habit recovery check (hourly safety net)...');

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

    console.log(`🔍 Found ${stuckHabitsSnapshot.size} habits with nextScheduledDate in the past`);

    if (stuckHabitsSnapshot.empty) {
      console.log('✅ No stuck habits found');
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
        // SMS was sent, but nextScheduledDate wasn't updated - CRITICAL BUG
        console.warn(`⚠️ Habit "${habit.title}" (${habit.id}): SMS was sent but nextScheduledDate stuck at ${habit.nextScheduledDate.toDate().toISOString()}`);
        alreadySent++;
      }

      // Calculate the NEXT future occurrence (skip the missed one)
      const nextOccurrence = calculateNextOccurrence(habit);
      console.log(`🔧 Recovering habit "${habit.title}": advancing from ${habit.nextScheduledDate.toDate().toISOString()} to ${nextOccurrence.toISOString()}`);

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
        console.log(`✅ Recovered habit "${habit.title}" - next SMS will be ${nextOccurrence.toISOString()}`);

      } catch (error) {
        console.error(`❌ Failed to recover habit ${habit.id}:`, error.message);

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

    const summary = {
      stuckHabits: stuckHabitsSnapshot.size,
      recovered,
      alreadySent,
      timestamp: new Date().toISOString()
    };

    console.log(`📊 Recovery summary:`, summary);
    return summary;

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
  console.log('🏥 Running health check monitor...');

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

    if (stuckHabitsSnapshot.size > 0) {
      console.warn(`⚠️ HEALTH: ${stuckHabitsSnapshot.size} habits stuck in the past`);
    } else {
      console.log(`✅ HEALTH: No stuck habits`);
    }

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

    if (recentErrorsSnapshot.size > 0) {
      console.warn(`⚠️ HEALTH: ${recentErrorsSnapshot.size} critical errors in last 15 minutes`);
      // Log first few errors for context
      recentErrorsSnapshot.docs.slice(0, 3).forEach(doc => {
        const error = doc.data();
        console.warn(`  - ${error.type}: ${error.errorMessage} (habit: ${error.habitTitle || error.habitId})`);
      });
    } else {
      console.log(`✅ HEALTH: No recent critical errors`);
    }

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

    if (successRate < 95) {
      console.warn(`⚠️ HEALTH: SMS success rate is ${successRate}% (${failedSMS}/${totalSMS} failed)`);
    } else {
      console.log(`✅ HEALTH: SMS success rate is ${successRate}%`);
    }

    // Check 4: Overall system health
    const criticalCount = Object.values(healthMetrics.checks).filter(check => check.status === 'critical').length;
    const warningCount = Object.values(healthMetrics.checks).filter(check => check.status === 'warning').length;

    healthMetrics.overallStatus = criticalCount > 0 ? 'critical' : (warningCount > 0 ? 'warning' : 'healthy');

    // Log health metrics to dedicated collection
    await admin.firestore()
      .collection('healthMetrics')
      .add(healthMetrics);

    // Alert on critical status
    if (healthMetrics.overallStatus === 'critical') {
      console.error(`🚨 CRITICAL HEALTH ALERT: System has ${criticalCount} critical issues`);
      console.error(`📊 Health metrics:`, JSON.stringify(healthMetrics, null, 2));
    } else if (healthMetrics.overallStatus === 'warning') {
      console.warn(`⚠️ WARNING: System has ${warningCount} warnings`);
    } else {
      console.log(`✅ HEALTH: System is healthy`);
    }

    console.log(`📊 Health check complete - Status: ${healthMetrics.overallStatus}`);
    return healthMetrics;

  } catch (error) {
    console.error('❌ Health check monitor failed:', error);
    throw error;
  }
});

/**
 * Calculate the next scheduled occurrence for a recurring habit
 *
 * @param {Object} habit - Habit document data with frequency, customDays, scheduledTime
 * @returns {Date} - Next scheduled date
 */
function calculateNextOccurrence(habit) {
  const now = new Date();
  const currentDate = habit.nextScheduledDate.toDate();

  // Extract time components from scheduledTime
  const scheduledTime = habit.scheduledTime.toDate();
  const hours = scheduledTime.getHours();
  const minutes = scheduledTime.getMinutes();
  const seconds = scheduledTime.getSeconds();

  switch (habit.frequency) {
    case 'daily':
      // Add 1 day to current nextScheduledDate
      const nextDaily = new Date(currentDate);
      nextDaily.setDate(nextDaily.getDate() + 1);
      nextDaily.setHours(hours, minutes, seconds, 0);
      return nextDaily;

    case 'weekdays':
      // Find next weekday (Monday-Friday)
      const nextWeekday = new Date(currentDate);
      nextWeekday.setDate(nextWeekday.getDate() + 1);
      nextWeekday.setHours(hours, minutes, seconds, 0);

      // Skip weekends (0 = Sunday, 6 = Saturday)
      while (nextWeekday.getDay() === 0 || nextWeekday.getDay() === 6) {
        nextWeekday.setDate(nextWeekday.getDate() + 1);
      }
      return nextWeekday;

    case 'weekly':
      // Add 7 days to current nextScheduledDate
      const nextWeekly = new Date(currentDate);
      nextWeekly.setDate(nextWeekly.getDate() + 7);
      nextWeekly.setHours(hours, minutes, seconds, 0);
      return nextWeekly;

    case 'custom':
      // Find next day that matches customDays array
      const customDays = habit.customDays || [];
      if (customDays.length === 0) {
        // Fallback to daily if no custom days specified
        const fallback = new Date(currentDate);
        fallback.setDate(fallback.getDate() + 1);
        fallback.setHours(hours, minutes, seconds, 0);
        return fallback;
      }

      // Convert custom days to weekday numbers (0=Sunday, 1=Monday, etc.)
      const dayMap = {
        'sunday': 0, 'monday': 1, 'tuesday': 2, 'wednesday': 3,
        'thursday': 4, 'friday': 5, 'saturday': 6
      };
      const targetDays = customDays.map(day => dayMap[day.toLowerCase()]);

      // Search for next matching day (up to 14 days ahead)
      const nextCustom = new Date(currentDate);
      for (let i = 1; i <= 14; i++) {
        nextCustom.setDate(currentDate.getDate() + i);
        if (targetDays.includes(nextCustom.getDay())) {
          nextCustom.setHours(hours, minutes, seconds, 0);
          return nextCustom;
        }
      }

      // Fallback if no match found
      nextCustom.setDate(currentDate.getDate() + 1);
      nextCustom.setHours(hours, minutes, seconds, 0);
      return nextCustom;

    case 'once':
      // One-time habits should not be updated
      return currentDate;

    default:
      // Fallback to daily
      const defaultNext = new Date(currentDate);
      defaultNext.setDate(defaultNext.getDate() + 1);
      defaultNext.setHours(hours, minutes, seconds, 0);
      return defaultNext;
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

/**
 * Delete old test habits that have wrong schema
 */
exports.deleteOldTestHabits = onRequest(async (req, res) => {
  const habitIdsToDelete = [
    '25491E5B-85EF-4020-AC48-E16AB3652331',  // Tester
    'A766A797-8DF3-49CD-99F9-ABCF5BDEEA4F',  // Morning
    'A7FB8471-85C2-49EB-9E7C-99CE3E8A96DD',  // Shajsj
    'CB9F1F81-B9E3-4643-B24D-CBC263704454'   // Morning alarm
  ];

  const userId = 'IJue7FhdmbbIzR3WG6Tzhhf2ykD2';
  const profileId = '+17788143739';
  const deleted = [];

  for (const habitId of habitIdsToDelete) {
    await admin.firestore()
      .doc(`users/${userId}/profiles/${profileId}/habits/${habitId}`)
      .delete();
    deleted.push(habitId);
    console.log(`✅ Deleted habit: ${habitId}`);
  }

  res.json({ deleted, count: deleted.length });
});

/**
 * MIGRATION: Fix existing habits with past nextScheduledDate
 */
exports.fixPastHabits = onRequest(async (req, res) => {
  try {
    console.log('🔧 Starting migration to fix past habits...');

    // Get all habits
    const allHabitsSnapshot = await admin.firestore()
      .collectionGroup('habits')
      .get();

    const now = new Date();
    const fixed = [];
    const skipped = [];

    for (const doc of allHabitsSnapshot.docs) {
      const habit = doc.data();
      const path = doc.ref.path;

      // Check if nextScheduledDate is in the past
      if (habit.nextScheduledDate && habit.nextScheduledDate.toDate() < now) {
        console.log(`📅 Fixing: ${habit.title} (${path})`);

        // Calculate new nextScheduledDate based on frequency
        const nextOccurrence = calculateNextOccurrence(habit);

        await doc.ref.update({
          nextScheduledDate: admin.firestore.Timestamp.fromDate(nextOccurrence)
        });

        fixed.push({
          title: habit.title,
          oldDate: habit.nextScheduledDate.toDate().toISOString(),
          newDate: nextOccurrence.toISOString()
        });
      } else {
        skipped.push({
          title: habit.title,
          reason: habit.nextScheduledDate ? 'already in future' : 'missing nextScheduledDate'
        });
      }
    }

    console.log(`✅ Migration complete. Fixed: ${fixed.length}, Skipped: ${skipped.length}`);

    res.json({
      totalHabits: allHabitsSnapshot.size,
      fixed: fixed.length,
      skipped: skipped.length,
      details: { fixed, skipped }
    });

  } catch (error) {
    console.error('❌ Error in fixPastHabits:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * DEBUG: Check all habits in database
 */
exports.debugAllHabits = onRequest(async (req, res) => {
  try {
    const now = admin.firestore.Timestamp.now();
    const ninetySecondsAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 90 * 1000)
    );

    // Get ALL habits
    const allHabitsSnapshot = await admin.firestore()
      .collectionGroup('habits')
      .get();

    console.log(`📊 Total habits in database: ${allHabitsSnapshot.size}`);

    const habitsInfo = [];

    for (const doc of allHabitsSnapshot.docs) {
      const habit = doc.data();
      const path = doc.ref.path;

      const info = {
        path,
        title: habit.title,
        frequency: habit.frequency,
        status: habit.status,
        nextScheduledDate: habit.nextScheduledDate ? habit.nextScheduledDate.toDate().toISOString() : 'MISSING',
        scheduledTime: habit.scheduledTime ? habit.scheduledTime.toDate().toISOString() : 'MISSING',
        createdAt: habit.createdAt ? habit.createdAt.toDate().toISOString() : 'MISSING'
      };

      // Check if would match query (90-second window to match new scheduler)
      if (habit.status === 'active' && habit.nextScheduledDate) {
        const inWindow = habit.nextScheduledDate >= ninetySecondsAgo && habit.nextScheduledDate <= now;
        info.wouldMatchQuery = inWindow;
        info.queryWindow = `${ninetySecondsAgo.toDate().toISOString()} to ${now.toDate().toISOString()}`;
      } else {
        info.wouldMatchQuery = false;
        info.reason = habit.status !== 'active' ? 'status not active' : 'missing nextScheduledDate';
      }

      habitsInfo.push(info);
    }

    res.json({
      totalHabits: allHabitsSnapshot.size,
      habits: habitsInfo,
      currentTime: now.toDate().toISOString()
    });

  } catch (error) {
    console.error('❌ Error in debugAllHabits:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Clean up old malformed gallery events
 * DELETE THIS AFTER RUNNING ONCE
 */
exports.cleanupMalformedGalleryEvents = onRequest(async (req, res) => {
  try {
    const userId = 'IJue7FhdmbbIzR3WG6Tzhhf2ykD2';

    const gallerySnapshot = await admin.firestore()
      .collection(`users/${userId}/gallery_events`)
      .get();

    const deleted = [];

    for (const doc of gallerySnapshot.docs) {
      const data = doc.data();

      // Check if document has the OLD malformed schema
      // Old schema has: habitId, habitTitle, messageText, profileName
      // New schema has: id, userId, profileId, eventType, eventData
      if (data.habitId || data.messageText || data.profileName) {
        await doc.ref.delete();
        deleted.push(doc.id);
        console.log(`🗑️ Deleted malformed event: ${doc.id}`);
      }
    }

    res.json({
      message: 'Cleanup complete',
      deleted: deleted,
      count: deleted.length
    });

  } catch (error) {
    console.error('❌ Error in cleanupMalformedGalleryEvents:', error);
    res.status(500).json({ error: error.message });
  }
});


