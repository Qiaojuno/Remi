# Recurring Task Scheduling System

## Professional Standard Implementation

This document explains how recurring tasks (habits) are scheduled and managed in the Halloo app, following professional standards used by Google Calendar, iOS Reminders, and Todoist.

---

## Data Model

### Task Structure
```swift
struct Task {
    let frequency: TaskFrequency        // .once, .daily, .weekdays, .weekly, .custom
    let scheduledTime: Date             // Template time (e.g., "9:35 AM on some day")
    let customDays: [Weekday]           // For .custom frequency: [.monday, .wednesday]
    var nextScheduledDate: Date         // CALCULATED next occurrence timestamp
    let startDate: Date                 // When this task/habit started
}
```

### Key Concepts

**1. Template Data (Never Changes)**
- `frequency`: Pattern of recurrence
- `customDays`: Which days of week (for custom frequency)
- `scheduledTime`: The time component (hours/minutes)
- `startDate`: When the habit was created

**2. Dynamic Data (Updates After Each SMS)**
- `nextScheduledDate`: The actual next occurrence timestamp
- Updated by Cloud Function after sending each SMS

---

## How It Works

### Example: "Every Monday & Wednesday at 9:35 AM"

**Creation (Tuesday Oct 15, 11:00 PM)**

1. User selects:
   - Days: Monday, Wednesday
   - Time: 9:35 AM

2. iOS calculates first occurrence:
   ```swift
   calculateFirstOccurrence(
       frequency: .custom,
       scheduledTime: Date("9:35 AM"),  // from DatePicker
       customDays: [.monday, .wednesday]
   )
   // Returns: "Wednesday Oct 16, 9:35 AM" (next matching day)
   ```

3. Task created with:
   ```swift
   Task(
       frequency: .custom,
       scheduledTime: Date("Oct 15, 9:35 AM"),  // Template
       customDays: [.monday, .wednesday],
       nextScheduledDate: Date("Oct 16, 9:35 AM"),  // Calculated
       startDate: Date("Oct 15")
   )
   ```

**First SMS (Wednesday Oct 16, 9:35 AM)**

1. Cloud Function runs every minute
2. Finds habit where `nextScheduledDate` is within last 2 minutes
3. Generates friendly randomized message:
   ```javascript
   const message = getTaskReminderMessage(habit, profile);
   // Example: "Hello Mom 🌞 A gentle reminder to Take Morning Medication
   //           Snap a quick photo when you finish — it always brightens the day 🌿"
   ```
4. Sends SMS via Twilio
5. Stores message and updates next occurrence:
   ```javascript
   await habitDoc.ref.update({
       nextScheduledDate: "Monday Oct 21, 9:35 AM",  // Next Monday
       lastSentMessage: message  // Store what we sent
   })
   ```

**Second SMS (Monday Oct 21, 9:35 AM)**

1. Cloud Function finds habit again
2. Generates a new randomized message (different from first one)
3. Sends SMS via Twilio
4. Updates `nextScheduledDate` to "Wednesday Oct 23, 9:35 AM" and stores new `lastSentMessage`

**Continues indefinitely...**

---

## Frequency Types & Behavior

### 1. One-Time Tasks (`.once`)
**User selects**: Specific date + time (e.g., "Oct 20, 2:00 PM")

**Behavior**:
- Must be in the future (validation error if past)
- `nextScheduledDate = scheduledTime`
- After SMS sent, habit remains but is NOT updated (future feature: could auto-delete or mark complete)

**Example**:
```
scheduledTime: "Oct 20, 2:00 PM"
nextScheduledDate: "Oct 20, 2:00 PM"
frequency: .once
```

---

### 2. Daily Tasks (`.daily`)
**User selects**: Time only (e.g., "8:00 AM")

**Behavior**:
- If current time < 8:00 AM → starts today
- If current time > 8:00 AM → starts tomorrow
- Repeats every day at 8:00 AM indefinitely

**Example** (created at 7:00 AM):
```
scheduledTime: "8:00 AM"
nextScheduledDate: "Today 8:00 AM"  // Calculated
frequency: .daily
```

**Example** (created at 10:00 PM):
```
scheduledTime: "8:00 AM"
nextScheduledDate: "Tomorrow 8:00 AM"  // Calculated
frequency: .daily
```

---

### 3. Weekdays Only (`.weekdays`)
**User selects**: Time only (e.g., "9:00 AM")

**Behavior**:
- Sends Monday through Friday only
- Skips Saturday and Sunday
- If created on Friday 10:00 PM with 9:00 AM time → starts Monday 9:00 AM

**Example**:
```
scheduledTime: "9:00 AM"
nextScheduledDate: "Next weekday at 9:00 AM"  // Calculated
frequency: .weekdays
```

---

### 4. Weekly Tasks (`.weekly`)
**User selects**: Day of week + time (e.g., "Wednesday 9:35 AM")

**Behavior**:
- Repeats every Wednesday at 9:35 AM
- Uses the weekday from `scheduledTime` as the template

**Example**:
```
scheduledTime: "Wednesday 9:35 AM"
nextScheduledDate: "Next Wednesday 9:35 AM"  // Calculated
frequency: .weekly
```

---

### 5. Custom Days (`.custom`)
**User selects**: Multiple days + time (e.g., "Mon/Wed/Fri 9:35 AM")

**Behavior**:
- Repeats on selected days indefinitely
- Most flexible option

**Example**:
```
scheduledTime: "9:35 AM"
customDays: [.monday, .wednesday, .friday]
nextScheduledDate: "Next Mon/Wed/Fri at 9:35 AM"  // Calculated
frequency: .custom
```

---

## Cloud Function Updates

### After Sending SMS (functions/index.js)

```javascript
// Send SMS
await twilioClient.messages.create({ ... });

// Update nextScheduledDate for recurring habits only
if (habit.frequency !== 'once') {
    const nextOccurrence = calculateNextOccurrence(habit);
    await habitDoc.ref.update({
        nextScheduledDate: admin.firestore.Timestamp.fromDate(nextOccurrence)
    });
}
```

### calculateNextOccurrence() Logic

**Daily**: Add 1 day
```javascript
nextDaily.setDate(nextDaily.getDate() + 1);
```

**Weekly**: Add 7 days
```javascript
nextWeekly.setDate(nextWeekly.getDate() + 7);
```

**Weekdays**: Add days, skip weekends
```javascript
while (nextWeekday.getDay() === 0 || nextWeekday.getDay() === 6) {
    nextWeekday.setDate(nextWeekday.getDate() + 1);
}
```

**Custom**: Search next 14 days for matching weekday
```javascript
for (let i = 1; i <= 14; i++) {
    nextCustom.setDate(currentDate.getDate() + i);
    if (targetDays.includes(nextCustom.getDay())) {
        return nextCustom;
    }
}
```

---

## Edge Cases Handled

### ✅ Creating habit after scheduled time
**Scenario**: Create "Every day at 9:00 AM" at 10:00 PM
**Result**: First occurrence = Tomorrow 9:00 AM

### ✅ Creating habit on non-matching day
**Scenario**: Create "Every Wednesday at 3:00 PM" on Tuesday 11:00 PM
**Result**: First occurrence = Wednesday 3:00 PM (next day)

### ✅ One-time task in the past
**Scenario**: Try to create one-time task for "Yesterday 2:00 PM"
**Result**: Error shown: "Cannot create task with a time in the past"

### ✅ Weekend handling for weekdays
**Scenario**: Create "Weekdays 9:00 AM" on Friday 10:00 PM
**Result**: First occurrence = Monday 9:00 AM (skips weekend)

### ✅ Custom days with no match today
**Scenario**: Create "Mon/Wed/Fri 9:00 AM" on Tuesday 10:00 PM
**Result**: First occurrence = Wednesday 9:00 AM (next matching day)

---

## Code Locations

### iOS (Swift)
- **TaskViewModel.swift** (lines 1143-1255): `calculateFirstOccurrence()` function
- **TaskViewModel.swift** (lines 648-659): Validation for past times
- **TaskViewModel.swift** (line 682): Pass calculated `nextScheduledDate` to Task initializer
- **Task.swift** (line 23): `nextScheduledDate` field
- **TaskFrequency.swift**: Frequency enum definitions

### Cloud Functions (JavaScript)
- **functions/index.js** (lines 646-655): Update `nextScheduledDate` after SMS
- **functions/index.js** (lines 703-784): `calculateNextOccurrence()` function
- **functions/index.js** (lines 513-520): Query for habits due in 2-minute window

---

## Testing Checklist

- [ ] Daily task created before scheduled time → triggers today
- [ ] Daily task created after scheduled time → triggers tomorrow
- [ ] Weekly task → triggers on correct day of week
- [ ] Custom days → triggers on all selected days
- [ ] Weekdays → skips weekends
- [ ] One-time task in past → shows error
- [ ] One-time task in future → sends SMS once
- [ ] After SMS sent → `nextScheduledDate` updated correctly
- [ ] Second occurrence → SMS sent again at correct time

---

## SMS Message Generation (Updated: ffd2878)

### Friendly Randomized Messages

Instead of robotic templates, the system generates warm, caring messages with 120 unique combinations:

**Message Components:**
1. **Greeting** (5 variations): "Hi [Name]!", "Hello [Name] 🌞", etc.
2. **Prompt** (6 variations): "Time to", "A gentle reminder to", etc.
3. **Instructions** (4 types × 5 variations):
   - Photo required: "Snap a quick photo when you finish — it always brightens the day 🌿"
   - Text required: "Just reply when you're finished 💬"
   - Both photo & text: "Send a photo and a quick note when done — I'd love to see and hear from you 📸💬"
   - Flexible: "Let me know when you're done, however you'd like — photo, text, or just a quick hello 💙"

**Example Messages:**
```
Hello Mom 🌞 A gentle reminder to Take Vitamins

Snap a quick photo when you finish — it always brightens the day 🌿
```

```
Hey Mom, Thinking of you — remember to Take Vitamins

Once you're done, share a picture — it'll make me smile 😊
```

**Technical Details:**
- Function: `getTaskReminderMessage(habit, profile)` in functions/index.js (lines 1349-1421)
- Storage: `habit.lastSentMessage` field stores actual SMS sent
- Gallery: `eventData.sentMessage` includes SMS in gallery events
- UI: CardStackView displays actual sent messages in blue bubbles

**Benefits:**
- Warmer, more caring tone (less robotic, more human)
- 120 unique message combinations per habit
- Elderly users feel valued and cared for
- Gallery shows authentic conversation history
- Backward compatible with old events

---

## Future Enhancements

1. **End dates**: Support `endDate` to stop recurring tasks
2. **Completion tracking**: Mark one-time tasks as complete after SMS
3. **Snooze/skip**: Allow user to skip next occurrence
4. **Timezone handling**: Handle user timezone changes
5. **Multiple times per day**: Support multiple scheduled times for same habit
6. **Bi-weekly, monthly**: Add more frequency options
7. **Message personalization**: Learn recipient's preferred message style over time
8. **Time-of-day greetings**: Different greetings for morning/afternoon/evening

---

**Last Updated**: November 4, 2025
**Implementation**: TaskViewModel.swift, functions/index.js
**Recent Changes**: Added friendly randomized message generation system (ffd2878)
