# Halloo Notification System Analysis

## Executive Summary

The Halloo iOS app implements a **dual-layer notification system**:

1. **Local iOS Notifications** (UNUserNotificationCenter) - For in-app family reminders
2. **SMS Push Notifications** (Twilio) - For task reminders to elderly users

**Important:** The notification system is **NOT push notifications to iOS devices** but rather **SMS reminders to elderly users' phones** and **local notifications to family members** about task status and responses.

---

## System Architecture

### Layer 1: Local Notifications (iOS In-App)

**Purpose:** Alert family members about task completions and elderly user responses

**Status:** DISABLED IN MVP (commented out in code)

**Implementation:**
- Protocol: `NotificationServiceProtocol`
- Implementation: `NotificationService` 
- Framework: `UserNotifications` (UNUserNotificationCenter)
- Scheduling: Local device only, no push notifications

### Layer 2: SMS Reminders (via Twilio)

**Purpose:** Send care task reminders to elderly users via SMS

**Status:** ACTIVE AND CRITICAL

**Implementation:**
- Cloud Functions: `sendScheduledTaskReminders` (runs every 1 minute)
- Cloud Functions: `sendSMS` (callable function)
- Service: `TwilioSMSService`
- Scheduler: Cloud Scheduler

### Layer 3: Real-Time Data Broadcasting

**Purpose:** Synchronize task responses across family member devices

**Status:** ACTIVE

**Implementation:**
- DataSyncCoordinator: Publishes SMS responses via Combine subjects
- Firestore Listeners: Real-time message collection observing

---

## Complete File List

### iOS App Files

#### Notification Service Files (Local Notifications)
1. `/Users/nich/Desktop/Halloo/Halloo/Services/NotificationService.swift`
   - Local notification scheduling using UNUserNotificationCenter
   - 48 lines
   - Handles: permission requests, scheduling, cancellation

2. `/Users/nich/Desktop/Halloo/Halloo/Services/NotificationServiceProtocol.swift`
   - Interface for notification service
   - 28 lines
   - Methods: requestPermissions(), scheduleNotification(), cancelNotification(), getPendingNotificationIds()

#### Core Integration Files
3. `/Users/nich/Desktop/Halloo/Halloo/Core/App.swift`
   - AppDelegate and HalloApp lifecycle
   - Lines 91-219: Notification configuration
   - Calls `requestNotificationPermissions()` during app init
   - Sets up SMS listener in `setupSMSListener()`

4. `/Users/nich/Desktop/Halloo/Halloo/Views/ContentView.swift`
   - Line 535-563: `debugAndClearNotifications()` function
   - Clears all pending and delivered notifications on app launch
   - Logs notification inspection for debugging

5. `/Users/nich/Desktop/Halloo/Halloo/Models/Container.swift`
   - Line 58-61: NotificationService registration
   - Dependency injection setup

#### ViewModel Files (Using Notifications)
6. `/Users/nich/Desktop/Halloo/Halloo/ViewModels/TaskViewModel.swift`
   - Lines 262: notificationService dependency injection
   - Lines 880-915: Notification scheduling methods (DISABLED)
   - `scheduleTaskNotifications()`: Creates 30 future notification occurrences
   - `cancelTaskNotifications()`: Selective cancellation by ID
   - **Status:** All local notification code is commented out

7. `/Users/nich/Desktop/Halloo/Halloo/Core/DataSyncCoordinator.swift`
   - Lines 108-199: Publisher subjects for data broadcasting
   - `smsResponsesSubject`: Broadcasts elderly user SMS responses
   - `profileUpdatesSubject`: Broadcasts elderly profile changes
   - `taskUpdatesSubject`: Broadcasts task updates
   - Real-time synchronization across family devices

---

### Cloud Functions / Backend Files

8. `/Users/nich/Desktop/Halloo/functions/index.js` (1690 lines)

#### Key Exports:
   - **`sendSMS`** (lines 35-181): Callable function to send SMS via Twilio
     - Validates phone numbers (E.164 format)
     - Checks SMS quota before sending
     - Logs to Firestore `smsLogs` collection
     - Saves outbound message to `messages` collection
     
   - **`twilioWebhook`** (lines 193-500+): Receives incoming SMS replies
     - Stores incoming messages to Firestore
     - Matches replies to recent tasks (30-minute window)
     - Validates response format (photo/text requirements)
     - Creates gallery events from task completions
     
   - **`sendScheduledTaskReminders`** (lines 814-1080): CRITICAL SCHEDULER
     - Runs every 1 minute via Cloud Scheduler
     - Finds all active habits with `nextScheduledDate` in last 5 minutes
     - Calls Twilio to send SMS reminders
     - Updates `lastSMSSentAt` timestamp after successful send
     - Advances `nextScheduledDate` to next occurrence
     
   - **`recoverMissedHabits`** (lines 1102-1210): Hourly recovery
     - Finds habits stuck in the past (>5 minutes)
     - Advances them to next future occurrence
     
   - **`healthCheckMonitor`** (lines 1222-1330+): Monitoring
     - Runs every 15 minutes
     - Detects stuck habits and update failures
     - Creates error records in Firestore

---

## Data Storage & Structures

### Firestore Collections

```
users/{userId}/
├── messages/           # Twilio webhook incoming SMS
│   ├── messageBody
│   ├── fromPhone
│   ├── toPhone
│   ├── twilioSid
│   ├── direction: "inbound"/"outbound"
│   └── receivedAt
├── smsLogs/           # SMS delivery audit trail
│   ├── to
│   ├── message
│   ├── profileId
│   ├── messageType
│   ├── twilioSid
│   └── sentAt
└── profiles/{profileId}/
    ├── habits/        # Tasks/reminders
    │   ├── title
    │   ├── status: "active"/"paused"/"archived"
    │   ├── nextScheduledDate  # KEY FIELD
    │   ├── lastSMSSentAt      # KEY FIELD
    │   ├── scheduledTime
    │   ├── frequency
    │   ├── requiresPhoto
    │   ├── requiresText
    │   └── [other task fields]
    └── messages/      # SMS messages (stored twice!)
        └── [same structure as users/{userId}/messages/]
```

### Key Data Fields

1. **`nextScheduledDate`** (Timestamp)
   - The next time this task will trigger an SMS
   - Updated after SMS is sent successfully
   - Used by scheduler to find tasks ready to send

2. **`lastSMSSentAt`** (Timestamp)
   - When the most recent SMS was sent
   - Used by webhook to match responses to tasks (30-minute window)
   - Prevents duplicate SMS sends

3. **`scheduledTime`** (Date/Time)
   - The time portion of when task should occur
   - Combined with frequency to calculate `nextScheduledDate`

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         NOTIFICATION CREATION                       │
└─────────────────────────────────────────────────────────────────────┘

Family Member (iOS App)
        │
        ├─ Opens Habits tab
        │
        ├─ Creates task via HabitCreationCard
        │
        └─> TaskViewModel.createTask()
                │
                ├─ Validates form (profile confirmed, title, schedule)
                │
                ├─> DatabaseService.createTask()
                │        │
                │        └─> Firebase Firestore
                │                │
                │                └─ users/{userId}/profiles/{profileId}/habits/{habitId}
                │                        ├─ title, description, category
                │                        ├─ frequency, scheduledTime
                │                        ├─ nextScheduledDate = calculated first occurrence
                │                        └─ status = "active"
                │
                ├─ [DISABLED] scheduleTaskNotifications() ← local notifications disabled
                │
                └─ showingCreateTask = false

┌─────────────────────────────────────────────────────────────────────┐
│                    SCHEDULER: SMS REMINDER SENDING                  │
└─────────────────────────────────────────────────────────────────────┘

Cloud Scheduler (every 1 minute)
        │
        └─> sendScheduledTaskReminders()
                │
                ├─ Query: habits where nextScheduledDate in [now-5min, now]
                │
                ├─ For each matching habit:
                │     │
                │     ├─ Generate SMS text based on category
                │     │     "Hi! Time to take your morning medication"
                │     │
                │     ├─> TwilioSMSService.sendSMS()
                │     │     │
                │     │     ├─> Twilio API (via Cloud Function)
                │     │     │
                │     │     ├─ Send SMS to profile.phoneNumber
                │     │     │
                │     │     └─ Store in messages collection (direction: "outbound")
                │     │
                │     ├─ Store SMS in smsLogs collection (audit trail)
                │     │
                │     ├─ Update habit.lastSMSSentAt = now
                │     │
                │     └─ Calculate next occurrence & update nextScheduledDate
                │           (e.g., if daily, add 1 day)
                │
                └─ Log summary (count sent, failures)

┌─────────────────────────────────────────────────────────────────────┐
│                  SMS RESPONSE: ELDERLY USER REPLIES                 │
└─────────────────────────────────────────────────────────────────────┘

Elderly User (Feature Phone, SMS)
        │
        ├─ Receives SMS: "Hi! Time to take your morning medication"
        │
        ├─ Types reply: "YES" or "DONE" or sends photo
        │
        └─ Sends SMS reply to Twilio number

Twilio Gateway
        │
        └─> Cloud Function: twilioWebhook()
                │
                ├─ Validate request is from Twilio
                │
                ├─ Extract: fromPhone, messageBody, numMedia
                │
                ├─ Find profile by phoneNumber
                │
                ├─ Store message to:
                │     ├─ users/{userId}/profiles/{profileId}/messages/
                │     └─ users/{userId}/messages/
                │
                ├─ Match reply to recent habit (30-min window)
                │     └─ Search habits where lastSMSSentAt > 30min ago
                │
                ├─ Validate response format
                │     └─ Check if photo/text requirements met
                │
                ├─ Create SMSResponse record
                │
                ├─ Create GalleryHistoryEvent
                │
                └─ Broadcast via DataSyncCoordinator.smsResponsesSubject

┌─────────────────────────────────────────────────────────────────────┐
│              REAL-TIME SYNC: BROADCAST TO FAMILY                    │
└─────────────────────────────────────────────────────────────────────┘

Firestore Change Event
        │
        ├─ New message in profiles/{profileId}/messages/
        │
        └─> DatabaseService.observeIncomingSMSMessages()
                │
                ├─ Emits SMSResponse via Combine stream
                │
                └─> App.setupSMSListener()
                        │
                        └─> DataSyncCoordinator.broadcastSMSResponse()
                                │
                                ├─ smsResponsesSubject.send(response)
                                │
                                ├─ ProfileViewModel updates gallery
                                │
                                ├─ DashboardViewModel updates task status
                                │
                                └─ [DISABLED] Sends local notification to family
                                      └─ Would alert family to check gallery

All Family Members (iOS App)
        │
        ├─ Subscribe to dataSyncCoordinator.smsResponses
        │
        ├─ Receive broadcast immediately
        │
        ├─ Update UI (gallery shows new message, task marked complete)
        │
        └─ [DISABLED] Show local notification banner

```

---

## Local Notification Implementation Details

### NotificationService.swift

```swift
class NotificationService: NotificationServiceProtocol {
    
    func requestPermissions() async -> Bool
    // Requests .alert, .sound, .badge permissions
    // Returns true if user grants permission
    
    func scheduleNotification(id, title, body, scheduledTime) async throws
    // Uses UNCalendarNotificationTrigger to schedule at specific time
    // Creates UNNotificationRequest with identifier
    // Stores in UNUserNotificationCenter
    
    func cancelNotification(withId: String) async
    // Removes pending notification by ID
    
    func cancelAllNotifications() async
    // Clears all pending and delivered notifications
    
    func getPendingNotificationIds() async -> [String]
    // Queries UNUserNotificationCenter.pendingNotificationRequests()
    // Returns array of identifier strings
}
```

### Current Status (As of Nov 2025)

**Lines in TaskViewModel:**
- 881-896: `scheduleTaskNotifications()` - COMMENTED OUT
- 904-915: `cancelTaskNotifications()` - COMMENTED OUT
- 660-661: Comment "Local notifications disabled - SMS handled by Cloud Function"

**All notification scheduling in viewModel is bypassed** - SMS is the only actual notification mechanism in production.

---

## SMS Reminder Scheduling (Active)

### Cloud Function: `sendScheduledTaskReminders`

**Trigger:** Cloud Scheduler - Every 1 minute
**Status:** CRITICAL AND ACTIVE

**Algorithm:**
1. Query all active habits with `nextScheduledDate` in range [now-5min, now]
2. For each habit:
   - Verify SMS wasn't already sent (check `lastSMSSentAt` vs `nextScheduledDate`)
   - Generate SMS text from habit properties
   - Send via Twilio API
   - Log to Firestore
   - Update `lastSMSSentAt`
   - Calculate next occurrence
   - Update `nextScheduledDate`
3. Log summary with counts and errors

**5-Minute Catchup Window:**
- If scheduler is delayed (Cloud Scheduler outage), will catch up to 5 minutes late
- Prevents tasks from being skipped

---

## Duplicate Prevention Mechanisms

### 1. `nextScheduledDate` + `lastSMSSentAt` Check
```javascript
// In sendScheduledTaskReminders
const scheduledTimeDate = habit.nextScheduledDate.toDate();
const lastSent = habit.lastSMSSentAt ? habit.lastSMSSentAt.toDate() : null;

// Only send if:
// - nextScheduledDate is in time window AND
// - lastSMSSentAt doesn't match nextScheduledDate (not already sent)
if (lastSent && lastSent.getTime() === scheduledTimeDate.getTime()) {
    console.log('SMS already sent - skipping');
    return;
}
```

### 2. 30-Minute Response Matching Window
```javascript
// In twilioWebhook - find habit that was recently reminded
const thirtyMinutesAgo = new Date(now - 30 * 60 * 1000);
const recentHabits = habits.filter(h => {
    const sentTime = h.lastSMSSentAt.toDate();
    return sentTime >= thirtyMinutesAgo && sentTime <= now;
});
```

### 3. Missed Habit Recovery
**Cloud Function:** `recoverMissedHabits` (every 60 minutes)
- Finds habits where `nextScheduledDate < now - 5 minutes`
- Checks if SMS was actually sent
- If SMS was sent but date wasn't updated: marks as stuck
- Advances to next future occurrence

---

## Important Findings & Issues

### 1. LOCAL NOTIFICATIONS ARE DISABLED

All local notification scheduling in TaskViewModel is commented out. This was intentional:

```swift
// Line 660-661 in TaskViewModel.swift
// Local notifications disabled - SMS handled by Cloud Function
// try await scheduleTaskNotifications(for: task)
```

**Reason:** SMS is the primary notification method; local notifications would be redundant for elderly users.

### 2. DOUBLE STORAGE OF SMS MESSAGES

SMS messages are stored in TWO locations:
- `users/{userId}/messages/` - User-level audit trail
- `users/{userId}/profiles/{profileId}/messages/` - Profile-level for gallery

This is intentional for query optimization (profile-level for gallery UI).

### 3. SMS IS NOT PUSH NOTIFICATIONS

The "notification system" is:
- ✅ SMS reminders to elderly users (Twilio)
- ✅ Real-time sync to family devices (Firestore listeners + Combine)
- ❌ NOT iOS push notifications (APNs)
- ❌ NOT Firebase Cloud Messaging

### 4. NO APNs / FCM INTEGRATION

No code for Apple Push Notifications or Firebase Cloud Messaging. The app uses:
- Firestore real-time listeners for family coordination
- Combine subjects for in-app broadcasting
- SMS via Twilio for elderly users

### 5. SCHEDULER LATENESS TOLERANCE

The 5-minute catchup window in `sendScheduledTaskReminders` means:
- Habits scheduled 5 minutes ago will still be sent
- Protects against Cloud Scheduler delays
- Could cause SMS to be sent up to 5 minutes late

---

## Data Source Analysis

### Notification Creation
- **Source:** TaskViewModel (iOS app)
- **Method:** Firebase Firestore write via DatabaseService
- **Storage:** `users/{userId}/profiles/{profileId}/habits/`
- **Key Fields:** `nextScheduledDate`, `frequency`, `scheduledTime`

### Notification Triggering
- **Source:** Cloud Scheduler (runs every 1 minute)
- **Mechanism:** Compares `nextScheduledDate` to current time
- **Action:** Sends SMS via Twilio if time matches
- **Confirmation:** Updates `lastSMSSentAt` timestamp

### Notification Storage
- **SMS Log:** `users/{userId}/smsLogs/` - Audit trail
- **Message History:** `users/{userId}/profiles/{profileId}/messages/` - Gallery display
- **Task Record:** `users/{userId}/profiles/{profileId}/habits/` - Task document itself

### Notification Response
- **Trigger:** Elderly user sends SMS reply
- **Webhook:** Twilio → Cloud Function `twilioWebhook`
- **Storage:** Creates SMSResponse document and GalleryHistoryEvent
- **Broadcast:** DataSyncCoordinator publishes via smsResponsesSubject

---

## Duplication Risks & Mitigations

### Risk 1: Duplicate SMS Sends
**Scenario:** Cloud Scheduler runs twice for same minute

**Mitigation:**
```javascript
if (lastSMSSentAt === nextScheduledDate) {
    // Already sent, skip
    return;
}
```

**Status:** ✅ Protected

### Risk 2: Orphaned Task Records
**Scenario:** Task deleted but `nextScheduledDate` still in future

**Mitigation:**
- `recoverMissedHabits` function finds stuck tasks
- Manual recovery in `healthCheckMonitor`

**Status:** ⚠️ Reactive (finds issues hourly)

### Risk 3: Gallery Event Duplicates
**Scenario:** Same SMS response processed twice

**Mitigation:**
- Uses `twilioSid` (Twilio's unique ID) as document identifier
- Each SMS response creates one gallery event
- Firestore prevents duplicate writes with same ID

**Status:** ✅ Protected (Firestore-level)

---

## Summary Table

| Aspect | Status | Implementation | Details |
|--------|--------|----------------|---------|
| **Local Notifications** | ❌ DISABLED | UNUserNotificationCenter | Code exists but commented out in TaskViewModel |
| **SMS Reminders** | ✅ ACTIVE | Twilio + Cloud Functions | Runs every 1 minute, critical path |
| **Real-Time Sync** | ✅ ACTIVE | Firestore listeners + Combine | Family member devices sync instantly |
| **Push Notifications** | ❌ NOT USED | APNs / FCM | No implementation, not part of system |
| **Local Storage** | ✅ YES | Firestore | habits, messages, smsLogs collections |
| **Duplicate Prevention** | ✅ PROTECTED | Multiple checks | lastSMSSentAt vs nextScheduledDate |
| **SMS Quota** | ✅ ENFORCED | Cloud Function | Tracks usage per user |
| **Response Matching** | ✅ WORKING | 30-minute window | Matches replies to recent tasks |

---

## Key Files Summary

| File | Lines | Purpose | Status |
|------|-------|---------|--------|
| NotificationService.swift | 48 | Local notification scheduling | Disabled |
| NotificationServiceProtocol.swift | 28 | Service interface | In use |
| App.swift | ~600 | App lifecycle & SMS setup | Active |
| TaskViewModel.swift | ~1300 | Task creation & notification scheduling | Create works, notify disabled |
| DataSyncCoordinator.swift | ~600 | Real-time broadcasting | Active |
| functions/index.js | 1690 | Cloud Functions (SMS, scheduler, webhooks) | Critical |

---

## Conclusion

The Halloo notification system is **NOT a push notification system** in the traditional sense. It's a **task reminder system** that:

1. **Creates reminders** via iOS app → Firestore
2. **Schedules delivery** via Cloud Functions → Twilio SMS
3. **Sends to elderly users** via Twilio
4. **Receives responses** via Twilio Webhook → Firestore
5. **Broadcasts to family** via Firestore listeners → Real-time UI updates

**Local iOS notifications were intentionally disabled** because SMS is the primary notification mechanism. The real-time Firestore listeners keep family members updated on task responses across all their devices.

