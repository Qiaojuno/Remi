# Remi Notification System - Architecture Diagrams

## High-Level System Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         REMI NOTIFICATION SYSTEM                     │
└──────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────┐
                    │   Family Members        │
                    │   (iOS App)             │
                    │   • Dashboard           │
                    │   • Habits Tab          │
                    │   • Gallery (Chat)      │
                    └────────────┬────────────┘
                                 │
                    ┌────────────┴───────────┐
                    │                        │
          ┌─────────▼──────────┐  ┌──────────▼──────────┐
          │ 1. TASK CREATION   │  │ 3. REAL-TIME SYNC   │
          │ ─────────────────  │  │ ──────────────────  │
          │ TaskViewModel      │  │ DataSyncCoordinator │
          │ Creates tasks in   │  │ Firestore listeners │
          │ Firestore          │  │ Combine publishers  │
          │ Sets nextScheduled │  │ Updates family UIs  │
          │ Date               │  │                     │
          └─────────┬──────────┘  └──────────┬──────────┘
                    │                        │
                    └───────────┬────────────┘
                                │
                    ┌───────────▼──────────────┐
                    │        FIRESTORE         │
                    │ ───────────────--------- │
                    │ users/{}                 │
                    │ ├─ profiles/{}           │
                    │ │ ├─ habits/{}           │
                    │ │ │ ├─ title             │
                    │ │ │ ├─ nextScheduledDate |
                    │ │ │ ├─ lastSMSSentAt     |
                    │ │ │ └─ frequency         |
                    │ │ ├─ messages/{}         │
                    │ │ └─ responses/          │
                    │ └─ smsLogs/{}            │
                    └────────┬────────---------┘
                             │
                    ┌────────▼────────-┐
                    │ 2. SMS SCHEDULER │
                    │ ─────────────────│
                    │ Cloud Scheduler  │
                    │ Every 1 minute   │
                    │ Finds tasks ready│
                    │ Sends via Twilio │
                    │ Updates tracking │
                    └────────┬────────-┘
                             │
                    ┌────────▼────────┐
                    │   TWILIO        │
                    │ ─────────────── │
                    │ sendSMS()       │
                    │ Sends SMS       │
                    │ to elderly      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  ELDERLY USER   │
                    │  (Feature Phone)│
                    │  ────────────── │
                    │  • Receives SMS │
                    │  • Replies SMS  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ TWILIO WEBHOOK  │
                    │ ──────────────  │
                    │ Receives reply  │
                    │ Validates       │
                    │ Stores message  │
                    │ Creates event   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   FIRESTORE     │
                    │  (Webhook       │
                    │   Storage)      │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ BROADCAST VIA   │
                    │ REALTIM SYNC    │
                    │ (Loop back to 3)│
                    └─────────────────┘
```

---

## Component Interaction Sequence

```
TASK CREATION → SCHEDULING → DELIVERY → RESPONSE → BROADCAST

┌──────────────────────────────────────────────────────────────────────┐
│ PHASE 1: FAMILY CREATES TASK                                         │
└──────────────────────────────────────────────────────────────────────┘

    Family Member                     iOS App
        │
        ├─ Opens Habits tab
        │
        ├─ Taps "Create Task"
        │
        ├─ Fills form:
        │  ├─ Title: "Take medication"
        │  ├─ Profile: "Grandma"
        │  ├─ Time: 9:00 AM
        │  └─ Frequency: Daily
        │
        └─ Taps "Save"
                  │
                  ▼
          TaskViewModel.createTask()
                  │
                  ├─ Validates form
                  │
                  ├─ Calculates firstOccurrence
                  │  └─ Returns: tomorrow 9:00 AM
                  │
                  ├─ Creates Task object:
                  │  ├─ id: "habit-123"
                  │  ├─ title: "Take medication"
                  │  ├─ scheduledTime: 9:00 AM
                  │  ├─ nextScheduledDate: tomorrow 9:00 AM
                  │  └─ frequency: "daily"
                  │
                  └─> DatabaseService.createTask()
                          │
                          ▼
                      Firebase Firestore
                      users/{userId}/profiles/{profileId}/habits/habit-123
                      {
                        "title": "Take medication",
                        "scheduledTime": timestamp,
                        "nextScheduledDate": timestamp,
                        "lastSMSSentAt": null,
                        "status": "active",
                        "frequency": "daily"
                      }

┌──────────────────────────────────────────────────────────────────────┐
│ PHASE 2: CLOUD SCHEDULER SENDS REMINDER (Every 1 minute)             │
└──────────────────────────────────────────────────────────────────────┘

    Cloud Scheduler (1 min interval)
        │
        └─ sendScheduledTaskReminders()
               │
               ├─ Calculate time windows:
               │  ├─ now = current timestamp
               │  └─ 5 minutes ago = now - 5 min
               │
               ├─ Query Firestore:
               │  └─ WHERE nextScheduledDate >= 5 min ago
               │     AND   nextScheduledDate <= now
               │     AND   status == "active"
               │
               ├─ Found: habit-123
               │  └─ nextScheduledDate: 9:00 AM (matches!)
               │
               ├─ Check if already sent:
               │  ├─ lastSMSSentAt = null ✓
               │  └─ Not yet sent, proceed
               │
               ├─ Generate SMS:
               │  └─ "Hi! Time to take your medication"
               │
               ├─ Call Twilio API:
               │  ├─ to: "+1778-814-3739"
               │  ├─ from: "+1888-SMS-HALLO"
               │  └─ message: "Hi! Time to take your medication"
               │
               ├─ Update Firestore:
               │  ├─ SET lastSMSSentAt = 9:00 AM (now)
               │  ├─ SET nextScheduledDate = tomorrow 9:00 AM
               │  └─ (Calculate next occurrence + 1 day for daily)
               │
               └─ Log to users/{userId}/smsLogs/

┌──────────────────────────────────────────────────────────────────────┐
│ PHASE 3: ELDERLY USER RECEIVES & REPLIES                             │
└──────────────────────────────────────────────────────────────────────┘

    Elderly User                      SMS Gateway
        │
        ├─ Receives SMS:
        │  "Hi! Time to take your medication"
        │
        ├─ Types reply:
        │  "YES"
        │
        └─ Sends SMS reply
               │
               ▼
           Twilio Gateway
               │
               └─ Route to webhook:
                  POST /twilioWebhook
                  {
                    "From": "+1778-814-3739",
                    "Body": "YES",
                    "MessageSid": "SM1234567890",
                    "NumMedia": "0"
                  }

┌──────────────────────────────────────────────────────────────────────┐
│ PHASE 4: WEBHOOK PROCESSES RESPONSE                                  │
└──────────────────────────────────────────────────────────────────────┘

    Cloud Function: twilioWebhook()
        │
        ├─ Validate Twilio Signature:
        │  ├─ Reconstruct full URL (handles Cloud Functions Gen 2 routing)
        │  ├─ If host contains "cloudfunctions.net" → append "/twilioWebhook"
        │  ├─ Verify signature with Twilio auth token
        │  └─ Reject if invalid ✓
        │
        ├─ Extract data:
        │  ├─ fromPhone: "+1778-814-3739"
        │  ├─ messageBody: "YES"
        │  ├─ numMedia: 0
        │  └─ twilioSid: "SM1234567890"
        │
        ├─ Find profile by phone
        │  └─ Found: profile-456
        │
        ├─ Store message:
        │  ├─ users/{userId}/profiles/{profileId}/messages/
        │  └─ users/{userId}/messages/
        │
        ├─ Find recent habit:
        │  └─ Search lastSMSSentAt >= 30 min ago
        │     Found: habit-123
        │
        ├─ Validate response:
        │  ├─ requiresPhoto: false
        │  ├─ requiresText: true
        │  ├─ Has text: true ✓
        │  └─ Valid response!
        │
        ├─ Send thank you SMS:
        │  ├─ Reply: "Thank you! We'll let your family know ❤️"
        │  ├─ Twilio sends immediately
        │  └─ Store replyMessage for gallery event
        │
        ├─ Create SMSResponse:
        │  ├─ taskId: "habit-123"
        │  ├─ textResponse: "YES"
        │  ├─ isCompleted: true
        │  └─ Saves to database
        │
        ├─ Create GalleryHistoryEvent:
        │  ├─ type: "taskCompletion"
        │  ├─ text: "Grandma completed medication"
        │  ├─ replyMessage: "Thank you! We'll let your family know ❤️"
        │  ├─ timestamp: now
        │  └─ ALL DATA IN SINGLE WRITE (iOS listener only processes .added)
        │
        └─ Update task completion metrics:
             ├─ completionCount + 1
             └─ lastCompletedAt = now

┌──────────────────────────────────────────────────────────────────────┐
│ PHASE 5: BROADCAST TO FAMILY (Real-time Sync)                        │
└──────────────────────────────────────────────────────────────────────┘

    Firestore Change Event
    (New message in profiles/{profileId}/messages/)
        │
        └─> DatabaseService.observeIncomingSMSMessages()
                │
                ├─ Emits SMSResponse via Combine stream
                │
                └─> App.setupSMSListener()
                        │
                        └─> DataSyncCoordinator.broadcastSMSResponse()
                                │
                                └─> smsResponsesSubject.send(response)

    All Family Members' Apps
    (Subscribed to smsResponses stream)
        │
        ├─ Receive broadcast immediately
        │
        ├─ ProfileViewModel:
        │  └─ Gallery shows new message bubble
        │
        ├─ DashboardViewModel:
        │  └─ Task marked as completed
        │
        └─ UI Updates (real-time):
             ├─ Gallery shows "Grandma: YES"
             ├─ Task completion percentage updates
             └─ Checkmark appears on dashboard
```

---

## Data Structure Relationships

```
┌────────────────────────────────────────────────────────────────────┐
│ FIRESTORE HIERARCHY                                                │
└────────────────────────────────────────────────────────────────────┘

users/{userId}
│
├─ [User Document]
│  ├─ email
│  ├─ name
│  ├─ smsQuotaUsed
│  └─ smsQuotaLimit
│
├─ messages/ [Collection]
│  │ (User-level SMS history - audit trail)
│  │
│  └─ {messageId}
│     ├─ fromPhone: "+1778..."
│     ├─ toPhone: "+1888..."
│     ├─ messageBody: "YES"
│     ├─ direction: "inbound" or "outbound"
│     ├─ twilioSid: "SM1234..."
│     └─ receivedAt: timestamp
│
├─ smsLogs/ [Collection]
│  │ (SMS delivery audit trail)
│  │
│  └─ {logId}
│     ├─ to: "+1778..."
│     ├─ message: "Hi! Time for meds"
│     ├─ profileId: "profile-456"
│     ├─ messageType: "taskReminder"
│     ├─ twilioSid: "SM1234..."
│     └─ sentAt: timestamp
│
└─ profiles/{profileId}
   │ [Elderly Profile Document]
   │
   ├─ name: "Grandma"
   ├─ phoneNumber: "+1778..."
   ├─ status: "confirmed" or "pending"
   │
   ├─ habits/ [Collection]
   │ │ (Care Tasks/Reminders)
   │ │
   │ └─ {habitId}
   │    ├─ title: "Take medication"
   │    ├─ description: "Morning meds with water"
   │    ├─ category: "medication"
   │    │
   │    ├─ SCHEDULING FIELDS:
   │    ├─ scheduledTime: timestamp (9:00 AM)
   │    ├─ nextScheduledDate: timestamp ⭐ KEY FIELD
   │    ├─ lastSMSSentAt: timestamp (when SMS sent) ⭐ KEY FIELD
   │    │
   │    ├─ RECURRENCE:
   │    ├─ frequency: "daily" or "weekly" or "custom"
   │    ├─ customDays: ["Monday", "Wednesday", "Friday"]
   │    │
   │    ├─ VALIDATION:
   │    ├─ requiresPhoto: boolean
   │    ├─ requiresText: boolean
   │    │
   │    ├─ TRACKING:
   │    ├─ completionCount: number
   │    ├─ lastCompletedAt: timestamp
   │    ├─ status: "active" or "paused" or "archived"
   │    │
   │    └─ METADATA:
   │       ├─ createdAt: timestamp
   │       ├─ lastModifiedAt: timestamp
   │       └─ userId: "{userId}"
   │
   ├─ messages/ [Collection]
   │ │ (SMS Messages - Profile level for gallery)
   │ │ [DUPLICATE of users/{userId}/messages/ - for query optimization]
   │ │
   │ └─ {messageId}
   │    ├─ fromPhone: "+1778..."
   │    ├─ toPhone: "+1888..."
   │    ├─ messageBody: "YES"
   │    ├─ direction: "inbound"
   │    ├─ twilioSid: "SM1234..."
   │    ├─ receivedAt: timestamp
   │    └─ profileId: "{profileId}"
   │
   └─ responses/ [Collection]
      │ (Structured SMS Responses - New)
      │
      └─ {responseId}
         ├─ taskId: "{habitId}"
         ├─ textResponse: "YES"
         ├─ photoData: binary or null
         ├─ isCompleted: boolean
         ├─ receivedAt: timestamp
         └─ responseType: "text" or "photo"
```

---

## Scheduler Logic Flow

```
┌────────────────────────────────────────────────────────────────────┐
│ SENDSCHEDULEDTASKREMINDERS EXECUTION                               │
└────────────────────────────────────────────────────────────────────┘

START: sendScheduledTaskReminders()
│
├─ Calculate time window:
│  ├─ now = current timestamp
│  ├─ fiveMinutesAgo = now - 5 minutes
│  └─ ninety_seconds_ago = now - 90 seconds (for query)
│
├─ Query Firebase:
│  ├─ FROM: all users/{userId}/profiles/{profileId}/habits
│  ├─ WHERE: status = "active"
│  ├─ WHERE: nextScheduledDate >= fiveMinutesAgo
│  ├─ WHERE: nextScheduledDate <= now
│  └─ RESULT: [habit-123, habit-456, ...]
│
├─ For each matching habit:
│  │
│  ├─ Log lateness:
│  │  ├─ latenessSeconds = (now - nextScheduledDate) / 1000
│  │  ├─ if >= 60 seconds: log as WARNING
│  │  └─ if < 60 seconds: log as normal scheduler latency
│  │
│  ├─ Check if already sent:
│  │  ├─ Query smsLogs where:
│  │  │  ├─ profileId = habit.profileId
│  │  │  ├─ nextScheduledDate = habit.nextScheduledDate
│  │  │  └─ RESULT: [previous log or empty]
│  │  │
│  │  ├─ If found:
│  │  │  └─ SKIP (already sent)
│  │  │
│  │  └─ If NOT found:
│  │     └─ PROCEED (haven't sent yet)
│  │
│  ├─ [DISABLED] Schedule local notification
│  │  └─ (In MVP, local notifications disabled)
│  │
│  ├─ Generate SMS text:
│  │  ├─ Switch on category:
│  │  ├─ "medication" → "Hi! Time to take your medication"
│  │  ├─ "exercise" → "Time for your walk!"
│  │  └─ "social" → "Call someone to catch up!"
│  │
│  ├─ Send via Twilio:
│  │  ├─ TRY:
│  │  │  ├─ twilioClient.messages.create({
│  │  │  │   ├─ to: profile.phoneNumber
│  │  │  │   ├─ from: TWILIO_PHONE_NUMBER
│  │  │  │   └─ body: smsText
│  │  │  │ })
│  │  │  │
│  │  │  └─ ON SUCCESS:
│  │  │     ├─ Log SMS to smsLogs collection
│  │  │     ├─ Emit metric/event
│  │  │     └─ sentCount++
│  │  │
│  │  └─ CATCH ERROR:
│  │     ├─ Log error to Firebase
│  │     ├─ failureCount++
│  │     └─ CONTINUE (don't update nextScheduledDate)
│  │
│  ├─ CRITICAL: Update Firestore (outside try-catch):
│  │  ├─ Retry up to 3 times:
│  │  │  ├─ Update {habitId}:
│  │  │  │  ├─ SET lastSMSSentAt = now
│  │  │  │  └─ SET nextScheduledDate = calculateNext()
│  │  │  │
│  │  │  └─ ON RETRY FAILURE:
│  │  │     └─ Log to errorLogs collection
│  │  │
│  │  └─ ON SUCCESS:
│  │     └─ Log update success
│  │
│  └─ calculateNext():
│     ├─ Get current nextScheduledDate
│     ├─ Switch on frequency:
│     ├─ "daily" → add 1 day
│     ├─ "weekly" → add 7 days
│     ├─ "custom" → find next matching customDays[]
│     └─ RETURN: next occurrence timestamp
│
├─ Log summary:
│  ├─ totalHabits: count checked
│  ├─ sentCount: SMS successfully sent
│  ├─ skipCount: already sent
│  ├─ failureCount: Twilio errors
│  └─ updateFailureCount: Firestore update failures
│
└─ END

NEXT RUN: Wait 1 minute, execute again
```

---

## Duplicate Prevention Strategy

```
┌────────────────────────────────────────────────────────────────────┐
│ HOW DUPLICATES ARE PREVENTED                                       │
└────────────────────────────────────────────────────────────────────┘

SCENARIO 1: Cloud Scheduler runs twice in same minute
────────────────────────────────────────────────────────────

First Run:
  Query: habits where nextScheduledDate = 9:00 AM
  Result: Found habit-123
  SMS: Sends "Time to take medication" ✓
  Update: lastSMSSentAt = 9:00 AM, nextScheduledDate = tomorrow 9:00 AM

Second Run (seconds later, same minute):
  Query: habits where nextScheduledDate = 9:00 AM
  Result: EMPTY (date already updated to tomorrow) ✓
  Action: No habits match, nothing sent ✓

PROTECTION: ✅ Effective - nextScheduledDate update prevents re-run match


SCENARIO 2: Update fails but SMS was sent
────────────────────────────────────────────

Execution:
  SMS sent: ✓ "Time to take medication"
  Update fails: ✗ Firestore write error
  State: lastSMSSentAt = null, nextScheduledDate = 9:00 AM

Next minute run:
  Query: habits where nextScheduledDate = 9:00 AM
  Result: Found habit-123 again
  Check smsLogs: lastSMSSentAt field
    ├─ if null: Might send duplicate ⚠️
    └─ if set: Skip (already sent) ✓

PROTECTION: ⚠️ Partial - requires lastSMSSentAt to be set
RECOVERY: recoverMissedHabits() function finds and fixes


SCENARIO 3: Response webhook runs twice for same SMS
──────────────────────────────────────────────────────

First Webhook Call:
  messageBody: "YES"
  twilioSid: "SM1234567890"
  Store message: users/{userId}/profiles/{profileId}/messages/
  Action: Create new message document ✓

Second Webhook Call (same SMS):
  twilioSid: "SM1234567890" (same)
  Store message: users/{userId}/profiles/{profileId}/messages/
  Action: Firestore creates NEW document (different messageId) ⚠️
  Result: Potential duplicate message in gallery

PROTECTION: ⚠️ Weak - Firestore doesn't deduplicate on twilioSid
IMPROVEMENT: Should use twilioSid as document ID


SCENARIO 4: Gallery event duplicates
──────────────────────────────────────

Fixed via ProfileViewModel tracking:
  Line ~523: profileViewModel?.populateGalleryEventTrackingSet()
  Creates Set<String> of processed gallery event IDs
  Prevents duplicate UI rendering even if events are re-broadcast

PROTECTION: ✅ Effective at UI level
```

---

## Recovery & Monitoring

```
┌────────────────────────────────────────────────────────────────────┐
│ AUTOMATED RECOVERY FUNCTIONS                                       |
└────────────────────────────────────────────────────────────────────┘

1. sendScheduledTaskReminders()
   ├─ Runs: Every 1 minute
   ├─ Finds: Habits due in last 5 minutes
   ├─ Sends: SMS reminders
   └─ Fixes: Updates nextScheduledDate

2. recoverMissedHabits()
   ├─ Runs: Every 60 minutes
   ├─ Finds: Habits stuck > 5 minutes in past
   ├─ Checks: Was SMS actually sent?
   ├─ Fixes: Advances nextScheduledDate to future
   └─ Logs: Recovery attempts to errorLogs

3. healthCheckMonitor()
   ├─ Runs: Every 15 minutes
   ├─ Detects:
   │  ├─ Habits stuck in past > 1 hour
   │  ├─ Update failures in last run
   │  ├─ High lateness (> 5 minutes)
   │  └─ Quota exhaustion
   ├─ Logs: Detailed diagnostics
   └─ Alerts: Creates error records for debugging

4. cleanupOldGalleryEvents()
   ├─ Runs: Every 24 hours
   ├─ Deletes: Gallery events older than 90 days
   └─ Maintains: Database size and performance
```

---

## No-Reply Push Notification System (Added 2025-12-14)

```
┌──────────────────────────────────────────────────────────────────────┐
│                    NO-REPLY PUSH NOTIFICATION FLOW                   │
└──────────────────────────────────────────────────────────────────────┘

    SMS Sent to Elderly User
            │
            ▼
    ┌───────────────────────────────────────┐
    │ Cloud Scheduler: checkNoReplyAndNotify │
    │ Runs: Every 5 minutes                  │
    │ Window: 30-45 minutes after SMS sent   │
    └───────────────────────────────────────┘
            │
            ├─ Query smsLogs where:
            │   ├─ direction == 'outbound'
            │   ├─ messageType == 'taskReminder'
            │   ├─ sentAt >= 45 min ago
            │   ├─ sentAt <= 30 min ago
            │   └─ noReplyNotifiedAt == null
            │
            ▼
    ┌───────────────────────────────────────┐
    │ For each SMS log:                      │
    │                                        │
    │ 1. Check if reply exists               │
    │    └─ Query messages where:            │
    │       ├─ direction == 'inbound'        │
    │       └─ receivedAt >= SMS sentAt      │
    │                                        │
    │ 2. If no reply found:                  │
    │    └─ Get user's FCM token             │
    │    └─ Send push notification           │
    │    └─ Mark smsLog as notified          │
    └───────────────────────────────────────┘
            │
            ▼
    ┌───────────────────────────────────────┐
    │ sendPushNotification()                 │
    │                                        │
    │ • Fetch fcmToken from user doc         │
    │ • Build FCM message with:              │
    │   ├─ notification.title                │
    │   ├─ notification.body                 │
    │   └─ data: {type, habitId, profileId}  │
    │ • Send via admin.messaging().send()    │
    │ • Handle invalid token cleanup         │
    └───────────────────────────────────────┘
            │
            ▼
    ┌───────────────────────────────────────┐
    │ iOS App Receives Push                  │
    │                                        │
    │ • AppDelegate handles notification     │
    │ • Shows banner even in foreground      │
    │ • On tap: posts didTapNoReplyNotification │
    │ • ContentView navigates to profile     │
    └───────────────────────────────────────┘
```

### Push Notification Payload Structure

```javascript
{
  notification: {
    title: "No reply from Grandma Rose",
    body: "Grandma Rose hasn't responded to \"Take Medication\" yet. You may want to check in."
  },
  data: {
    type: "noReply",
    habitId: "uuid-habit-123",
    profileId: "+15551234567",
    smsLogId: "smsLog-doc-id",
    userId: "firebase-auth-uid",
    timestamp: "2025-12-14T09:35:00Z"
  },
  token: "user-fcm-token",
  apns: {
    payload: {
      aps: {
        alert: { title, body },
        sound: "default",
        badge: 1,
        "mutable-content": 1
      }
    }
  }
}
```

### Duplicate Prevention

1. **noReplyNotifiedAt field**: Set on smsLog after notification sent
2. **Time window (30-45 min)**: Prevents re-processing old SMS
3. **replyReceived flag**: Marks SMS as having received a reply
4. **noReplyNotificationSkipped**: Tracks skipped notifications (no FCM token)

### Configuration Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| NO_REPLY_TIMEOUT_MINUTES | 30 | Minimum wait before notifying |
| MAX_WINDOW_MINUTES | 45 | Maximum age of SMS to process |
| Schedule | Every 5 min | How often checker runs |

---

## Key Timestamps & Their Usage

```
┌────────────────────────────────────────────────────────────────────┐
│ CRITICAL TIMESTAMP FIELDS                                          │
└────────────────────────────────────────────────────────────────────┘

nextScheduledDate (Timestamp) ⭐ PRIMARY TRIGGER
├─ Purpose: When should SMS be sent?
├─ Updated: After each SMS sent
├─ Queried: Every minute by sendScheduledTaskReminders()
├─ Calculation: Based on frequency + scheduledTime
├─ Example Timeline:
│  ├─ Day 1: 9:00 AM (daily medication)
│  ├─ [SMS sent at 9:00:45] ✓
│  └─ [nextScheduledDate updated to Day 2: 9:00 AM]
│
└─ Used in: Scheduler query, duplicate prevention, recovery

lastSMSSentAt (Timestamp) ⭐ DUPLICATE PREVENTION
├─ Purpose: When was last SMS sent for this task?
├─ Updated: After SMS successfully sent
├─ Matched against: nextScheduledDate (must not match)
├─ Used by: Webhook to find recent task (30-min window)
├─ Example:
│  ├─ Task created with SMS reminder needed
│  ├─ [Scheduler sends SMS]
│  ├─ lastSMSSentAt set to timestamp of send
│  └─ If second run tries to send: SKIP (lastSMSSentAt matches)
│
└─ Used in: SMS matching, duplicate prevention, response handling

scheduledTime (Date/Time) - RECURRENCE TEMPLATE
├─ Purpose: Time portion for recurring tasks
├─ Set: When task is created (9:00 AM)
├─ Usage: Combined with frequency to calculate nextScheduledDate
├─ Example:
│  ├─ scheduledTime: 9:00 AM
│  ├─ frequency: "daily"
│  └─ → nextScheduledDate: (today at 9:00 AM) or (tomorrow at 9:00 AM)
│
└─ Does NOT change: Only nextScheduledDate changes

receivedAt (Timestamp) - MESSAGE ARRIVAL
├─ Purpose: When was SMS message received?
├─ Set: By Twilio webhook
├─ Usage: Gallery sorting, message history
└─ Example: "Message received at 9:05 AM"

createdAt (Timestamp) - TASK CREATION
├─ Purpose: When was task created?
├─ Set: When user creates task
└─ Usage: Task history, audit trail

lastCompletedAt (Timestamp) - COMPLETION TRACKING
├─ Purpose: When was task last marked complete?
├─ Set: When elderly user responds YES or sends photo
└─ Usage: Completion statistics, last interaction time

smsQuotaPeriodEnd (Timestamp) - QUOTA RESET
├─ Purpose: When does SMS quota reset for user?
├─ Set: At signup + 30 days
├─ Reset: Automatically by sendSMS() function
└─ Usage: Enforce SMS quota limits (prevent abuse)
```

