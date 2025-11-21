# Timezone Implementation for North America

**Status:** Ready to implement
**Estimated Time:** 5-6 hours
**Scope:** North America (+1 phone numbers only)

---

## Priority Order

1. ✅ Fix login issues FIRST
2. Then implement timezone support below

---

## STEP 1: Critical Fix - Prevent Crashes (5 minutes)

**Problem:** App crashes if old profiles are missing `timeZone` field

**File:** `Halloo/Models/ElderlyProfile.swift` (line 102)

**Change:**
```swift
// BEFORE (line 102)
timeZone = try container.decode(String.self, forKey: .timeZone)

// AFTER
timeZone = (try? container.decode(String.self, forKey: .timeZone))
    ?? TimeZone.current.identifier
```

**Why:** Prevents crashes with old Firebase data

---

## STEP 2: Add Timezone to Task Model (30 minutes)

**File:** `Halloo/Models/Task.swift`

### 2.1 Add field (after line 25):
```swift
var lastSMSSentAt: Date?  // Track when SMS reminder was last sent
let timeZone: String       // ADD THIS - Profile's timezone for scheduling
```

### 2.2 Update CodingKeys enum:
```swift
enum CodingKeys: String, CodingKey {
    // ... existing keys
    case timeZone  // ADD THIS
}
```

### 2.3 Update decoder (in `init(from decoder:)` around line 50):
```swift
lastSMSSentAt = try container.decodeIfPresent(Date.self, forKey: .lastSMSSentAt)

// ADD THIS - Backward compatibility for old tasks without timezone
timeZone = (try? container.decode(String.self, forKey: .timeZone))
    ?? TimeZone.current.identifier
```

### 2.4 Update initializer (around line 77):
```swift
init(
    // ... existing parameters
    lastSMSSentAt: Date? = nil,
    timeZone: String = TimeZone.current.identifier  // ADD THIS
) {
    // ... existing assignments
    self.lastSMSSentAt = lastSMSSentAt
    self.timeZone = timeZone  // ADD THIS
}
```

---

## STEP 3: Update iOS Date Calculations (1 hour)

**File:** `Halloo/ViewModels/TaskViewModel.swift`

### 3.1 Update `calculateFirstOccurrence` signature (line 1171):
```swift
private func calculateFirstOccurrence(
    frequency: TaskFrequency,
    scheduledTime: Date,
    customDays: Set<Weekday>,
    profileTimeZone: String  // ADD THIS PARAMETER
) -> Date? {
    let now = Date()
    var calendar = Calendar(identifier: .gregorian)

    // USE PROFILE'S TIMEZONE INSTEAD OF DEVICE TIMEZONE
    calendar.timeZone = TimeZone(identifier: profileTimeZone) ?? .current

    // ... rest of existing logic stays the same
}
```

### 3.2 Update call to `calculateFirstOccurrence` (around line 621):
```swift
guard let firstOccurrence = calculateFirstOccurrence(
    frequency: frequency,
    scheduledTime: scheduledTime,
    customDays: customDays,
    profileTimeZone: selectedProfile.timeZone  // ADD THIS
) else {
    // ... existing error handling
}
```

### 3.3 Update Task creation (around line 640):
```swift
let task = Task(
    // ... existing parameters
    nextScheduledDate: firstOccurrence,
    lastSMSSentAt: nil,
    timeZone: selectedProfile.timeZone  // ADD THIS
)
```

---

## STEP 4: Cloud Functions - Install moment-timezone (5 minutes)

**File:** `functions/package.json`

### 4.1 Add dependency:
```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0",
    "twilio": "^4.19.0",
    "moment-timezone": "^0.5.43"  // ADD THIS
  }
}
```

### 4.2 Install:
```bash
cd functions
npm install
```

---

## STEP 5: Update Cloud Functions Timezone Logic (2 hours)

**File:** `functions/index.js`

### 5.1 Add import (top of file):
```javascript
const admin = require('firebase-admin');
const functions = require('firebase-functions');
const twilio = require('twilio');
const moment = require('moment-timezone');  // ADD THIS
```

### 5.2 Replace `calculateNextOccurrence` function (line 1371):

**REPLACE ENTIRE FUNCTION WITH:**
```javascript
/**
 * Calculate the next occurrence for a habit based on its frequency
 * @param {Object} habit - Habit document data
 * @param {string} profileTimeZone - Profile's timezone (e.g., "America/Los_Angeles")
 * @returns {Date} Next occurrence timestamp
 */
function calculateNextOccurrence(habit, profileTimeZone) {
  // Get current date in profile's timezone
  const currentDate = moment(habit.nextScheduledDate.toDate()).tz(profileTimeZone);
  const scheduledTime = moment(habit.scheduledTime.toDate()).tz(profileTimeZone);

  // Extract time components
  const hours = scheduledTime.hours();
  const minutes = scheduledTime.minutes();
  const seconds = scheduledTime.seconds();

  switch (habit.frequency) {
    case 'daily':
      // Add 1 day to current nextScheduledDate
      const nextDaily = currentDate.clone().add(1, 'day');
      nextDaily.hours(hours).minutes(minutes).seconds(seconds).milliseconds(0);
      return nextDaily.toDate();

    case 'weekdays':
      // Find next weekday (Monday-Friday)
      let nextWeekday = currentDate.clone().add(1, 'day');
      nextWeekday.hours(hours).minutes(minutes).seconds(seconds).milliseconds(0);

      // Skip weekends
      while (nextWeekday.day() === 0 || nextWeekday.day() === 6) {
        nextWeekday.add(1, 'day');
      }
      return nextWeekday.toDate();

    case 'weekly':
      // Add 7 days
      const nextWeekly = currentDate.clone().add(7, 'days');
      nextWeekly.hours(hours).minutes(minutes).seconds(seconds).milliseconds(0);
      return nextWeekly.toDate();

    case 'custom':
      // Find next day that matches customDays
      let nextCustom = currentDate.clone().add(1, 'day');
      nextCustom.hours(hours).minutes(minutes).seconds(seconds).milliseconds(0);

      // Convert customDays array to moment day numbers (0=Sunday, 6=Saturday)
      const customDaysSet = new Set(habit.customDays.map(day => {
        const dayMap = {
          'sunday': 0, 'monday': 1, 'tuesday': 2, 'wednesday': 3,
          'thursday': 4, 'friday': 5, 'saturday': 6
        };
        return dayMap[day.toLowerCase()];
      }));

      // Search for next matching day (max 7 days)
      for (let i = 0; i < 7; i++) {
        if (customDaysSet.has(nextCustom.day())) {
          return nextCustom.toDate();
        }
        nextCustom.add(1, 'day');
      }

      // Fallback (should never reach here)
      return nextCustom.toDate();

    case 'once':
      // One-time habits don't repeat - return far future date
      return moment().add(100, 'years').toDate();

    default:
      console.error(`Unknown frequency: ${habit.frequency}`);
      return currentDate.clone().add(1, 'day').toDate();
  }
}
```

### 5.3 Update calls to `calculateNextOccurrence`:

**Location 1: In `sendScheduledReminders` (around line 750):**
```javascript
// BEFORE
const nextOccurrence = calculateNextOccurrence(habit);

// AFTER - Get profile and pass timezone
const profileDoc = await habitDoc.ref.parent.parent.get();
const profile = profileDoc.data();
const nextOccurrence = calculateNextOccurrence(
  habit,
  profile.timeZone || 'America/Los_Angeles'
);
```

**Location 2: In `processSMSResponse` (around line 380):**
```javascript
// BEFORE
const nextOccurrence = calculateNextOccurrence(habit);

// AFTER
const nextOccurrence = calculateNextOccurrence(
  habit,
  profile.timeZone || 'America/Los_Angeles'
);
```

**Note:** Search for ALL occurrences of `calculateNextOccurrence(habit)` and add timezone parameter

### 5.4 Update scheduled function timezone (line 602):
```javascript
// BEFORE
exports.sendScheduledReminders = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'America/Los_Angeles'  // Hardcoded PST
}, async (event) => {

// AFTER
exports.sendScheduledReminders = onSchedule({
  schedule: 'every 5 minutes',
  timeZone: 'America/New_York'  // Eastern Time (covers most NA timezones)
}, async (event) => {
```

**Why Eastern?** Function schedule needs ONE timezone. Logic now handles each profile's individual timezone.

---

## STEP 6: UI Updates to Show Timezone (30 minutes)

### Option A: Habit Creation Form

**File:** `Halloo/Views/TaskViews.swift`

Add below time picker:
```swift
// After the time picker
DatePicker("Scheduled Time", selection: $viewModel.scheduledTime, displayedComponents: .hourAndMinute)

// ADD THIS
if let profile = viewModel.selectedProfile {
    HStack {
        Text("Reminder will be sent at scheduled time in")
            .font(.caption)
            .foregroundColor(.gray)
        Text(profile.displayTimeZone.abbreviation() ?? profile.timeZone)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.blue)
    }
    .padding(.horizontal)
}
```

### Option B: Habits List

**File:** `Halloo/Views/HabitsView.swift`

Add timezone to habit row:
```swift
// Find where scheduled time is displayed
Text(DateFormatters.formatTime(task.scheduledTime))
    .font(.system(size: 17, weight: .semibold))

// ADD timezone abbreviation
if let tz = TimeZone(identifier: profile.timeZone) {
    Text(tz.abbreviation() ?? "")
        .font(.system(size: 12))
        .foregroundColor(.gray)
}
```

---

## STEP 7: Testing (1 hour)

### Test Scenarios:

#### 1. Same Timezone
- User: PST
- Recipient: PST
- Habit: 9:00 AM daily
- ✅ Expected: SMS at 9:00 AM PST

#### 2. Cross-Timezone (West to East)
- User: PST
- Recipient: EST (profile.timeZone = "America/New_York")
- Habit: 9:00 AM daily
- ✅ Expected: SMS at 9:00 AM EST (6:00 AM PST)

#### 3. Cross-Timezone (East to West)
- User: EST
- Recipient: PST (profile.timeZone = "America/Los_Angeles")
- Habit: 9:00 AM daily
- ✅ Expected: SMS at 9:00 AM PST (12:00 PM EST)

#### 4. Central Timezone
- User: EST
- Recipient: CST (profile.timeZone = "America/Chicago")
- Habit: 9:00 AM daily
- ✅ Expected: SMS at 9:00 AM CST

#### 5. DST Transition
- Recipient: EST
- Habit: 9:00 AM daily
- DST: Spring forward (2 AM → 3 AM)
- ✅ Expected: SMS still at 9:00 AM EDT

### How to Test:

```bash
# 1. Create test profiles with different timezones in Firebase Console
# 2. Create habits scheduled for near future
# 3. Monitor Cloud Function logs:
firebase functions:log --only sendScheduledReminders

# 4. Check console logs in iOS app for date calculations
# 5. Verify SMS delivery times match recipient timezone
```

---

## North America Timezones Reference

All supported (use +1 phone numbers ✅):

```
'America/New_York'          // EST/EDT - New York, Toronto
'America/Chicago'           // CST/CDT - Chicago, Mexico City
'America/Denver'            // MST/MDT - Denver, Calgary
'America/Los_Angeles'       // PST/PDT - LA, Vancouver
'America/Phoenix'           // MST (no DST) - Arizona
'America/Anchorage'         // AKST/AKDT - Alaska
'Pacific/Honolulu'          // HST (no DST) - Hawaii
'America/Halifax'           // AST/ADT - Nova Scotia
'America/St_Johns'          // NST/NDT - Newfoundland
```

---

## Deployment

### 1. Deploy Cloud Functions:
```bash
cd functions
npm install
firebase deploy --only functions
```

### 2. Deploy iOS App:
- Build in Xcode
- Test on device
- Submit to TestFlight

### 3. Monitor:
```bash
# Watch for errors
firebase functions:log

# Check Firestore for timezone fields
# Verify old data still works (backward compatibility)
```

---

## Migration Notes

**Good News:** All changes are backward compatible! ✅

- Old profiles without timezone → Use device timezone (fallback)
- Old tasks without timezone → Use device timezone (fallback)
- New habits → Automatically use profile's timezone
- Cloud Functions → Check for timezone field, fallback to PST if missing

**No data migration script needed!**

---

## Summary Checklist

- [ ] **FIRST:** Fix login issues
- [ ] Step 1: Fix ElderlyProfile decoder crash (5 min)
- [ ] Step 2: Add timezone to Task model (30 min)
- [ ] Step 3: Update iOS date calculations (1 hour)
- [ ] Step 4: Install moment-timezone (5 min)
- [ ] Step 5: Update Cloud Functions logic (2 hours)
- [ ] Step 6: Update UI to show timezone (30 min)
- [ ] Step 7: Test with different NA timezones (1 hour)
- [ ] Deploy to production

**Total Time:** 5-6 hours

---

## Questions?

- Timezone display in UI preferences?
- Need timezone picker for profiles?
- Want to add timezone to profile edit screen?
- Testing strategy for different timezones?

---

**Last Updated:** 2025-11-19
**Status:** Awaiting login fix, then ready to implement
