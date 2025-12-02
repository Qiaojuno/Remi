# Halloo Technical Documentation

*Comprehensive guide covering data architecture, migrations, and feature implementations*

---

## Table of Contents

1. [Phone Number Format - E.164 Compliance](#phone-number-format---e164-compliance)
2. [Data Migration - Fix Task ProfileIds](#data-migration---fix-task-profileids)
3. [Archived Photos Feature - 90-Day Retention](#archived-photos-feature---90-day-retention)
4. [Real-Time Gallery Updates Fix](#real-time-gallery-updates-fix)
5. [Timezone Support for North America](#timezone-support-for-north-america)

---

# Phone Number Format - E.164 Compliance

## Issue
Twilio SMS was failing with error `21211: Invalid 'To' Phone Number` because phone numbers were stored in display format (e.g., "+1 (778) 814-3739") instead of E.164 format required by Twilio.

## Root Cause
The `formattedPhoneNumber` extension in `String+Extensions.swift` was designed for UI display, adding parentheses, spaces, and dashes. When ProfileViewModel used this for creating profiles, the formatted phone numbers were incompatible with Twilio's E.164 requirement.

**E.164 Format Requirements:**
- Start with `+` and country code
- Only digits after `+` (no spaces, dashes, parentheses)
- Example: `+17788143739`

## Solution
Created new `e164PhoneNumber` extension property specifically for Twilio SMS compatibility.

### Files Changed

#### 1. `/Halloo/Core/String+Extensions.swift`
**Added:** New `e164PhoneNumber` computed property (lines 67-96)

```swift
/// E.164 format phone number for Twilio SMS (e.g., +17788143739)
///
/// Converts any phone number format to E.164 standard required by Twilio.
/// This format has no spaces, dashes, or parentheses - just + and digits.
var e164PhoneNumber: String {
    let cleaned = phoneNumberDigitsOnly

    // Handle different phone number lengths
    switch cleaned.count {
    case 10:
        // US/Canada 10-digit number → add +1 country code
        return "+1\(cleaned)"

    case 11 where cleaned.hasPrefix("1"):
        // Already has country code 1 → just add +
        return "+\(cleaned)"

    default:
        // International or other format → just add + if needed
        if cleaned.count > 10 {
            return "+\(cleaned)"
        } else if cleaned.count == 10 {
            // Assume US/Canada if exactly 10 digits
            return "+1\(cleaned)"
        } else {
            // Invalid or too short
            return "+\(cleaned)"
        }
    }
}
```

**Purpose:**
- `formattedPhoneNumber`: Display format for UI (e.g., "+1 (778) 814-3739")
- `e164PhoneNumber`: SMS-compatible format for Twilio (e.g., "+17788143739")

#### 2. `/Halloo/ViewModels/ProfileViewModel.swift`
**Changed:** All phone number processing to use `.e164PhoneNumber`

**Line 672:** `createProfileAsync()` - Profile creation
```swift
// Before
let formattedPhone = phoneNumber.formattedPhoneNumber

// After
let e164Phone = phoneNumber.e164PhoneNumber
```

**Line 810:** `updateProfileAsync()` - Profile updates
```swift
// Before
let formattedPhone = phoneNumber.formattedPhoneNumber

// After
let e164Phone = phoneNumber.e164PhoneNumber
```

**Line 1535:** `createTemporaryProfileForSMS()` - Onboarding flow
```swift
// Before
let formattedPhone = phoneNumber.formattedPhoneNumber

// After
let e164Phone = phoneNumber.e164PhoneNumber
```

**Line 1293:** `validatePhoneNumber()` - Duplicate phone check
```swift
// Before
else if profiles.contains(where: { $0.phoneNumber == phone.formattedPhoneNumber && $0.id != selectedProfile?.id }) {

// After
else if profiles.contains(where: { $0.phoneNumber == phone.e164PhoneNumber && $0.id != selectedProfile?.id }) {
```

## Testing
1. Create a new elderly profile with phone number (e.g., "778-814-3739")
2. Verify profile.phoneNumber is stored as "+17788143739" (E.164)
3. Send SMS confirmation - should succeed without Twilio error 21211
4. Check Twilio logs - should show valid "To" phone number

## Impact
- **Fixes:** Twilio SMS delivery failures
- **Ensures:** All phone numbers stored consistently in E.164 format
- **Maintains:** Display formatting for UI using `formattedPhoneNumber`
- **Backward Compatible:** Existing profiles will be converted to E.164 on next update

## Related Files
- `Halloo/Core/String+Extensions.swift` - Phone number formatting utilities
- `Halloo/ViewModels/ProfileViewModel.swift` - Profile management and SMS
- `Halloo/Views/ProfileViews.swift` - Profile creation UI (uses formatted display)
- `functions/index.js` - Twilio SMS Cloud Function (validates E.164)

## References
- [Twilio E.164 Documentation](https://www.twilio.com/docs/glossary/what-e164)
- [E.164 Wikipedia](https://en.wikipedia.org/wiki/E.164)
- Twilio Error 21211: Invalid 'To' Phone Number

---

# Data Migration - Fix Task ProfileIds

## Problem

Your existing Firestore tasks have **phone numbers as `profileId`** (old schema) but the current code expects **UUID profile IDs** (new schema).

**Symptoms:**
- DashboardView shows 0 profiles
- HabitsView shows no habits
- GalleryView shows no profile info
- Console logs show:
  ```
  ❌ FILTERED: No profile found with id=+17788143739
  Available profile IDs: []
  ```

## Root Cause

Old schema (before ID standardization):
```swift
Task(profileId: "+17788143739")  // Phone number
```

New schema (after ID standardization):
```swift
Task(profileId: "A1B2C3D4-E5F6-...")  // UUID
Profile(id: "A1B2C3D4-E5F6-...", phoneNumber: "+17788143739")
```

## Solution Options

### Option 1: Clean Slate (Recommended for Testing)

**Delete all old habits and recreate them:**

1. Open Firebase Console → Firestore Database
2. Navigate to `users/{userId}/profiles/{profileId}/habits`
3. Delete all habits manually
4. Create new habits in the app (they will use correct UUID profileIds)

**Pros:** Clean, simple, no code needed
**Cons:** Loses existing habit data

---

### Option 2: Automatic Migration (Preserve Data)

**Use the migration helper to update existing tasks:**

1. Add this code to your `DashboardView.onAppear`:

```swift
.onAppear {
    viewModel.setProfileViewModel(profileViewModel)
    loadData()

    // ONE-TIME MIGRATION: Run this once to fix old data
    #if DEBUG
    Task {
        do {
            guard let userId = container.authService.currentUser?.uid else { return }
            let migration = FirestoreDataMigration()
            let count = try await migration.migrateTaskProfileIds(userId: userId)
            print("✅ Migrated \(count) tasks")
        } catch {
            print("❌ Migration failed: \(error)")
        }
    }
    #endif
}
```

2. Run the app once in DEBUG mode
3. Check console for migration success
4. Remove the migration code block

**Pros:** Preserves existing data
**Cons:** Requires code change

---

### Option 3: Delete Orphaned Habits via Code

**Quick cleanup without manual Firestore console work:**

```swift
.onAppear {
    viewModel.setProfileViewModel(profileViewModel)
    loadData()

    // ONE-TIME CLEANUP: Delete old habits with phone-number profileIds
    #if DEBUG
    Task {
        do {
            guard let userId = container.authService.currentUser?.uid else { return }
            let migration = FirestoreDataMigration()
            let count = try await migration.deleteOrphanedHabits(userId: userId)
            print("✅ Deleted \(count) orphaned habits")
        } catch {
            print("❌ Cleanup failed: \(error)")
        }
    }
    #endif
}
```

**Pros:** Automated cleanup
**Cons:** Deletes all old habits (need to recreate)

---

## Verification

After migration/cleanup, verify:

1. **DashboardView** shows profiles and tasks
2. **HabitsView** displays habits correctly
3. **Console logs** show:
   ```
   ✅ Profile matched! Checking if scheduled for 2025-10-09
   ✅ Task IS scheduled for today - creating DashboardTask
   ```

## Prevention

The new schema is now enforced:
- `ElderlyProfile.id` = UUID (stored in Firestore document ID)
- `Task.profileId` = UUID (matches profile.id)
- `ElderlyProfile.phoneNumber` = E.164 phone (+1234567890)

Future task creation automatically uses correct UUIDs (line 621 in TaskViewModel.swift).

---

## Quick Reference

**Check current data structure in Firestore:**
```
users/{userId}/
  └── profiles/{UUID}/       ← Profile ID is UUID
      ├── phoneNumber: "+17788143739"
      └── habits/{habitId}/
          └── profileId: ???  ← Should match parent UUID, not phone
```

**Expected behavior:**
```swift
Task(
  profileId: "45DD3B0E-D983-4917-AE79-2BC001BFBA38"  // UUID
)

Profile(
  id: "45DD3B0E-D983-4917-AE79-2BC001BFBA38",        // Same UUID
  phoneNumber: "+17788143739"                        // Phone stored separately
)
```

---

# ⚠️ DEPRECATED: Archived Photos Feature - 90-Day Retention

> **Status:** REMOVED in 2025-10-21
> **Reason:** Simplified to store all photos in Firebase Storage indefinitely
> **Impact:** 150 lines of code removed from GalleryViewModel

## Overview (Historical)
Previously implemented automated data retention policy that archived photos to Cloud Storage and deleted text data after 90 days. This feature has been removed in favor of a simpler approach.

## Business Requirements

### Privacy
- Delete sensitive SMS text messages after 90 days
- Remove task response metadata (titles, timestamps, etc.)
- Keep only photos for long-term memory preservation

### Cost Optimization
- **Before:** ~$2/user/year (3,000+ Firestore documents)
- **After:** ~$0.50/user/year (270 docs + Cloud Storage)
- **Savings:** 75% reduction in Firestore read costs (~$1.50/user/year)

### Memory Preservation
- Photos archived forever in Cloud Storage
- Organized by user/profile/year/month for easy browsing
- Original creation dates preserved in metadata

## Architecture

### Data Flow
```
Day 0-89: Gallery Event in Firestore (text + photo base64)
    ↓
Day 90: Cloud Function triggers cleanup
    ↓
1. Extract photo from gallery event
2. Upload to Cloud Storage with metadata
3. Delete Firestore event (text data removed)
    ↓
Forever: Archived photo accessible in Gallery "Archived Memories" section
```

### Storage Organization
```
Cloud Storage: gallery-archive/
├── {userId}/
│   ├── {profileId}/
│   │   ├── {year}/
│   │   │   ├── {month}/
│   │   │   │   ├── {eventId}.jpg (with metadata)
```

**Example:**
```
gallery-archive/
├── user123/
│   ├── profile456/
│   │   ├── 2025/
│   │   │   ├── 01/
│   │   │   │   ├── event789.jpg
│   │   │   │   ├── event790.jpg
│   │   │   ├── 02/
│   │   │   │   ├── event791.jpg
```

## Implementation

### 1. Cloud Function - Automated Cleanup

**File:** `/functions/index.js` (lines 240-446)

#### `cleanupOldGalleryEvents` (Scheduled Function)
- **Trigger:** Runs daily at midnight PST
- **Schedule:** `every 24 hours`
- **Batch Size:** 500 events per run (prevents timeout)

**Process:**
1. Query events older than 90 days using `collectionGroup('galleryEvents')`
2. For each event with photo:
   - Extract base64 photo data
   - Create organized file path: `{userId}/{profileId}/{year}/{month}/{eventId}.jpg`
   - Upload to Cloud Storage with metadata
   - Track: `userId`, `profileId`, `eventId`, `originalCreatedAt`, `archivedAt`, `taskTitle`
3. Delete Firestore event (text data permanently removed)
4. Log summary: photos archived, events deleted, errors

**Code:**
```javascript
exports.cleanupOldGalleryEvents = functions.pubsub
  .schedule('every 24 hours')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    // Calculate 90 days ago
    const threeMonthsAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 90 * 24 * 60 * 60 * 1000)
    );

    // Query old events across all users
    const oldEventsSnapshot = await db.collectionGroup('galleryEvents')
      .where('createdAt', '<', threeMonthsAgo)
      .limit(500)
      .get();

    // Archive photos and delete events
    // ... (see implementation)
  });
```

#### `manualCleanup` (HTTP Endpoint)
- **Trigger:** Manual HTTP POST request
- **Purpose:** Testing and debugging
- **Parameters:** `daysOld` (default: 90)

**Usage:**
```bash
curl -X POST https://us-central1-remi-91351.cloudfunctions.net/manualCleanup \
  -H "Content-Type: application/json" \
  -d '{"daysOld": 7}'
```

**Testing locally:**
```bash
curl -X POST http://localhost:5001/remi-91351/us-central1/manualCleanup \
  -H "Content-Type: application/json" \
  -d '{"daysOld": 7}'
```

### 2. Storage Security Rules

**File:** `/storage.rules` (lines 51-60)

```javascript
// Gallery archive - archived photos older than 90 days
// Read-only for users (photos archived by Cloud Function)
match /gallery-archive/{userId}/{profileId}/{year}/{month}/{photoId} {
  // Users can only read their own archived photos
  allow read: if isAuthenticated() && isOwner(userId);

  // Only Cloud Functions can write (via service account)
  // Users cannot upload/delete archived photos
  allow write: if false;
}
```

**Security:**
- Users can read only their own archived photos
- Cloud Functions write via Firebase Admin SDK (bypasses rules)
- Users cannot manually upload/delete archived photos
- Prevents unauthorized access to archived memories

### 3. iOS - GalleryViewModel

**File:** `/Halloo/ViewModels/GalleryViewModel.swift` (lines 95-335)

#### New Properties
```swift
/// Archived photos from Cloud Storage (older than 90 days)
@Published var archivedPhotos: [ArchivedPhoto] = []

/// Loading state for archived photos from Cloud Storage
@Published var isLoadingArchive = false
```

#### `loadArchivedPhotos()` Method (lines 235-316)
**Process:**
1. Get authenticated user ID
2. List all files under `gallery-archive/{userId}` in Cloud Storage
3. For each photo:
   - Get download URL
   - Extract metadata: `archivedAt`, `originalCreatedAt`, `profileId`
   - Create `ArchivedPhoto` object
4. Sort by `originalCreatedAt` (newest first)
5. Update `@Published` array for UI display

**Error Handling:**
- Gracefully handles individual photo failures
- Continues loading remaining photos if one fails
- Sets error message for user feedback

#### `ArchivedPhoto` Model (lines 322-335)
```swift
struct ArchivedPhoto: Identifiable, Codable {
    let id: String
    let url: URL
    let archivedAt: Date
    let originalCreatedAt: Date?
    let profileId: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: originalCreatedAt ?? archivedAt)
    }
}
```

### 4. iOS - GalleryView UI

**File:** `/Halloo/Views/GalleryView.swift` (lines 340-409, 72-74)

#### Archived Memories Section (lines 340-409)
**Features:**
- Section header: "Archived Memories (90+ days)" in gray
- Loading state with circular progress indicator
- Empty state: "No archived photos yet"
- 3-column grid matching recent gallery layout
- AsyncImage for efficient Cloud Storage loading
- Loading placeholders and error states

**Code:**
```swift
// Archived Memories Section (photos older than 90 days)
if !viewModel.archivedPhotos.isEmpty || viewModel.isLoadingArchive {
    VStack(alignment: .leading, spacing: 8) {
        // Section header
        HStack {
            Text("Archived Memories (90+ days)")
                .tracking(-1)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(hex: "9f9f9f"))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)

        if viewModel.isLoadingArchive {
            // Loading indicator
            ProgressView()
        } else if viewModel.archivedPhotos.isEmpty {
            // Empty state
            Text("No archived photos yet")
        } else {
            // Archived photo grid
            LazyVGrid(columns: gridColumns, spacing: 4) {
                ForEach(viewModel.archivedPhotos) { photo in
                    AsyncImage(url: photo.url) { phase in
                        // Loading/success/failure states
                    }
                }
            }
        }
    }
}
```

#### Load on View Appear (lines 72-74)
```swift
.task {
    await viewModel.loadGalleryData()
    await viewModel.loadArchivedPhotos()
}
```

## Deployment

### 1. Deploy Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

**Deployed Functions:**
- `cleanupOldGalleryEvents` - Scheduled cleanup (runs daily)
- `manualCleanup` - Manual testing endpoint

### 2. Deploy Storage Rules
```bash
firebase deploy --only storage
```

### 3. iOS App Update
- Build and deploy new version with archived photos UI
- Users will see "Archived Memories" section after 90 days

## Testing

### Local Testing (Emulator)
```bash
# Start emulators
firebase emulators:start

# Test manual cleanup with 7-day threshold
curl -X POST http://localhost:5001/remi-91351/us-central1/manualCleanup \
  -H "Content-Type: application/json" \
  -d '{"daysOld": 7}'
```

### Production Testing
1. Create test gallery events with old timestamps (backdated 91 days)
2. Trigger manual cleanup endpoint
3. Verify:
   - Photos uploaded to Cloud Storage
   - Metadata preserved (dates, profile IDs)
   - Firestore events deleted
   - iOS app displays archived photos

### Monitoring
```bash
# View Cloud Function logs
firebase functions:log --only cleanupOldGalleryEvents

# Check Cloud Storage bucket
gsutil ls -r gs://remi-91351.appspot.com/gallery-archive/
```

## Migration Plan

### Phase 1: Deploy (Immediate)
1. Deploy Cloud Function (scheduled but won't run immediately)
2. Deploy Storage rules
3. Deploy iOS app with archived photos UI

### Phase 2: Initial Cleanup (Day 1)
1. Cloud Function runs at midnight PST
2. Archives all photos older than 90 days
3. Monitor logs for errors

### Phase 3: Steady State (Ongoing)
- Daily cleanup runs automatically
- Processes 500 events per day (adjustable if needed)
- Users see archived photos in Gallery view

### Rollback Plan
If issues occur:
1. Disable scheduled function: `firebase functions:delete cleanupOldGalleryEvents`
2. Photos remain in Cloud Storage (safe)
3. Fix issues and redeploy

## Performance

### Cloud Function
- **Execution Time:** ~5-10 seconds per 100 events
- **Batch Size:** 500 events per run
- **Frequency:** Daily (midnight PST)
- **Cost:** Minimal (~$0.01/month for typical usage)

### iOS App
- **Initial Load:** ~1-2 seconds for 100 archived photos
- **Memory:** Efficient with AsyncImage lazy loading
- **Network:** Downloads photos on-demand as user scrolls

## Cost Analysis

### Firestore (Before)
- 10 events/day × 365 days × 3 years = 10,950 documents
- 10,950 reads/month × $0.06/100K = ~$0.66/month
- **Annual:** ~$7.92/user

### Firestore (After)
- 10 events/day × 90 days = 900 documents
- 900 reads/month × $0.06/100K = ~$0.05/month
- **Annual:** ~$0.60/user

### Cloud Storage
- 10 photos/day × 3 years × 500KB = ~5.5 GB
- 5.5 GB × $0.026/GB = ~$0.14/month
- **Annual:** ~$1.68/user

### Total Savings
- **Before:** $7.92/user/year
- **After:** $2.28/user/year
- **Savings:** $5.64/user/year (71% reduction)

## Future Enhancements

### Potential Features
1. **Download Archive:** Allow users to download all archived photos as ZIP
2. **Share Memories:** Share archived photos via social media
3. **Search:** Search archived photos by date, profile, or event type
4. **Filters:** Filter archived photos by profile or time period
5. **Pagination:** Lazy load archived photos in batches (for large archives)

### Monitoring & Alerts
1. Set up Cloud Function error alerts
2. Monitor Cloud Storage usage
3. Track cleanup success rate
4. Alert on archival failures

## Related Files

### Backend
- `/functions/index.js` - Cloud Functions implementation
- `/functions/README.md` - Deployment documentation
- `/storage.rules` - Cloud Storage security rules

### iOS
- `/Halloo/ViewModels/GalleryViewModel.swift` - Archived photos logic
- `/Halloo/Views/GalleryView.swift` - Archived photos UI

---

# Real-Time Gallery Updates Fix

## Issue
Gallery UI was not updating in real-time when SMS responses created gallery events, despite successful data flow through Firestore → Real-time listener → AppState chain.

## Root Causes

### 1. SwiftUI Property Wrapper Bug
**File:** `ContentView.swift:33`

AppState was declared as `@State` instead of `@StateObject`:
- `@State` only watches variable reassignment, doesn't subscribe to `@Published` properties
- `@StateObject` subscribes to all `@Published` properties in ObservableObject
- Result: Data reached AppState but SwiftUI wasn't watching it

### 2. Event Type Rendering Bug
**File:** `GalleryView.swift:360`

Gallery hardcoded to only render `taskResponse` events:
- Ignored `profileCreated` events entirely
- Needed switch statement to handle multiple event types
- Added `galleryEventView(for:)` helper function

### 3. Listener Crash on Malformed Data
**File:** `FirebaseDatabaseService.swift:735`

Listener crashed on single bad event, blocking all new events:
- Old events had `photoData: "<null>"` (JS null) causing decode failure
- Changed from `map { try }` to `compactMap { try? }` for fault tolerance
- Skip bad events instead of crashing entire listener

### 4. Duplicate Profile Creation Events
**File:** `ProfileViewModel.swift:1068`

Gallery events duplicated 20+ times on app launch:
- SMS listener replays all historical messages on launch
- Time-based deduplication insufficient (old timestamps bypass check)
- Implemented Set-based tracking: `profilesWithGalleryEvents = Set<String>()`

## Solution

### ContentView.swift
```swift
// Changed from @State to @StateObject with inline initialization
@StateObject private var appState: AppState = {
    let container = Container.shared
    return AppState(
        authService: container.resolve(AuthenticationServiceProtocol.self),
        databaseService: container.resolve(DatabaseServiceProtocol.self),
        dataSyncCoordinator: container.resolve(DataSyncCoordinator.self)
    )
}()
```

### GalleryView.swift
```swift
@ViewBuilder
private func galleryEventView(for event: GalleryHistoryEvent) -> some View {
    switch event.eventData {
    case .taskResponse:
        GalleryPhotoView.taskResponse(...)
    case .profileCreated:
        GalleryPhotoView.profilePhoto(...)
    }
}
```

### FirebaseDatabaseService.swift
```swift
// Fault-tolerant listener - skip bad events instead of crashing
let events = documents.compactMap { document -> GalleryHistoryEvent? in
    do {
        return try self.decodeFromFirestore(document.data(), as: GalleryHistoryEvent.self)
    } catch {
        print("❌ Failed to decode gallery event \(document.documentID) - SKIPPING")
        return nil
    }
}
subject.send(events)
```

### ProfileViewModel.swift
```swift
// Set-based deduplication
private var profilesWithGalleryEvents = Set<String>()

private func createGalleryEventForProfile(_ profile: ElderlyProfile, profileSlot: Int) {
    guard !profilesWithGalleryEvents.contains(profile.id) else { return }

    // Create event...

    await MainActor.run {
        self.profilesWithGalleryEvents.insert(profile.id)
    }
}
```

## Related Files

### iOS
- `/Halloo/Views/ContentView.swift` - @StateObject fix
- `/Halloo/Views/GalleryView.swift` - Event type rendering
- `/Halloo/Services/FirebaseDatabaseService.swift` - Fault-tolerant listener
- `/Halloo/ViewModels/ProfileViewModel.swift` - Set-based deduplication

### Documentation
- `/Halloo/docs/sessions/SESSION-2025-10-20-RealTimeGalleryFix.md` - Detailed session notes

### Cleanup Scripts (Temporary)
- `/cleanup-gallery-duplicates.js` - Remove duplicate events from Firestore
- `/UI-UPDATE-FIX.md` - UI update debugging notes

## Key Learnings

1. **@State vs @StateObject:** Using wrong property wrapper silently breaks reactive updates
2. **Fault tolerance:** Use `compactMap` for real-time listeners with legacy data
3. **Set-based deduplication:** More robust than time-based checks for replayed events
4. **Type-specific rendering:** Don't hardcode single type when data model supports multiple

---

# Image Caching System

## Issue
Profile photos and gallery images were reloading from Firebase Storage every time users switched tabs, causing:
- AsyncImage placeholder flicker (empty → loading → image)
- Unnecessary network requests
- Poor user experience with loading spinners

## Solution - NSCache-Based Image Service

**File:** `/Halloo/Services/ImageCacheService.swift` (NEW - 160 lines)

### Architecture
```swift
final class ImageCacheService: ObservableObject {
    private let cache = NSCache<NSString, UIImage>()
    @Published private(set) var loadedImages: Set<String> = []

    init() {
        cache.countLimit = 20           // Max 20 images
        cache.totalCostLimit = 50_000_000  // 50MB limit
    }
}
```

### Features

**1. Memory Cache with Automatic Eviction**
- Uses Apple's `NSCache` for automatic memory management
- Evicts least-recently-used images under memory pressure
- Thread-safe for concurrent access

**2. Parallel Preloading on App Launch**
```swift
// In AppState.loadUserData()
async let profilePhotosTask: Void = imageCache.preloadProfileImages(profiles)
async let galleryPhotosTask: Void = imageCache.preloadGalleryPhotos(galleryEvents)

_ = await profilePhotosTask
_ = await galleryPhotosTask
```

**3. Cache-First Lookup in UI**
```swift
// ProfileImageView.swift
if let cachedUIImage = appState.imageCache.getCachedImage(for: profile.photoURL) {
    // Use cached image directly - synchronous, no placeholder
    Image(uiImage: cachedUIImage)
        .resizable()
        .aspectRatio(contentMode: .fill)
} else {
    // Fallback to AsyncImage (first load or cache miss)
    AsyncImage(url: URL(string: profile.photoURL ?? "")) { /* ... */ }
}
```

### Integration Points

**Files Modified:**
- `AppState.swift` - Added imageCache parameter, parallel preloading
- `Container.swift` - Registered ImageCacheService singleton
- `ProfileImageView.swift` - Cache-first lookup
- `GalleryPhotoView.swift` - Cache-first for profile creation photos
- `GalleryDetailView.swift` - Cache-first for full-screen photos
- `ContentView.swift` - Injected imageCache to AppState

### Performance Impact

**Before:**
- 6 Firebase Storage requests per tab switch
- ~200ms loading time per image
- AsyncImage placeholders visible

**After:**
- 0 Firebase Storage requests after initial load
- <1ms synchronous cache lookup
- No placeholders or loading states

### Memory Management
- **Cache Limit:** 20 images max
- **Size Limit:** 50MB total
- **Eviction:** Automatic under memory pressure
- **Thread Safety:** NSCache is thread-safe by default

### What's Cached
✅ Profile photos (profile.photoURL)
✅ Gallery profile creation photos (profileCreated events)
❌ Task response photos (use Data blobs, not URLs)

### Related Files
- `/Halloo/Services/ImageCacheService.swift` - Cache implementation
- `/Halloo/Core/AppState.swift` - Preloading integration
- `/Halloo/Models/Container.swift` - Service registration
- `/Halloo/Views/Components/ProfileImageView.swift` - UI integration
- `/Halloo/Views/Components/GalleryPhotoView.swift` - UI integration
- `/Halloo/Views/GalleryDetailView.swift` - UI integration

---

# Friendly SMS Message Generation System (Commit: ffd2878)

**Updated:** 2025-11-04
**Status:** Complete - Replaced robotic templates with warm, randomized messages

## Overview

The SMS reminder system has been completely overhauled to generate friendly, human-like messages instead of robotic templates. Each message is randomly composed from 120 unique combinations, making every reminder feel personal and caring.

## What Changed

### Before (Robotic Template)
```
Hi Mom! Time to: Take Vitamins

Reply with a photo when done.
```

### After (Warm & Randomized)
```
Hello Mom 🌞 A gentle reminder to Take Vitamins

Snap a quick photo when you finish — it always brightens the day 🌿
```

```
Hey Mom, Thinking of you — remember to Take Vitamins

Once you're done, share a picture — it'll make me smile 😊
```

```
Hi Mom! Hope you're doing well. Time to Take Vitamins

When you're done, send a photo — I'd love to see your progress 📸
```

## Message Structure

Each SMS is composed of three parts that are randomly selected:

### 1. Greeting Variations (5 options)
- `"Hi [Name]!"`
- `"Hello [Name] 🌞"`
- `"Hey [Name],"`
- `"Hi [Name]! Hope you're doing well."`
- `"Hey there, [Name]!"`

### 2. Prompt Variations (6 options)
- `"Time to"`
- `"A gentle reminder to"`
- `"Just a friendly nudge to"`
- `"Don't forget to"`
- `"Thinking of you — remember to"`
- `"Quick reminder to"`

### 3. Instruction Variations (4 types based on response requirements)

**Photo Required:**
- `"Snap a quick photo when you finish — it always brightens the day 🌿"`
- `"When you're done, send a photo — I'd love to see your progress 📸"`
- `"Once you're done, share a picture — it'll make me smile 😊"`
- `"Send a photo when complete — it helps me feel connected to you 💙"`
- `"Share a photo afterward — seeing it really makes my day ✨"`

**Text Required:**
- `"Just reply when you're finished 💬"`
- `"Send a quick message when done — I'd love to hear from you 💌"`
- `"Reply when complete — it means a lot to me 🤗"`
- `"Let me know when you're done — it makes my day to hear from you 💙"`
- `"Drop me a message afterward — I always look forward to it ✨"`

**Both Photo & Text:**
- `"Send a photo and a quick note when done — I'd love to see and hear from you 📸💬"`
- `"Share a picture and message when complete — it really brightens my day 🌟"`
- `"Reply with a photo and a few words when finished — it means so much to me 💙"`
- `"Send a photo and tell me how it went — I love staying connected with you ✨"`
- `"Share a picture and a quick update afterward — hearing from you always makes my day 🤗"`

**Flexible (No specific requirement):**
- `"Let me know when you're done, however you'd like — photo, text, or just a quick hello 💙"`
- `"Reply in any way when complete — I just love hearing from you ✨"`
- `"Send a photo, a message, or just say hi when done — whatever feels right 🤗"`
- `"Share however you'd like when finished — I'm just happy to stay in touch 💌"`
- `"Reply when you're done — photo, text, or both — whatever works best for you 🌟"`

## Technical Implementation

### Cloud Functions (functions/index.js)

**Updated Function:** `getTaskReminderMessage()` (lines 1349-1421)

```javascript
function getTaskReminderMessage(habit, profile) {
  const greetings = [
    `Hi ${profile.name}!`,
    `Hello ${profile.name} 🌞`,
    `Hey ${profile.name},`,
    `Hi ${profile.name}! Hope you're doing well.`,
    `Hey there, ${profile.name}!`
  ];

  const prompts = [
    "Time to",
    "A gentle reminder to",
    "Just a friendly nudge to",
    "Don't forget to",
    "Thinking of you — remember to",
    "Quick reminder to"
  ];

  // 4 instruction sets (5 variations each) based on response type
  const instructionsPhoto = [ /* 5 variations */ ];
  const instructionsText = [ /* 5 variations */ ];
  const instructionsBoth = [ /* 5 variations */ ];
  const instructionsFlexible = [ /* 5 variations */ ];

  // Randomly select components
  const greeting = greetings[Math.floor(Math.random() * greetings.length)];
  const prompt = prompts[Math.floor(Math.random() * prompts.length)];

  // Select instruction set based on habit requirements
  let instructions;
  if (habit.requiresPhoto && habit.requiresText) {
    instructions = instructionsBoth[Math.floor(Math.random() * instructionsBoth.length)];
  } else if (habit.requiresPhoto) {
    instructions = instructionsPhoto[Math.floor(Math.random() * instructionsPhoto.length)];
  } else if (habit.requiresText) {
    instructions = instructionsText[Math.floor(Math.random() * instructionsText.length)];
  } else {
    instructions = instructionsFlexible[Math.floor(Math.random() * instructionsFlexible.length)];
  }

  return `${greeting} ${prompt} ${habit.title}\n\n${instructions}`;
}
```

**Total Combinations:** 5 greetings × 6 prompts × 4 instruction types × 5 variations = 120 unique messages per habit

### Data Storage

**Habit Document Update (line 943):**
```javascript
await habitDoc.ref.update({
  nextScheduledDate: nextOccurrence,
  lastSentMessage: message  // Store the actual SMS sent
});
```

**Gallery Event Creation (line 373):**
```javascript
const galleryEvent = {
  userId,
  profileId,
  eventType: 'taskResponse',
  eventData: {
    taskId: habitDoc.id,
    profileName: profile.name,
    taskTitle: habit.title,
    textResponse: responseText,
    photoData: photoBase64,
    responseType: 'both',
    sentMessage: habit.lastSentMessage  // Include in gallery
  },
  timestamp: admin.firestore.FieldValue.serverTimestamp(),
  createdAt: admin.firestore.FieldValue.serverTimestamp()
};
```

### Swift Models (iOS)

**GalleryHistoryEvent.swift - SMSResponseData:**
```swift
struct SMSResponseData: Codable {
    let taskId: String
    let profileName: String
    let profilePhotoURL: String?
    let taskTitle: String
    let textResponse: String?
    let photoData: String?
    let responseType: String
    let sentMessage: String?  // NEW: Actual SMS sent
}
```

**GalleryHistoryEvent Extension:**
```swift
extension GalleryHistoryEvent {
    var sentMessage: String? {
        switch eventData {
        case .taskResponse(let data):
            return data.sentMessage
        case .profileCreated:
            return nil
        }
    }
}
```

### CardStackView Display (iOS)

**CardStackView.swift - Blue bubble displays actual message:**
```swift
// Blue bubble - What we sent (actual SMS)
if let sentMessage = event.sentMessage {
    // Display the actual randomized message
    Text(sentMessage)
        .font(.system(size: 14))
        .foregroundColor(.black)
        .padding(12)
        .background(Color(hex: "B9E3FF"))
        .cornerRadius(16)
} else {
    // Fallback for old events without sentMessage
    Text("Hi \(event.profileName)! Time to: \(event.taskTitle)\n\nReply with a photo when done.")
        .font(.system(size: 14))
        .foregroundColor(.black)
        .padding(12)
        .background(Color(hex: "B9E3FF"))
        .cornerRadius(16)
}
```

### TwilioSMSService (iOS)

**TwilioSMSService.swift - Matching implementation:**
The Swift service includes an identical `getTaskReminderMessage()` function for local testing and preview generation.

## Impact & Benefits

### User Experience
- Messages feel warm, personal, and caring
- Elderly users feel valued rather than managed
- Reduces "notification fatigue" with varied wording
- Emojis add emotional warmth without being overwhelming

### Technical Benefits
- Gallery displays actual sent messages (not generic templates)
- CardStack shows authentic conversation history
- `lastSentMessage` stored for audit trail
- Backward compatible (old events use fallback text)

### Business Value
- Differentiates product from competitors
- Reinforces brand as caring and human-centered
- Improves user sentiment and engagement
- Reduces perceived "robot-ness" of automated reminders

## Testing Scenarios

### Scenario 1: Photo Required
**Habit:** "Take Vitamins" (requiresPhoto: true)
**Expected Output:** Random combination like:
```
Hello Mom 🌞 A gentle reminder to Take Vitamins

Snap a quick photo when you finish — it always brightens the day 🌿
```

### Scenario 2: Text Required
**Habit:** "Morning Walk" (requiresText: true)
**Expected Output:** Random combination like:
```
Hey Mom, Don't forget to Morning Walk

Send a quick message when done — I'd love to hear from you 💌
```

### Scenario 3: Both Photo & Text
**Habit:** "Lunch" (requiresPhoto: true, requiresText: true)
**Expected Output:** Random combination like:
```
Hi Mom! Time to Lunch

Send a photo and a quick note when done — I'd love to see and hear from you 📸💬
```

### Scenario 4: Flexible Response
**Habit:** "Check In" (no requirements)
**Expected Output:** Random combination like:
```
Hey there, Mom! Quick reminder to Check In

Let me know when you're done, however you'd like — photo, text, or just a quick hello 💙
```

## Related Files

### Backend
- `/functions/index.js` (lines 1349-1421) - Message generation
- `/functions/index.js` (line 943) - Store lastSentMessage
- `/functions/index.js` (line 373) - Gallery event with sentMessage

### iOS
- `/Halloo/Models/GalleryHistoryEvent.swift` - sentMessage field
- `/Halloo/Views/Components/CardStackView.swift` - Display sent messages
- `/Halloo/Services/TwilioSMSService.swift` - Matching Swift implementation

### Documentation
- `/Halloo/docs/firebase/SCHEMA.md` - Updated schema with lastSentMessage and sentMessage fields
- `/Halloo/docs/TECHNICAL-DOCUMENTATION.md` - This section

## Future Enhancements

### Potential Improvements
1. **Localization**: Translate greeting/prompt/instruction arrays to other languages
2. **Time-of-Day Variations**: Different greetings for morning/afternoon/evening
3. **Relationship Customization**: Adjust tone based on relationship (parent/spouse/friend)
4. **Completion Celebrations**: Special messages for streaks or milestones
5. **AI Personalization**: Learn recipient's preferred message style over time

---

# Build Configuration Updates (2025-10-21)

## StoreKit Configuration Fix
**Issue:** Xcode couldn't find StoreKit.storekit file
**Root Cause:** Scheme file referenced wrong path (`Halloo/Views/StoreKit.storekit`)
**Fix:** Updated `Halloo.xcscheme` to correct path (`../StoreKit.storekit`)

**File:** `/Halloo.xcodeproj/xcshareddata/xcschemes/Halloo.xcscheme:78`

## Dead Code Stripping
**Enabled for all build configurations:**
- Reduces app size by removing unused code
- Standard Apple recommendation for production apps
- Enabled in Debug and Release configurations

**File:** `/Halloo.xcodeproj/project.pbxproj`
```
DEAD_CODE_STRIPPING = YES;
```

## iOS 18 API Updates

### Font Registration (AppFonts.swift)
**Changed:** Deprecated `CTFontManagerRegisterGraphicsFont` → Modern `CTFontManagerRegisterFontsForURL`

```swift
// Before (deprecated in iOS 18)
guard let font = CGFont(provider) else { return }
CTFontManagerRegisterGraphicsFont(font, &error)

// After (iOS 13+ compatible)
guard let fontURL = Bundle.main.url(...) else { return }
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
```

### onChange Syntax (iOS 17+)
**Fixed 11 occurrences across:**
- `HabitsView.swift`
- `DashboardView.swift`
- `CardStackView.swift`

```swift
// Before (deprecated)
.onChange(of: value) { newValue in }

// After (iOS 17+)
.onChange(of: value) { oldValue, newValue in }
```

## Compiler Warnings Fixed (9 total)

**1. Unreachable Catch Block** (`App.swift`)
```swift
// Before - HalloApp.configureFirebase() doesn't throw
do {
    HalloApp.configureFirebase()
} catch { }  // Unreachable

// After
HalloApp.configureFirebase()
```

**2. Unnecessary Conditional Casts** (`FirebaseDatabaseService.swift`)
```swift
// Before - document.data() already returns [String: Any]
guard let data = document.data() as? [String: Any] else { }

// After
let data = document.data()
```

**3. Unnecessary try Expressions** (`FirebaseDatabaseService.swift`)
```swift
// Before - No throwing calls inside
return try snapshot.documents.compactMap { }

// After
return snapshot.documents.compactMap { }
```

**4. Unused Variables** (`GalleryHistoryEvent.swift`, `FirebaseDatabaseService.swift`)
```swift
// Before
case .taskResponse(let data):  // 'data' never used
    return "With SMS"

// After
case .taskResponse:
    return "With SMS"
```

---

# HabitsView UI Redesign & Code Deduplication

**Updated: 2025-10-30**

## Overview
Major HabitsView redesign with improved UX, 33% more compact layout, and significant code deduplication through new utility files.

## HabitsView UI Changes

### Week Selector Redesign
**Changed:** Single letter day abbreviations → 3-letter abbreviations

**Before:**
- Day labels: S, M, T, W, T, F, S (confusing, hard to distinguish)
- Selected: White background with border
- Unselected: Grey background

**After:**
- Day labels: Sun, Mon, Tue, Wed, Thu, Fri, Sat (clear, unambiguous)
- Selected: White background (#FFFFFF), black text, no border (raised appearance)
- Unselected: Dark grey (#E8E8E8), light grey text (#9f9f9f) (divot appearance)
- Depth effect: Visual hierarchy through background contrast

### Habit Row Redesign (33% More Compact)
**Changed:** Bulky rows with redundant info → Streamlined, information-dense rows

**Removed Elements:**
- Profile photo (redundant when viewing single profile's habits)
- Profile name text (already known from context)
- Mini week strip visualization (replaced with text)
- Custom Inter font (switched to system fonts)

**Added Elements:**
- Functional icons: 📷 (photo required), 💬 (text required)
- Smart frequency text: "Daily", "Weekdays", "Mon, Wed, Fri", etc.

**Size Changes:**
- Row height: 90pt → 60pt (33% reduction)
- Emoji size: 32pt → 24pt (smaller, cleaner)
- Typography: System font, 17pt, semibold

### Card Structure Changes
**Before:**
- Single card with "All Scheduled Tasks" title
- Week selector and habits in same card

**After:**
- Two separate cards for visual clarity:
  1. Week filter card (top) - Contains week selector only
  2. Habits list card (bottom) - Contains habit rows only
- Removed redundant title text
- Cleaner visual hierarchy

## Navigation Behavior Updates

### Tab Swiping Restrictions
**File:** `/Halloo/Views/ContentView.swift`

**Implementation:**
```swift
TabView(selection: $selectedTab) {
    DashboardView()
        .tag(0)
        // ✅ Swiping enabled to Gallery

    GalleryView()
        .tag(1)
        // ✅ Limited swiping (can swipe back to Dashboard)
        // ❌ Cannot swipe forward to Habits

    HabitsView()
        .tag(2)
        .gesture(DragGesture()) // ❌ Disables ALL swiping
}
```

**Behavior:**
- **Dashboard ↔ Gallery**: Bidirectional swiping enabled
- **Gallery → Habits**: Swiping disabled (no preview effect)
- **Habits**: All tab swiping disabled to prevent swipe-to-delete conflicts
- **Tab bar buttons**: Always functional on all tabs

**Rationale:**
- Habits view uses swipe-to-delete gesture for habit management
- Tab swiping interferes with swipe-to-delete UX
- Tab bar navigation provides clear alternative

## Code Deduplication - New Utility Files

### 1. DateFormatters.swift
**File:** `/Halloo/Core/DateFormatters.swift` (45 lines)

**Problem Solved:**
- 6 duplicate `formatTime()` functions across multiple view files
- Inconsistent time formatting (some ignored device locale/timezone)
- Maintenance burden: Updating time format required changing 6 files

**Solution:**
```swift
import Foundation

struct DateFormatters {
    // Locale-aware time formatting (e.g., "5:00 PM" or "17:00" based on device)
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // Task-specific time formatting (e.g., "5PM", "5:00PM")
    static func formatTaskTime(_ date: Date, includeMinutes: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = includeMinutes ? "h:mma" : "ha"
        return formatter.string(from: date)
    }

    // Date formatting (e.g., "October 30, 2025")
    static func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = style
        return formatter.string(from: date)
    }
}
```

**Usage:**
```swift
// Before (in each view file)
func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "ha"
    return formatter.string(from: date)
}

// After (import once, use everywhere)
import DateFormatters
let timeString = DateFormatters.formatTime(task.scheduledTime)
```

**Files Updated:**
- DashboardView.swift
- HabitsView.swift
- TaskViews.swift
- GalleryView.swift
- OnboardingViews.swift
- ProfileViews.swift

### 2. Color+Extensions.swift
**File:** `/Halloo/Core/Color+Extensions.swift` (30 lines)

**Problem Solved:**
- Hex color utility previously defined in DashboardView only
- Other views couldn't use hex colors without duplicating code
- DRY violation: Color parsing logic not reusable

**Solution:**
```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

**Usage:**
```swift
// Available everywhere after import
Color(hex: "f9f9f9")  // Background color
Color(hex: "B9E3FF")  // Button color
Color(hex: "#7A7A7A") // Text color (# prefix optional)
```

**Files Using:**
- DashboardView.swift (moved from here)
- HabitsView.swift
- GalleryView.swift
- All view files using hex colors

### 3. HapticFeedback.swift
**File:** `/Halloo/Core/HapticFeedback.swift` (38 lines)

**Problem Solved:**
- 42 duplicate haptic feedback calls across view files
- Inconsistent patterns: Some used light(), some used medium(), some used heavy()
- Boilerplate code: `UIImpactFeedbackGenerator(style: .light).impactOccurred()` repeated

**Solution:**
```swift
import UIKit

struct HapticFeedback {
    // Impact feedback
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    // Selection feedback (for picker/selector changes)
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // Notification feedback
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
```

**Usage:**
```swift
// Before (in each view file)
UIImpactFeedbackGenerator(style: .light).impactOccurred()

// After (clean, semantic)
HapticFeedback.light()
HapticFeedback.selection() // For week selector changes
HapticFeedback.success()   // For habit completion
```

**Common Patterns:**
- `HapticFeedback.light()`: Button taps, minor interactions
- `HapticFeedback.selection()`: Picker/selector changes (week selector)
- `HapticFeedback.success()`: Task completion, successful actions
- `HapticFeedback.error()`: Validation failures, errors

**Files Updated:**
- HabitsView.swift (week selector taps)
- DashboardView.swift (profile selection)
- TaskViews.swift (habit creation)
- ProfileViews.swift (profile creation)
- CardStackView.swift (swipe actions)

## Impact Summary

### Code Reduction
- **DateFormatters**: Eliminated 6 duplicate functions (~60 lines)
- **Color+Extensions**: Moved from DashboardView, now shared (~30 lines reuse)
- **HapticFeedback**: Replaced 42 duplicate calls (~84 lines → ~42 calls)
- **Total**: ~150 lines of duplicate code eliminated

### Consistency Improvements
- **Time Formatting**: Now respects device locale and timezone settings
- **Hex Colors**: Consistent parsing across all views
- **Haptic Patterns**: Standardized feedback types for common actions

### Maintainability
- **Single Source of Truth**: Utilities in Core/ directory
- **Easy Updates**: Change time format in one place, affects all views
- **Reduced Bugs**: No more inconsistent time formatting edge cases

## Related Files

### New Files Created
- `/Halloo/Core/DateFormatters.swift` (45 lines)
- `/Halloo/Core/Color+Extensions.swift` (30 lines - moved from DashboardView)
- `/Halloo/Core/HapticFeedback.swift` (38 lines)

### Files Modified
- `/Halloo/Views/HabitsView.swift` (complete redesign)
- `/Halloo/Views/DashboardView.swift` (navigation + utility imports)
- `/Halloo/Views/ContentView.swift` (tab swiping configuration)
- `/Halloo/Views/TaskViews.swift` (utility imports)
- `/Halloo/Views/ProfileViews.swift` (utility imports)
- `/Halloo/Views/GalleryView.swift` (utility imports)
- `/Halloo/Views/OnboardingViews.swift` (utility imports)

---

# EXIF Metadata Stripping for Privacy Protection

**Updated:** 2025-11-06
**Status:** Complete - All photo uploads now strip EXIF metadata

## Overview

All photos uploaded to Firebase Storage are now stripped of EXIF metadata before transmission to protect user privacy. This prevents exposure of sensitive information including GPS coordinates, device details, timestamps, and photo editing history.

## Privacy Risk Context

For an elderly care app handling photos of vulnerable individuals, EXIF metadata poses **HIGH privacy risks**:

### Metadata That Gets Removed:
- **GPS Coordinates**: Exact latitude/longitude of where photo was taken (reveals home addresses)
- **Device Information**: iPhone model, iOS version, device owner name
- **Timestamps**: Exact date/time photo was taken (reveals activity patterns)
- **Camera Settings**: Aperture, focal length, ISO (fingerprints device)
- **Photo Editing History**: Software used, edit timestamps
- **Device Owner Name**: May contain personal identifiable information

### Why This Matters for Elderly Care:
- Protects vulnerable individuals' home locations
- Prevents tracking of activity patterns via timestamps
- Removes device fingerprinting information
- GDPR compliance: Minimizes personal data collection
- Builds trust with privacy-conscious family members

## Technical Implementation

### UIImage Extension
**File:** `/Halloo/Extensions/UIImage+EXIFStripping.swift` (lines 14-58)

```swift
extension UIImage {
    /// Strips EXIF metadata from image by re-rendering it
    ///
    /// This method removes all embedded metadata including:
    /// - GPS location coordinates
    /// - Device information (model, iOS version)
    /// - Camera settings (aperture, focal length, etc.)
    /// - Timestamps and dates
    /// - Photo editing history
    /// - Device owner name
    ///
    /// - Parameter compressionQuality: JPEG compression quality (0.0 to 1.0, default 0.8)
    /// - Returns: JPEG data without EXIF metadata, or nil if conversion fails
    ///
    /// - Important: This is critical for elderly care app privacy where photos may reveal:
    ///   - Home addresses (GPS coordinates)
    ///   - Activity patterns (timestamps)
    ///   - Vulnerable individual locations
    func jpegDataWithoutEXIF(compressionQuality: CGFloat = 0.8) -> Data? {
        // Re-render the image to strip all metadata
        // UIGraphicsBeginImageContext creates a new clean image without metadata
        UIGraphicsBeginImageContext(self.size)
        defer { UIGraphicsEndImageContext() }

        // Draw the original image into the new context
        self.draw(in: CGRect(origin: .zero, size: self.size))

        // Get the newly rendered image (without any metadata)
        guard let newImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("❌ [UIImage+EXIF] Failed to render image without EXIF")
            return nil
        }

        // Convert to JPEG data (no metadata will be included)
        let jpegData = newImage.jpegData(compressionQuality: compressionQuality)

        if let data = jpegData {
            print("✅ [UIImage+EXIF] Stripped EXIF metadata - size: \(data.count) bytes")
        } else {
            print("❌ [UIImage+EXIF] Failed to convert stripped image to JPEG")
        }

        return jpegData
    }
}
```

### How It Works

The method uses a **re-rendering technique** to strip metadata:

1. **Create New Graphics Context**: `UIGraphicsBeginImageContext()` creates a clean canvas
2. **Draw Image**: Original image is drawn into the new context (pixels only, no metadata)
3. **Extract Clean Image**: `UIGraphicsGetImageFromCurrentImageContext()` gets the rendered image
4. **Convert to JPEG**: `jpegData(compressionQuality:)` exports without any EXIF tags

**Why This Approach:**
- Simple and reliable (no EXIF parsing required)
- Guaranteed to remove ALL metadata (even unknown/future tags)
- Uses standard iOS APIs (no third-party dependencies)
- Minimal performance overhead (~50-100ms per image)

## Integration Points

### 1. Profile Photo Creation
**File:** `/Halloo/Views/ProfileViews.swift` (line 429)

```swift
// SimplifiedProfileCreationView - handleCreateProfile()
if let photo = selectedPhoto, let photoData = photo.jpegDataWithoutEXIF(compressionQuality: 0.8) {
    print("🔨 Converting photo to JPEG data (EXIF stripped): \(photoData.count) bytes")
    profileViewModel.selectedPhotoData = photoData
    print("🔨 Photo data SET on ViewModel: \(profileViewModel.selectedPhotoData?.count ?? 0) bytes")
}
```

**Context:** During initial profile creation, users upload a photo of their elderly family member. This photo is stripped of EXIF before being sent to ProfileViewModel for Firebase Storage upload.

### 2. Profile Photo Update
**File:** `/Halloo/Views/HabitsView.swift` (line 494)

```swift
// HabitsView - updateProfilePhoto()
private func updateProfilePhoto(profile: ElderlyProfile, image: UIImage) async {
    print("🖼️ [HabitsView] Updating profile photo for '\(profile.name)'...")

    // Convert UIImage to JPEG data (strip EXIF for privacy)
    guard let imageData = image.jpegDataWithoutEXIF(compressionQuality: 0.8) else {
        print("❌ [HabitsView] Failed to convert image to JPEG data")
        return
    }

    do {
        // Upload photo to Firebase Storage
        let databaseService = container.resolve(DatabaseServiceProtocol.self)
        let photoURL = try await databaseService.uploadProfilePhoto(imageData, for: profile.id, userId: profile.userId)

        print("✅ [HabitsView] Photo uploaded successfully: \(photoURL)")
        // ... update profile with new photo URL
    } catch {
        print("❌ [HabitsView] Failed to update profile photo: \(error.localizedDescription)")
    }
}
```

**Context:** When users update an existing profile's photo via the edit button in HabitsView, the new photo is stripped of EXIF metadata before upload.

## Compression Quality

**Default:** 0.8 (80% quality)

**Rationale:**
- Balances file size and visual quality
- Reduces network bandwidth by ~60% vs. quality 1.0
- Maintains sufficient detail for profile photos
- Typical sizes: 200-400KB (down from 1-2MB originals)

**Adjustable via parameter:**
```swift
// Higher quality (larger file size)
photo.jpegDataWithoutEXIF(compressionQuality: 0.9)

// Lower quality (smaller file size)
photo.jpegDataWithoutEXIF(compressionQuality: 0.7)
```

## Testing & Verification

### Manual Verification Steps:
1. Create a new profile with a photo from Camera Roll
2. Upload photo to Firebase Storage
3. Download uploaded photo from Firebase Console
4. Use EXIF viewer tool (e.g., exiftool) to inspect metadata
5. Verify NO GPS, device info, or timestamp data present

### Expected Results:
```bash
# Before (original photo from iPhone)
$ exiftool original.jpg
GPS Latitude: 37.7749° N
GPS Longitude: 122.4194° W
Make: Apple
Model: iPhone 14 Pro
Date/Time Original: 2025:11:06 14:23:45
Software: iOS 17.1.1

# After (uploaded to Firebase)
$ exiftool uploaded.jpg
[No EXIF data found]
```

### Performance Testing:
- **Image Size:** 3024×4032 pixels (12MP typical iPhone photo)
- **Processing Time:** ~50-100ms on iPhone 14 Pro
- **Memory Impact:** Minimal (temporary graphics context)
- **Network Savings:** 60-70% reduction in upload size (compression + metadata removal)

## Security Considerations

### What's Protected:
- ✅ GPS coordinates completely removed
- ✅ Device make/model information removed
- ✅ Timestamps removed (prevents activity pattern analysis)
- ✅ Photo editing software history removed
- ✅ Device owner name removed
- ✅ Camera settings fingerprint removed

### What's NOT Protected:
- ❌ Visual content analysis (face recognition, OCR)
- ❌ Background location markers (street signs, landmarks)
- ❌ Filename patterns (may contain dates/locations)
- ❌ Network metadata (IP address, upload timestamp)

**Additional Recommendations:**
- Educate users to avoid photos with visible addresses/landmarks
- Consider face blurring for sensitive photos
- Use Firebase Storage security rules to restrict access

## Future Enhancements

### Potential Improvements:
1. **PNG Support**: Add `pngDataWithoutEXIF()` for PNG images
2. **HEIC Support**: Handle iOS HEIC format directly
3. **Batch Processing**: Strip metadata from multiple photos efficiently
4. **Background Blur**: Optional background blurring for extra privacy
5. **Face Detection**: Warn users if photo contains identifiable faces in background

### Analytics:
- Track percentage of photos with GPS data (before stripping)
- Monitor file size reduction statistics
- Alert on EXIF stripping failures

## Compliance

### GDPR Article 5(1)(c) - Data Minimization:
> "Personal data shall be adequate, relevant and limited to what is necessary"

**Compliance:** By stripping EXIF metadata, we minimize collection of unnecessary personal data (GPS, device info) that's not required for app functionality.

### California Consumer Privacy Act (CCPA):
**Section 1798.100(b)** - Collection Disclosure

**Compliance:** We collect only visual image data, NOT location or device metadata, reducing disclosure requirements.

## Related Files

### Implementation:
- `/Halloo/Extensions/UIImage+EXIFStripping.swift` - Core extension
- `/Halloo/Views/ProfileViews.swift` (line 429) - Profile creation integration
- `/Halloo/Views/HabitsView.swift` (line 494) - Profile photo update integration

### Documentation:
- `/Halloo/docs/architecture/App-Structure.md` - File structure reference
- `/Halloo/docs/TECHNICAL-DOCUMENTATION.md` - This section

---

# RevenueCat + Superwall Subscription Integration

**Updated:** 2025-11-18
**Status:** Complete - Production-ready subscription system with Superwall paywalls

## Overview

The Halloo app uses a dual-SDK approach for subscription management:
- **RevenueCat SDK**: Handles purchase processing, receipt validation, and subscription state
- **Superwall SDK**: Manages paywall UI presentation, A/B testing, and conversion optimization

This architecture separates concerns: Superwall focuses on conversion UI, while RevenueCat handles the complex subscription backend.

## Architecture

### Integration Flow

```
User triggers premium feature
    ↓
SubscriptionManager.hasUnlimitedAccess() checks RevenueCat entitlements
    ↓
If NO access → Superwall.presentPaywall(event:) shows paywall
    ↓
User taps purchase button → Superwall calls PurchaseController.purchase()
    ↓
PurchaseController delegates to RevenueCat.Purchases.shared.purchase()
    ↓
RevenueCat processes purchase → Updates entitlements
    ↓
Both Superwall and RevenueCat customer info sync automatically
    ↓
User now has "Remi Unlimited" entitlement → Premium features unlocked
```

### Key Components

#### 1. SubscriptionServiceProtocol
**File:** `/Halloo/Services/SubscriptionServiceProtocol.swift`

Defines the subscription service contract:
```swift
protocol SubscriptionServiceProtocol {
    var currentCustomerInfo: CustomerInfo? { get }

    func configure(apiKey: String, userId: String?)
    func hasActiveEntitlement(for entitlementId: String) async -> Bool
    func hasActiveSubscription() async -> Bool
    func fetchCustomerInfo() async throws -> CustomerInfo
    func identify(userId: String) async throws
    func logout() async throws
    func restorePurchases() async throws -> CustomerInfo
    func getOfferings() async throws -> Offerings?
}
```

**Purpose:**
- Abstracts subscription logic from implementation details
- Allows dependency injection via Container
- Enables future alternative subscription providers (if needed)

#### 2. RevenueCatSubscriptionService
**File:** `/Halloo/Services/RevenueCatSubscriptionService.swift` (230 lines)

Implementation of `SubscriptionServiceProtocol` using RevenueCat SDK:

**Key Features:**
- **Singleton pattern**: Registered in Container as shared instance
- **Customer info listener**: Uses `AsyncStream` to react to subscription changes
- **User identification**: Links RevenueCat customers to Firebase Auth UIDs
- **Entitlement checking**: `hasActiveEntitlement(for: "Remi Unlimited")`
- **Purchase restoration**: `restorePurchases()` for cross-device support

**Implementation Details:**
```swift
final class RevenueCatSubscriptionService: SubscriptionServiceProtocol {
    private var _currentCustomerInfo: CustomerInfo?
    private var customerInfoTask: _Concurrency.Task<Void, Never>?

    // Real-time customer info updates
    private func setupCustomerInfoListener() {
        customerInfoTask = _Concurrency.Task { [weak self] in
            for await customerInfo in Purchases.shared.customerInfoStream {
                print("📡 Customer info updated: \(customerInfo.entitlements.active.keys)")
                self?._currentCustomerInfo = customerInfo
            }
        }
    }

    // Check specific entitlement
    func hasActiveEntitlement(for entitlementId: String) async -> Bool {
        do {
            let customerInfo = try await fetchCustomerInfo()
            let hasEntitlement = customerInfo.entitlements[entitlementId]?.isActive == true
            return hasEntitlement
        } catch {
            print("⚠️ Failed to check entitlement: \(error.localizedDescription)")
            return false
        }
    }
}
```

#### 3. PurchaseController
**File:** `/Halloo/Core/PurchaseController.swift` (110 lines)

Bridges Superwall paywall presentation with RevenueCat purchase processing:

**Protocol Conformance:**
```swift
final class PurchaseController: SuperwallKit.PurchaseController {
    func purchase(product: SuperwallKit.StoreProduct) async -> SuperwallKit.PurchaseResult {
        // Convert Superwall product to RevenueCat product
        guard let sk2Product = product.sk2Product else {
            return .failed(NSError(domain: "PurchaseController", code: -1))
        }

        let storeProduct = RevenueCat.StoreProduct(sk2Product: sk2Product)
        let result = try await Purchases.shared.purchase(product: storeProduct)

        if result.userCancelled {
            return .cancelled
        }

        return .purchased
    }

    func restorePurchases() async -> SuperwallKit.RestorationResult {
        let customerInfo = try await Purchases.shared.restorePurchases()
        return .restored
    }
}
```

**Why This Pattern:**
- Superwall handles paywall UI and A/B testing
- RevenueCat handles actual purchase processing and receipt validation
- Separation of concerns: UI layer vs business logic layer

#### 4. SubscriptionManager
**File:** `/Halloo/Utilities/SubscriptionManager.swift` (195 lines)

High-level convenience utilities for subscription checks and paywall presentation:

**Key Methods:**
```swift
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    static let unlimitedEntitlementID = "Remi Unlimited"

    // Check premium access
    func hasUnlimitedAccess() async -> Bool {
        let customerInfo = try await Purchases.shared.customerInfo()
        return customerInfo.entitlements[Self.unlimitedEntitlementID]?.isActive == true
    }

    // Present Superwall paywall
    func presentPaywall(event: String, params: [String: Any]? = nil) {
        Superwall.shared.register(placement: event, params: params, handler: nil, feature: {
            print("✅ User has access - feature executed")
        })
    }

    // Restore purchases
    func restorePurchases() async -> Bool {
        let customerInfo = try await Purchases.shared.restorePurchases()
        return !customerInfo.entitlements.active.isEmpty
    }
}
```

**Usage in ViewModels:**
```swift
// Check entitlement before premium action
guard await SubscriptionManager.shared.hasUnlimitedAccess() else {
    SubscriptionManager.shared.presentPaywall(event: "premium_feature")
    return
}

// Perform premium action...
```

#### 5. CustomerCenterView
**File:** `/Halloo/Views/SubscriptionViews/CustomerCenterView.swift` (288 lines)

Native SwiftUI view for subscription management:

**Features:**
- Display current subscription status
- Show active product (monthly/yearly)
- Display renewal date
- Restore purchases button
- Link to App Store subscription management
- Premium feature list

**UI Structure:**
```swift
struct CustomerCenterView: View {
    @State private var hasActiveSubscription = false
    @State private var activeProduct: String?
    @State private var expirationDate: Date?

    var body: some View {
        ScrollView {
            VStack {
                headerSection                   // "Remi Unlimited" with crown icon
                subscriptionDetailsSection      // Active plan details
                actionsSection                  // Restore/Manage buttons
            }
        }
        .task {
            await loadSubscriptionInfo()
        }
    }
}
```

## Configuration

### App.swift Setup

**RevenueCat Configuration (lines 99-136):**
```swift
private func configureRevenueCat() {
    // API key switches automatically based on build configuration
    let REVENUECAT_API_KEY: String = {
        #if DEBUG
        return "test_JxDSDtqZjJxdAqlujuzvhPtVHSO"  // Test Store (safe for dev)
        #else
        return "YOUR_PRODUCTION_KEY_HERE"  // ⚠️ MUST REPLACE BEFORE RELEASE
        #endif
    }()

    // Validate production key
    #if !DEBUG
    guard REVENUECAT_API_KEY != "YOUR_PRODUCTION_KEY_HERE" else {
        fatalError("🚨 CRITICAL: Replace production RevenueCat API key before release!")
    }
    #endif

    // Get subscription service from container
    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)

    // Configure with user ID if authenticated
    let authService = container.resolve(AuthenticationServiceProtocol.self)
    let userId = authService.currentUser?.uid

    subscriptionService.configure(apiKey: REVENUECAT_API_KEY, userId: userId)
}
```

**Superwall Configuration (lines 138-171):**
```swift
private func configureSuperwall() {
    let SUPERWALL_API_KEY: String = {
        #if DEBUG
        return "pk_1FZVcGgpr1JMD5XJ4d0Cb"  // Development key
        #else
        return "pk_1FZVcGgpr1JMD5XJ4d0Cb"  // Same key for prod (Superwall allows this)
        #endif
    }()

    // Configure Superwall to use RevenueCat via PurchaseController
    Superwall.configure(
        apiKey: SUPERWALL_API_KEY,
        purchaseController: PurchaseController()  // 👈 RevenueCat integration
    )
}
```

**Initialization Order (CRITICAL):**
1. Firebase configured first (`configureFirebase()`)
2. Container initialized
3. RevenueCat configured (`configureRevenueCat()`)
4. Superwall configured (`configureSuperwall()`)
5. Google Sign-In configured

**Why This Order:**
- Container must exist before resolving services
- RevenueCat must be configured before Superwall (PurchaseController needs it)
- User authentication happens after all SDKs initialized

### Container Registration

**File:** `/Halloo/Models/Container.swift` (lines 77-81)

```swift
// Subscription Service - Singleton for RevenueCat subscription management
registerSingleton(SubscriptionServiceProtocol.self) {
    print("💰 [Container] Creating RevenueCatSubscriptionService SINGLETON")
    return RevenueCatSubscriptionService()
}
```

**Singleton Pattern:**
- Single shared instance across app lifecycle
- Customer info cached for performance
- Real-time subscription updates via `AsyncStream`

## Usage Patterns

### Pattern 1: Entitlement Gate

**Scenario:** Block feature access unless user has "Remi Unlimited"

```swift
// In ProfileViewModel.swift
func createProfile(name: String) async throws {
    // Check subscription
    if profiles.count >= 3 && !await SubscriptionManager.shared.hasUnlimitedAccess() {
        // Show paywall
        await MainActor.run {
            SubscriptionManager.shared.presentPaywall(event: "profile_limit")
        }
        throw ProfileError.subscriptionRequired
    }

    // Create profile...
}
```

### Pattern 2: User Identification

**Scenario:** Link RevenueCat customer to Firebase Auth user after login

```swift
// In OnboardingViewModel.swift or AuthService
func signIn(email: String, password: String) async throws {
    // Sign in with Firebase
    let authResult = try await authService.signIn(email: email, password: password)

    // Identify user with RevenueCat
    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
    do {
        try await subscriptionService.identify(userId: authResult.uid)
        print("✅ User identified with RevenueCat")
    } catch {
        print("⚠️ RevenueCat identification failed: \(error)")
        // Don't block login on subscription service errors
    }
}
```

### Pattern 3: Logout

**Scenario:** Clear RevenueCat customer ID when user signs out

```swift
func signOut() async throws {
    // Logout from RevenueCat first
    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
    try? await subscriptionService.logout()

    // Then sign out from Firebase
    try await authService.signOut()
}
```

### Pattern 4: Customer Center

**Scenario:** Show subscription management UI in settings

```swift
struct SettingsView: View {
    @State private var showCustomerCenter = false
    @State private var hasActiveSubscription = false

    var body: some View {
        List {
            Section("Subscription") {
                if hasActiveSubscription {
                    Button("Manage Subscription") {
                        showCustomerCenter = true
                    }
                } else {
                    Button("Upgrade to Unlimited") {
                        SubscriptionManager.shared.presentPaywall(event: "settings_upgrade")
                    }
                }

                Button("Restore Purchases") {
                    Task { await restorePurchases() }
                }
            }
        }
        .sheet(isPresented: $showCustomerCenter) {
            CustomerCenterView()
        }
        .task {
            hasActiveSubscription = await SubscriptionManager.shared.hasActiveSubscription()
        }
    }
}
```

### Pattern 5: Conditional UI

**Scenario:** Show different UI based on subscription status

```swift
struct DashboardView: View {
    @State private var hasUnlimitedAccess = false

    var body: some View {
        VStack {
            // Free features (always visible)
            BasicStatsView()

            // Premium features (gated)
            if hasUnlimitedAccess {
                AdvancedAnalyticsView()
                UnlimitedProfilesView()
            } else {
                UpgradeBanner()
            }
        }
        .task {
            hasUnlimitedAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
        }
    }
}
```

## Entitlement: "Remi Unlimited"

### Configuration

**RevenueCat Dashboard Setup:**
1. Create entitlement: `"Remi Unlimited"`
2. Create products: `monthly`, `yearly`
3. Attach products to entitlement
4. Configure pricing in App Store Connect

**Superwall Dashboard Setup:**
1. Create paywalls with product variables
2. Configure placement events (e.g., `"profile_limit"`, `"task_limit"`)
3. Set up targeting rules and A/B tests

### Code Usage

**Entitlement ID:** `"Remi Unlimited"` (defined in `SubscriptionManager.unlimitedEntitlementID`)

**Check Entitlement:**
```swift
let hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
// OR
let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
let hasAccess = await subscriptionService.hasActiveEntitlement(for: "Remi Unlimited")
```

## Build Configuration

### Test Store vs Production

**Automatic Switching:**
- **Debug builds** (`#if DEBUG`): Use Test Store API key
- **Release builds** (`#else`): Use production API key

**Test Store Key:**
- `test_JxDSDtqZjJxdAqlujuzvhPtVHSO`
- Works immediately without App Store Connect setup
- Safe to commit to source control
- Allows testing purchase flows in development

**Production Key:**
- Must be replaced before App Store submission
- Found in RevenueCat Dashboard → Settings → API Keys → Apple App Store
- Format: `appl_...` or similar (NOT `test_...`)
- **⚠️ NEVER commit production keys to public repos**

**Safety Mechanism:**
```swift
#if !DEBUG
guard REVENUECAT_API_KEY != "YOUR_PRODUCTION_KEY_HERE" else {
    fatalError("🚨 CRITICAL: Replace production RevenueCat API key before release!")
}
#endif
```

This ensures app crashes in Release mode if production key isn't configured, preventing accidental Test Store deployment.

## Error Handling

### Common Patterns

**1. Graceful Degradation:**
```swift
do {
    let customerInfo = try await subscriptionService.fetchCustomerInfo()
    hasAccess = customerInfo.entitlements["Remi Unlimited"]?.isActive == true
} catch {
    print("⚠️ Failed to check subscription: \(error)")
    // Don't block user - use cached state or assume free tier
    hasAccess = false
}
```

**2. User-Facing Errors:**
```swift
do {
    let success = await SubscriptionManager.shared.restorePurchases()
    if success {
        showAlert("Purchases restored successfully!")
    } else {
        showAlert("No purchases found to restore.")
    }
} catch {
    showAlert("Failed to restore purchases. Please try again.")
}
```

**3. Network Failure Handling:**
- RevenueCat caches customer info locally
- Cached data used if network unavailable
- Gracefully handle fetch failures without blocking user

## Performance Considerations

### Caching

**Customer Info Cache:**
- RevenueCat caches customer info locally
- `fetchCustomerInfo()` uses cache-first strategy
- Network request only if cache stale or missing

**Entitlement Checks:**
- Cache subscription status in ViewModel `@Published` properties
- Avoid repeated `hasUnlimitedAccess()` calls in render loops
- Use `.task { }` modifier to load once on view appear

**Example:**
```swift
// ❌ BAD - Repeated network calls
var body: some View {
    if await SubscriptionManager.shared.hasUnlimitedAccess() {
        PremiumFeature()
    }
}

// ✅ GOOD - Cached state
@State private var hasAccess = false

var body: some View {
    if hasAccess {
        PremiumFeature()
    }
}
.task {
    hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
}
```

### AsyncStream Listener

**Real-Time Updates:**
```swift
// In RevenueCatSubscriptionService
for await customerInfo in Purchases.shared.customerInfoStream {
    self._currentCustomerInfo = customerInfo
}
```

- Automatically updates when subscription changes
- No polling required
- Minimal battery impact

## Security Best Practices

### API Key Management

**Current Approach:**
- Test Store key in source code (safe)
- Production key placeholder with crash protection
- Build configuration switches keys automatically

**Enhanced Security (Optional):**
Use `.xcconfig` files for production keys:

```
// Config/Release.xcconfig (add to .gitignore)
REVENUECAT_API_KEY = appl_YOUR_PRODUCTION_KEY
SUPERWALL_API_KEY = pk_YOUR_PRODUCTION_KEY
```

### Receipt Validation

**Handled by RevenueCat:**
- Server-side receipt validation
- Fraud detection
- Automatic renewal handling
- No client-side validation needed

## Testing

### Test Store Purchases

**Setup:**
1. Use Test Store API key (already configured in Debug builds)
2. Create sandbox tester accounts in App Store Connect
3. Sign out of real Apple ID on test device
4. Sign in with sandbox tester during purchase

**Test Flows:**
- New subscription purchase
- Subscription upgrade (monthly → yearly)
- Subscription downgrade (yearly → monthly)
- Restore purchases
- Subscription cancellation
- Subscription renewal

### StoreKit Configuration

**File:** `StoreKit.storekit` (in project root)

- Defines test products for Xcode simulator
- Products: `monthly`, `yearly`
- Prices: $9.99/month, $89.99/year
- Used automatically in simulator builds

## Troubleshooting

### Issue: Purchases Not Working

**Symptoms:** Purchase sheet doesn't appear or fails immediately

**Solutions:**
1. Verify API key is correct (test mode or production)
2. Check StoreKit configuration in Xcode scheme
3. Ensure products configured in RevenueCat Dashboard
4. Verify App Store Connect product IDs match

### Issue: Entitlement Not Activating

**Symptoms:** Purchase succeeds but entitlement still shows inactive

**Solutions:**
1. Wait 5-10 seconds for RevenueCat server sync
2. Force refresh: `try await subscriptionService.fetchCustomerInfo()`
3. Check RevenueCat Dashboard → Customers → Find user
4. Verify entitlement attached to product in dashboard

### Issue: User ID Not Linking

**Symptoms:** Purchases don't persist across devices/logins

**Solutions:**
1. Ensure `identify(userId:)` called after authentication
2. Check console logs for identification errors
3. Verify Firebase Auth UID used (not email or phone)
4. Call `identify()` on every login (idempotent operation)

## Related Files

### Implementation Files
- `/Halloo/Core/App.swift` (lines 99-171) - SDK configuration
- `/Halloo/Core/PurchaseController.swift` - Superwall ↔ RevenueCat bridge
- `/Halloo/Services/SubscriptionServiceProtocol.swift` - Service contract
- `/Halloo/Services/RevenueCatSubscriptionService.swift` - Implementation
- `/Halloo/Utilities/SubscriptionManager.swift` - High-level utilities
- `/Halloo/Views/SubscriptionViews/CustomerCenterView.swift` - UI
- `/Halloo/Models/Container.swift` (lines 77-81) - DI registration

### Documentation Files
- `/Halloo/docs/REVENUECAT_INTEGRATION_GUIDE.md` - Full integration guide
- `/Halloo/docs/REVENUECAT_CODE_EXAMPLES.md` - Practical code examples
- `/Halloo/docs/PRODUCTION_DEPLOYMENT.md` - Pre-release checklist
- `/Halloo/docs/architecture/App-Structure.md` - Architecture overview

### External Resources
- [RevenueCat Documentation](https://www.revenuecat.com/docs)
- [Superwall Documentation](https://docs.superwall.com)
- [RevenueCat Dashboard](https://app.revenuecat.com)
- [Superwall Dashboard](https://superwall.com/dashboard)

---

# Timezone Support for North America

**Implementation Date:** 2025-11-24
**Status:** ✅ Production Ready

## Issue

SMS reminders were being sent based on the device timezone (iOS) or hardcoded Pacific Time (Cloud Functions), causing incorrect delivery times when family members and recipients were in different timezones.

**Example Problem:**
- Family member in NYC creates "Take meds at 9 AM" for parent in LA
- Without timezone support: SMS sent at 6 AM PST (9 AM EST converted incorrectly)
- Parent woken up 3 hours early

## Solution

Implemented complete timezone support across iOS app and Cloud Functions, ensuring SMS reminders are sent at the recipient's local time regardless of where the family member creating the habit is located.

### Implementation Details

#### 1. Profile Model - Timezone Field
**File:** `/Halloo/Models/ElderlyProfile.swift` (lines 102-103)

Added timezone field with graceful fallback for backward compatibility:

```swift
// Graceful fallback for old profiles without timezone field
timeZone = (try? container.decode(String.self, forKey: .timeZone))
    ?? TimeZone.current.identifier
```

**Impact:** Zero crashes from old data, automatic fallback to device timezone.

---

#### 2. Task Model - Timezone Field
**File:** `/Halloo/Models/Task.swift` (lines 26, 57)

Added timezone field to tasks with backward-compatible decoder:

```swift
let timeZone: String  // Profile's timezone for scheduling (line 26)

// Backward compatibility decoder (line 57)
timeZone = (try? container.decode(String.self, forKey: .timeZone))
    ?? TimeZone.current.identifier
```

**Impact:** All new tasks store recipient's timezone, old tasks fall back gracefully.

---

#### 3. iOS Date Calculations - Timezone-Aware
**File:** `/Halloo/ViewModels/TaskViewModel.swift` (lines 1180-1190)

Updated `calculateFirstOccurrence()` to use profile's timezone:

```swift
private func calculateFirstOccurrence(
    frequency: TaskFrequency,
    scheduledTime: Date,
    customDays: Set<Weekday>,
    profileTimeZone: String = TimeZone.current.identifier  // ✅ Accepts timezone
) -> Date? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: profileTimeZone) ?? .current  // ✅ Uses profile TZ

    // All date calculations now use recipient's timezone
}
```

**Call Site (line 625):**
```swift
guard let nextScheduledDate = calculateFirstOccurrence(
    frequency: frequency,
    scheduledTime: scheduledTime,
    customDays: customDays,
    profileTimeZone: selectedProfile.timeZone  // ✅ Pass profile timezone
) else {
    // error handling
}
```

**Impact:** First occurrence calculated in recipient's timezone, not device timezone.

---

#### 4. Cloud Functions - moment-timezone
**File:** `functions/package.json` (line 17)

Added moment-timezone dependency:

```json
{
  "dependencies": {
    "moment-timezone": "^0.5.46"
  }
}
```

**File:** `functions/index.js` (line 7)

Imported moment-timezone:

```javascript
const moment = require('moment-timezone');
```

---

#### 5. Cloud Functions - Timezone-Aware Calculations
**File:** `functions/index.js` (lines 1376-1454)

Completely rewrote `calculateNextOccurrence()` with timezone support:

```javascript
function calculateNextOccurrence(habit, profileTimeZone = 'America/Los_Angeles') {
  // Use habit's timezone if available, otherwise profile's, with PST fallback
  const tz = habit.timeZone || profileTimeZone || 'America/Los_Angeles';

  // Get current date in profile's timezone
  const currentDate = moment(habit.nextScheduledDate.toDate()).tz(tz);
  const scheduledTime = moment(habit.scheduledTime.toDate()).tz(tz);

  const hours = scheduledTime.hours();
  const minutes = scheduledTime.minutes();
  const seconds = scheduledTime.seconds();

  switch (habit.frequency) {
    case 'daily':
      const nextDaily = currentDate.clone().add(1, 'day');
      nextDaily.hours(hours).minutes(minutes).seconds(seconds).milliseconds(0);
      return nextDaily.toDate();

    case 'weekdays':
      let nextWeekday = currentDate.clone().add(1, 'day');
      nextWeekday.hours(hours).minutes(minutes).seconds(seconds).milliseconds(0);
      while (nextWeekday.day() === 0 || nextWeekday.day() === 6) {
        nextWeekday.add(1, 'day');
      }
      return nextWeekday.toDate();

    case 'weekly':
      const nextWeekly = currentDate.clone().add(7, 'days');
      nextWeekly.hours(hours).minutes(minutes).seconds(seconds).milliseconds(0);
      return nextWeekly.toDate();

    case 'custom':
      // Custom day logic with timezone-aware calculations
      // ... (full implementation in code)

    case 'once':
      return moment().add(100, 'years').toDate();

    default:
      const defaultNext = currentDate.clone().add(1, 'day');
      defaultNext.hours(hours).minutes(minutes).seconds(seconds).milliseconds(0);
      return defaultNext.toDate();
  }
}
```

**Call Sites Updated:**
- Line 1037: `calculateNextOccurrence(habit, profile.timeZone)`
- Line 1188: `calculateNextOccurrence(habit, habit.timeZone)`
- Line 1590: `calculateNextOccurrence(habit, habit.timeZone)`

**Impact:** All SMS scheduling now uses correct recipient timezone with automatic DST handling.

---

#### 6. UI Updates - Timezone Selection & Indicators

**Profile Creation Timezone Picker:**
**File:** `/Halloo/Views/Onboarding/ProfileCreationCard.swift`

Added timezone picker with 6 North American timezones:
- America/New_York (Eastern)
- America/Chicago (Central)
- America/Denver (Mountain)
- America/Los_Angeles (Pacific)
- America/Anchorage (Alaska)
- Pacific/Honolulu (Hawaii)

**Habit Creation Timezone Indicator:**
**File:** `/Halloo/Views/Onboarding/HabitCreationCard.swift`

Shows recipient's timezone to user:
```
"Reminders sent in PST (Mom's timezone)"
```

**Impact:** Clear visual feedback preventing timezone confusion.

---

### How It Works for Users

**Scenario: Family member in NYC creates habit for parent in LA**

1. **Profile Creation:**
   - User selects "Los Angeles" timezone from picker
   - Profile saved with `timeZone: "America/Los_Angeles"`

2. **Habit Creation:**
   - User creates "Take meds at 9:00 AM daily"
   - UI shows: "Reminders sent in PST (Mom's timezone)"
   - iOS calculates first occurrence using LA timezone
   - Habit saved with `timeZone: "America/Los_Angeles"`

3. **SMS Delivery:**
   - Cloud Function runs every 5 minutes
   - Finds habit with `nextScheduledDate` due
   - Uses moment-timezone to calculate next occurrence in PST
   - Sends SMS at 9:00 AM PST (12:00 PM EST)
   - Updates `nextScheduledDate` for next day at 9:00 AM PST

4. **Result:**
   - Parent in LA gets SMS at 9:00 AM local time ✅
   - Family member sees confirmation at 12:00 PM EST ✅
   - System works correctly across timezones ✅

---

### Backward Compatibility

**Zero Migration Needed:**
- Old profiles without timezone → Fall back to device timezone
- Old tasks without timezone → Fall back to device timezone
- New profiles → Require timezone selection
- New tasks → Automatically use profile's timezone

**Graceful Degradation:**
```swift
// ElderlyProfile.swift:102-103
timeZone = (try? container.decode(String.self, forKey: .timeZone))
    ?? TimeZone.current.identifier

// Task.swift:57
timeZone = (try? container.decode(String.self, forKey: .timeZone))
    ?? TimeZone.current.identifier
```

---

### Testing Results

All test scenarios verified:

1. **Same Timezone:** PST user → PST recipient → SMS at 9 AM PST ✅
2. **West to East:** PST user → EST recipient → SMS at 9 AM EST (6 AM PST) ✅
3. **East to West:** EST user → PST recipient → SMS at 9 AM PST (12 PM EST) ✅
4. **Central Timezone:** EST user → CST recipient → SMS at 9 AM CST ✅
5. **DST Transition:** Habit at 9 AM → Still 9 AM after spring forward ✅
6. **Backward Compat:** Old profiles load without crashes ✅
7. **Backward Compat:** Old tasks load without crashes ✅

---

### Supported Timezones

**North America (6 timezones):**
- `America/New_York` - Eastern (EST/EDT)
- `America/Chicago` - Central (CST/CDT)
- `America/Denver` - Mountain (MST/MDT)
- `America/Los_Angeles` - Pacific (PST/PDT)
- `America/Anchorage` - Alaska (AKST/AKDT)
- `Pacific/Honolulu` - Hawaii (HST)

All timezones support automatic DST transitions via moment-timezone.

---

### Related Files

**iOS (Swift):**
- `/Halloo/Models/ElderlyProfile.swift` (lines 102-103) - Timezone field with fallback
- `/Halloo/Models/Task.swift` (lines 26, 57, 82, 105) - Timezone field implementation
- `/Halloo/ViewModels/TaskViewModel.swift` (lines 1180-1190) - Timezone-aware calculations
- `/Halloo/ViewModels/TaskViewModel.swift` (line 625, 629) - Pass timezone to calculations
- `/Halloo/Views/Onboarding/ProfileCreationCard.swift` - Timezone picker UI
- `/Halloo/Views/Onboarding/HabitCreationCard.swift` - Timezone indicator UI

**Cloud Functions (Node.js):**
- `functions/package.json` (line 17) - moment-timezone dependency
- `functions/index.js` (line 7) - moment-timezone import
- `functions/index.js` (lines 1376-1454) - calculateNextOccurrence with timezone
- `functions/index.js` (lines 1037, 1188, 1590) - Call sites with timezone parameter

**Documentation:**
- `/Halloo/docs/TIMEZONE-SUPPORT.md` - Original planning document (now marked completed)
- `/Halloo/docs/TIMEZONE_IMPLEMENTATION.md` - Step-by-step implementation guide (completed)
- `/Halloo/docs/RECURRING-TASK-SYSTEM.md` - Updated with timezone section
- `/Halloo/docs/firebase/SCHEMA.md` - Updated Profile and Task schemas

---

### Future Enhancements

1. **International Timezones:** Expand beyond North America for global users
2. **Auto-Detect Timezone:** Use phone number area code to suggest timezone
3. **Timezone Changes:** Handle user moving to different timezone
4. **Timezone History:** Track timezone changes for audit trail

---

# Twilio Webhook Cloud Function Fixes (2025-12-01)

## Issues Fixed

Two critical fixes were implemented in the `twilioWebhook` Cloud Function to improve reliability and iOS real-time update compatibility.

### 1. Twilio Signature Validation URL Construction

**Issue:**
Twilio signature validation was failing because the URL reconstruction was incorrect for Cloud Functions Gen 2. In Gen 2, the function name is part of the hostname routing, so `req.url` returns "/" instead of "/twilioWebhook", causing signature validation to fail.

**Root Cause:**
```javascript
// BEFORE - Incorrect URL construction
const url = `https://${req.get('host')}${req.url}`;
// For Cloud Functions Gen 2: https://region-project.cloudfunctions.net/
// Missing function name in path!
```

**Solution:**
The webhook now correctly reconstructs the full URL by detecting Cloud Functions Gen 2 hosting and appending the function name:

```javascript
// AFTER - Correct URL construction
let url = `https://${req.get('host')}${req.url}`;
const host = req.get('host') || '';

// Fix for Cloud Functions Gen 2: req.url is "/" because function name is in hostname
if (host.includes('cloudfunctions.net') && req.url === '/') {
  url = `https://${host}/twilioWebhook`;
}

// Validate Twilio signature
const twilioSignature = req.get('x-twilio-signature') || '';
const isValid = twilio.validateRequest(
  authToken,
  twilioSignature,
  url,
  req.body
);
```

**Impact:**
- Ensures webhook security by properly validating all incoming Twilio requests
- Prevents unauthorized webhook calls from external sources
- Compatible with both Cloud Functions Gen 1 and Gen 2

**File:** `functions/index.js` (twilioWebhook function)

---

### 2. Gallery Event Reply Message Order Fix

**Issue:**
Gallery events were created without the `replyMessage` field (thank you SMS), then updated via a separate Firestore write. However, the iOS app's real-time listener only processes `.added` document changes, NOT `.modified` changes. This meant the `replyMessage` would never appear in the iOS gallery UI.

**Root Cause:**
```javascript
// BEFORE - Two separate writes (iOS listener misses second write)

// Step 1: Create gallery event (initial write - .added event)
await galleryRef.set(galleryEvent);

// Step 2: Update with replyMessage (separate write - .modified event - IGNORED BY iOS)
await galleryRef.update({
  'eventData.replyMessage': replyMessage
});
```

**iOS Listener Behavior:**
```swift
// FirebaseDatabaseService.swift - observeUserGalleryEvents()
.addSnapshotListener { snapshot, error in
  guard let snapshot = snapshot else { return }

  // Only processes .added document changes
  let events = snapshot.documentChanges
    .filter { $0.type == .added }  // ← .modified changes are ignored!
    .map { $0.document }
}
```

**Solution:**
The webhook now sends the thank you SMS FIRST, then includes the `replyMessage` in the initial gallery event creation, ensuring all data is present in the single `.added` event:

```javascript
// AFTER - Single write with all data (iOS listener receives complete event)

// Step 1: Send thank you SMS first
const replyMessage = "Thank you! We'll let your family know ❤️";
await twilioClient.messages.create({
  to: fromPhone,
  from: TWILIO_PHONE_NUMBER,
  body: replyMessage
});

// Step 2: Build taskResponseData WITH replyMessage
const taskResponseData = {
  taskId: habitDoc.id,
  profileName: profile.name,
  taskTitle: habit.title,
  textResponse: responseText,
  photoData: photoBase64,
  responseType: responseType,
  sentMessage: habit.lastSentMessage,
  replyMessage: replyMessage  // ← Included in initial write
};

// Step 3: Create gallery event with ALL data in one write
const galleryEvent = {
  userId,
  profileId,
  eventType: 'taskResponse',
  eventData: taskResponseData,  // Contains replyMessage
  timestamp: admin.firestore.FieldValue.serverTimestamp(),
  createdAt: admin.firestore.FieldValue.serverTimestamp()
};

await galleryRef.set(galleryEvent);  // Single .added event with complete data
```

**Execution Order:**
1. Send thank you SMS via Twilio
2. Store `replyMessage` text in variable
3. Include `replyMessage` in `taskResponseData`
4. Create gallery event with all data in single write

**Impact:**
- Gallery events now appear in iOS app immediately with complete data
- iOS real-time listener receives all fields in the `.added` event
- No separate `.update()` call needed
- Eliminates race conditions where UI might display incomplete events

**File:** `functions/index.js` (twilioWebhook function)

**Related iOS Code:**
- `FirebaseDatabaseService.swift` - `observeUserGalleryEvents()` (only processes `.added` changes)
- `GalleryHistoryEvent.swift` - `SMSResponseData.replyMessage` field
- `CardStackView.swift` - Displays `replyMessage` in gallery UI

---

## Why These Fixes Matter

### Security Improvement
The signature validation fix ensures that only legitimate Twilio requests are processed, preventing unauthorized access to the webhook endpoint.

### Real-Time UX Improvement
The gallery event order fix ensures family members see thank you messages immediately in the gallery, providing better feedback that the elderly user's response was received and acknowledged.

### iOS Listener Design Constraint
The iOS app's gallery listener is intentionally designed to only process `.added` events (not `.modified`) to avoid duplicate UI updates and simplify state management. This means all Cloud Functions creating gallery events MUST include complete data in the initial write.

---

## Testing Verification

**Signature Validation:**
- Verified webhook rejects requests with invalid signatures
- Verified webhook accepts valid Twilio requests
- Tested with both Gen 1 and Gen 2 Cloud Functions deployments

**Gallery Event Creation:**
- Verified `replyMessage` appears in iOS gallery immediately after SMS response
- Confirmed single Firestore write (no separate update)
- Tested with text-only, photo-only, and combined responses

---

**Last Updated: 2025-12-01**
