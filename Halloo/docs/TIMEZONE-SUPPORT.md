# Timezone Support - Future Enhancement

**Status:** Deferred (Post-MVP)
**Priority:** Medium
**Estimated Effort:** 8-12 hours
**Created:** 2025-11-02

---

## Executive Summary

The app has timezone infrastructure in place (`ElderlyProfile.timeZone` field), but it's **not currently being used**. All date calculations happen in the user's device timezone (iOS) or Pacific Time (Cloud Functions), which causes incorrect SMS delivery times when users and recipients are in different timezones.

**For MVP:** Acceptable if all users/recipients are in the same timezone or PST.

**For Production:** Must fix before launching in multiple timezones.

---

## Current Behavior

### What Works ✅
- ElderlyProfile has `timeZone: String` field (ElderlyProfile.swift:11)
- Timezone is saved to Firebase when profiles are created (ProfileViewModel.swift:608)
- UI allows users to select timezone (ProfileViewModel.swift:134)

### What's Broken ❌

**Scenario:** User in NYC creates "Take meds at 9 AM" for parent in LA

1. **iOS (Swift):**
   - User selects 9:00 AM in DatePicker
   - Interpreted as 9:00 AM **EST** (user's device timezone)
   - Saved to Firebase as UTC timestamp

2. **Cloud Functions (Node.js):**
   - Reads profile from Firebase (has `timeZone: "America/Los_Angeles"`)
   - **Ignores the timezone field completely**
   - Calculates next occurrence in **PST** (hardcoded)
   - Sends SMS at 6:00 AM PST (which is 9:00 AM EST)

3. **Result:**
   - Parent in LA gets SMS at **6:00 AM** instead of 9:00 AM ❌

---

## Root Causes

### 1. Task Model Missing Timezone
**File:** `Halloo/Models/Task.swift`

```swift
struct Task: Codable, Identifiable, Hashable {
    // ... existing fields
    // ❌ MISSING: let timeZone: String
}
```

**Impact:** Habits don't know which timezone they should execute in.

---

### 2. iOS Uses Device Timezone
**File:** `Halloo/ViewModels/TaskViewModel.swift`

```swift
// Line 1118
let calendar = Calendar.current  // ❌ Uses user's timezone, not recipient's
```

**Impact:** Date calculations happen in wrong timezone.

---

### 3. Cloud Functions Hardcoded to PST
**File:** `functions/index.js`

```javascript
// Line 732, 1019, 1139
timeZone: 'America/Los_Angeles'  // ❌ Hardcoded

// Line 1258-1339 - calculateNextOccurrence()
// Uses JavaScript Date which defaults to server timezone (PST)
```

**Impact:** All SMS sent based on Pacific Time, regardless of recipient location.

---

### 4. ElderlyProfile Decoder Will Crash
**File:** `Halloo/Models/ElderlyProfile.swift`

```swift
// Line 102
timeZone = try container.decode(String.self, forKey: .timeZone)  // ❌ Required field
```

**Impact:** If ANY old profile in Firebase is missing `timeZone` field, app crashes on load.

---

## Fix Checklist

### Critical (Prevents Crashes)
- [ ] **Fix ElderlyProfile decoder** - 5 minutes
  ```swift
  // ElderlyProfile.swift:102
  timeZone = (try? container.decode(String.self, forKey: .timeZone))
      ?? TimeZone.current.identifier
  ```

### High Priority (Core Functionality)
- [ ] **Add timezone to Task model** - 1 hour
  - Add `let timeZone: String` field to Task.swift
  - Update Task initializer to accept timezone parameter
  - Update TaskViewModel.createTask() to pass `profile.timeZone`
  - Add backward compatibility decoder: `timeZone = (try? ...) ?? TimeZone.current.identifier`

- [ ] **Fix iOS date calculations** - 2 hours
  - Update `calculateFirstOccurrence()` to accept `profileTimeZone` parameter
  - Create calendar with recipient's timezone: `calendar.timeZone = TimeZone(identifier: profileTimeZone)`
  - Pass profile timezone through all date calculation methods

- [ ] **Fix Cloud Functions timezone** - 3-4 hours
  - Add `moment-timezone` to `functions/package.json`
  - Update `calculateNextOccurrence(habit, profileTimeZone)` to accept timezone parameter
  - Use `moment.tz()` for all date calculations
  - Read `profile.timeZone` from Firestore and pass to all calculations
  - Test DST transitions

### Medium Priority (User Experience)
- [ ] **Show timezone in UI** - 1 hour
  - Display recipient's timezone in habit creation form
  - Show "9:00 AM EST" instead of "9:00 AM"
  - Add timezone indicator in habit list

- [ ] **Validate timezone consistency** - 30 minutes
  - Warn users if they're in different timezone than recipient
  - Confirm "Parent will receive SMS at 9:00 AM Pacific Time. Continue?"

---

## Code Changes Required

### 1. Task.swift
```swift
struct Task: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let profileId: String
    let title: String
    // ... existing fields
    let timeZone: String  // ADD THIS

    // Update CodingKeys
    enum CodingKeys: String, CodingKey {
        // ... existing keys
        case timeZone  // ADD THIS
    }

    // Update decoder
    init(from decoder: Decoder) throws {
        // ... existing decoding
        timeZone = (try? container.decode(String.self, forKey: .timeZone))
            ?? TimeZone.current.identifier  // Backward compatibility
    }
}
```

### 2. TaskViewModel.swift
```swift
// Update calculateFirstOccurrence
private func calculateFirstOccurrence(
    frequency: TaskFrequency,
    scheduledTime: Date,
    customDays: Set<Weekday>,
    profileTimeZone: String  // ADD THIS
) -> Date? {
    let now = Date()
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: profileTimeZone) ?? .current  // USE PROFILE TZ

    // ... rest of logic
}

// Update createTask to pass timezone
let task = Task(
    // ... existing fields
    timeZone: profile.timeZone,  // ADD THIS
    nextScheduledDate: nextScheduledDate
)
```

### 3. functions/index.js
```javascript
// Add to package.json dependencies
{
  "moment-timezone": "^0.5.43"
}

// Update calculateNextOccurrence
const moment = require('moment-timezone');

function calculateNextOccurrence(habit, profileTimeZone) {
  // Use profile's timezone instead of PST
  const currentDate = moment(habit.nextScheduledDate.toDate()).tz(profileTimeZone);
  const scheduledTime = moment(habit.scheduledTime.toDate()).tz(profileTimeZone);

  const hours = scheduledTime.hours();
  const minutes = scheduledTime.minutes();
  const seconds = scheduledTime.seconds();

  switch (habit.frequency) {
    case 'daily':
      const nextDaily = currentDate.clone().add(1, 'day');
      nextDaily.hours(hours).minutes(minutes).seconds(seconds);
      return nextDaily.toDate();

    case 'weekly':
      const nextWeekly = currentDate.clone().add(7, 'days');
      nextWeekly.hours(hours).minutes(minutes).seconds(seconds);
      return nextWeekly.toDate();

    // ... other frequencies
  }
}

// Update callers to pass timezone
const profile = profileDoc.data();
const nextOccurrence = calculateNextOccurrence(habit, profile.timeZone);
```

### 4. ElderlyProfile.swift (Critical Fix)
```swift
// Line 102 - Make timezone optional with fallback
init(from decoder: Decoder) throws {
    // ... existing decoding

    // Fix timezone to handle missing field
    timeZone = (try? container.decode(String.self, forKey: .timeZone))
        ?? TimeZone.current.identifier

    // ... rest of decoding
}
```

---

## Testing Plan

### Unit Tests
- [ ] Test date calculations in different timezones
- [ ] Test DST transitions (spring forward, fall back)
- [ ] Test edge cases (midnight, date line)
- [ ] Test decoder with missing timezone field

### Integration Tests
- [ ] User in PST creates habit for recipient in PST → SMS at correct time
- [ ] User in EST creates habit for recipient in PST → SMS at correct PST time
- [ ] User in JST creates habit for recipient in EST → SMS at correct EST time
- [ ] User travels to different timezone → existing habits still work
- [ ] Load old profile without timezone field → no crash
- [ ] Habit crosses DST boundary → time adjusts correctly

### Manual Testing Scenarios
```
Scenario 1: Same Timezone
- User: NYC (EST)
- Recipient: NYC (EST)
- Habit: "Take meds at 9:00 AM daily"
- Expected: SMS at 9:00 AM EST ✅

Scenario 2: Different Timezone
- User: NYC (EST)
- Recipient: LA (PST)
- Habit: "Take meds at 9:00 AM daily"
- Expected: SMS at 9:00 AM PST (6:00 AM EST) ✅

Scenario 3: International
- User: Tokyo (JST)
- Recipient: NYC (EST)
- Habit: "Take meds at 9:00 AM daily"
- Expected: SMS at 9:00 AM EST ✅

Scenario 4: DST Transition
- User: NYC (EST)
- Recipient: NYC (EST)
- Habit: "Take meds at 9:00 AM daily"
- DST: Spring forward at 2:00 AM → 3:00 AM
- Expected: SMS still at 9:00 AM EDT ✅
```

---

## Migration Plan

### Phase 1: Add Fields (Backward Compatible)
1. Add timezone to Task model with optional decoder
2. Update TaskViewModel to save timezone
3. Deploy iOS app update

**Impact:** Zero downtime, new habits have timezone, old habits use fallback

### Phase 2: Update Cloud Functions
1. Install moment-timezone
2. Update calculateNextOccurrence() to use timezone
3. Deploy Cloud Functions update

**Impact:** Zero downtime, SMS start using correct timezone

### Phase 3: Backfill Old Data (Optional)
1. Write migration script to add timezone to old habits
2. Use profile's timezone as default
3. Run migration on production database

**Impact:** Improves accuracy for existing habits

---

## Workarounds for MVP

### Option A: Document Limitation
Add to documentation:
> **Timezone Limitation:** For best results, ensure the family member creating habits is in the same timezone as the elderly recipient. SMS delivery times are currently based on Pacific Time (PST/PDT).

### Option B: Force PST Only
Add validation:
```swift
guard profile.timeZone == "America/Los_Angeles" else {
    throw ProfileError.timezoneNotSupported
}
```

### Option C: Adjust User Expectations
UI text:
> "Your parent will receive this reminder at 9:00 AM Pacific Time"

---

## Related Files

### iOS (Swift)
- `Halloo/Models/Task.swift` - Task model (missing timezone)
- `Halloo/Models/ElderlyProfile.swift` - Profile model (has timezone)
- `Halloo/ViewModels/TaskViewModel.swift` - Date calculations
- `Halloo/ViewModels/ProfileViewModel.swift` - Profile creation

### Cloud Functions (Node.js)
- `functions/index.js` - SMS scheduling and date calculations
- `functions/package.json` - Dependencies (need moment-timezone)

### Documentation
- `Halloo/docs/RECURRING-TASK-SYSTEM.md` - Mentions timezone as future enhancement
- `Halloo/docs/TECHNICAL-DOCUMENTATION.md` - General architecture

---

## References

- [Moment Timezone Documentation](https://momentjs.com/timezone/)
- [iOS Calendar Timezone Handling](https://developer.apple.com/documentation/foundation/calendar)
- [Firestore Timestamp Best Practices](https://firebase.google.com/docs/firestore/manage-data/data-types#date_and_time)
- [Twilio SMS Best Practices - Timezone Considerations](https://www.twilio.com/docs/sms/best-practices)

---

## Decision Log

**2025-11-02:** Deferred timezone support to post-MVP
- **Reason:** Not critical for initial launch with single-timezone users
- **Risk:** Limited to PST-based users or same-timezone families
- **Mitigation:** Document limitation, plan for Phase 2 implementation

---

**Last Updated:** 2025-11-02
**Status:** Documented, awaiting implementation
**Owner:** TBD
**Target Release:** v1.1 (Post-MVP)
