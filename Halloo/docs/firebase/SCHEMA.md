# 🔥 Firebase Schema Contract & Audit Report
**Project:** Halloo/Remi iOS App
**Date:** 2025-10-03
**Last Verified:** 2025-10-09
**Status:** ✅ **SCHEMA MIGRATION COMPLETE**

---

## 📋 Executive Summary

### Current Schema Status: ✅ **HIERARCHICAL ARCHITECTURE (Correct)**
The implementation successfully uses **nested subcollection architecture** as designed.

### Current Schema: ✅ **NESTED COLLECTIONS**
```
/users/{firebaseUID}                    ← Top-level document (Firebase Auth UID)
  /profiles/{profileId}                 ← Subcollection (parent/elderly profiles)
    /habits/{habitId}                   ← Subcollection (tasks under profile)
    /messages/{messageId}               ← Subcollection (SMS under profile)
  /gallery_events/{eventId}             ← Subcollection (gallery events under user)
```

### Migration Status: ✅ **COMPLETE**
All production code uses nested paths via `CollectionPath` enum in FirebaseDatabaseService.swift. Legacy flat paths removed from production code.

---

## 🏗️ SCHEMA CONTRACT (Target Architecture)

### 1. User Document (Top Level)
**Path:** `/users/{firebaseUID}`

**Document ID Rule:**
- ✅ **MUST** use Firebase Auth UID (from `Auth.auth().currentUser.uid`)
- ❌ **NEVER** use UUID or custom ID

**Structure:**
```json
{
  "id": "firebase-auth-uid-abc123",           // Firebase Auth UID
  "email": "user@example.com",
  "fullName": "John Doe",
  "phoneNumber": "+15551234567",
  "createdAt": "2025-10-03T12:00:00Z",
  "isOnboardingComplete": true,
  "subscriptionStatus": "active",
  "trialEndDate": "2025-11-03T12:00:00Z",
  "quizAnswers": {
    "q1": "answer1"
  },
  "profileCount": 2,                          // Auto-calculated
  "taskCount": 5,                             // Auto-calculated
  "lastSyncTimestamp": "2025-10-03T14:30:00Z"
}
```

**Field Requirements:**
- `id` → MUST equal document path `{firebaseUID}`
- `email` → Required, from Firebase Auth
- `fullName` → Required, from sign-in
- `phoneNumber` → Required for SMS fallback
- `createdAt` → Required, set on first document creation
- `profileCount` → Auto-updated when profiles added/removed
- `taskCount` → Auto-updated when tasks added/removed

---

### 2. Profile (Elderly/Parent) Subcollection
**Path:** `/users/{firebaseUID}/profiles/{profileId}`

**Document ID Rule:**
- ✅ **Option A (Recommended):** Use phone number as ID: `normalize(phoneNumber)` → `"+15551234567"`
- ✅ **Option B:** Use UUID.uuidString for uniqueness
- ❌ **NEVER** mix both strategies without documented rules

**Structure:**
```json
{
  "id": "+15551234567",                       // Normalized phone OR UUID
  "userId": "firebase-auth-uid-abc123",       // Parent user reference
  "name": "Grandma Rose",
  "phoneNumber": "+15551234567",
  "relationship": "Grandmother",
  "isEmergencyContact": false,
  "timeZone": "America/New_York",
  "notes": "Prefers morning calls",
  "photoURL": "https://storage.googleapis.com/...",
  "status": "confirmed",                      // pending, confirmed, inactive
  "createdAt": "2025-10-03T12:00:00Z",
  "lastActiveAt": "2025-10-03T14:00:00Z",
  "confirmedAt": "2025-10-03T12:15:00Z",
  "lastCompletionDate": "2025-10-03T13:00:00Z"
}
```

**Field Requirements:**
- `id` → MUST be consistent (phone number OR UUID, never random)
- `userId` → MUST match parent document path `{firebaseUID}`
- `phoneNumber` → Required, E.164 format (+1XXXXXXXXXX)
- `status` → Enum: `pendingConfirmation`, `confirmed`, `inactive`
- `createdAt` → Required
- `confirmedAt` → Set when SMS confirmation received

---

### 3. Habit (Task) Subcollection
**Path:** `/users/{firebaseUID}/profiles/{profileId}/habits/{habitId}`

**Document ID Rule:**
- ✅ Use UUID.uuidString (habits are unique per creation)
- ❌ **NEVER** use task title or date as ID (not unique)

**Structure:**
```json
{
  "id": "uuid-habit-123",
  "userId": "firebase-auth-uid-abc123",       // Redundant but useful for queries
  "profileId": "+15551234567",                // Parent profile reference
  "title": "Take Morning Medication",
  "description": "Blue pill with breakfast",
  "category": "medication",
  "frequency": "daily",
  "scheduledTime": "2025-10-03T09:00:00Z",
  "deadlineMinutes": 10,
  "requiresPhoto": true,
  "requiresText": false,
  "customDays": ["monday", "wednesday", "friday"],
  "startDate": "2025-10-03T00:00:00Z",
  "endDate": null,
  "status": "active",                         // active, paused, completed, archived, expired
  "notes": "With water",
  "createdAt": "2025-10-03T12:00:00Z",
  "lastModifiedAt": "2025-10-03T12:00:00Z",
  "lastUpdatedAt": "2025-10-03T12:00:00Z",
  "completionCount": 5,
  "lastCompletedAt": "2025-10-03T09:05:00Z",
  "nextScheduledDate": "2025-10-04T09:00:00Z",
  "lastSentMessage": "Hello Mom 🌞 A gentle reminder to Take Morning Medication\n\nSnap a quick photo when you finish — it always brightens the day 🌿"  // NEW: Last SMS sent (added ffd2878)
}
```

**Field Requirements:**
- `id` → UUID (unique per habit creation)
- `userId` → MUST match user document path
- `profileId` → MUST match parent profile document ID
- `scheduledTime` → Required
- `nextScheduledDate` → Required for query optimization
- `lastSentMessage` → Optional, stores the actual SMS text sent to recipient (randomized friendly message)

---

### 4. Message (SMS Response) Subcollection
**Path:** `/users/{firebaseUID}/profiles/{profileId}/messages/{messageId}`

**Document ID Rule:**
- ✅ Use UUID.uuidString OR Twilio message SID
- ❌ **NEVER** use timestamp alone (not unique)

**Structure:**
```json
{
  "id": "uuid-message-456",
  "taskId": "uuid-habit-123",                 // Optional: links to specific habit
  "profileId": "+15551234567",                // Parent profile reference
  "userId": "firebase-auth-uid-abc123",       // User reference
  "textResponse": "Done! Feeling great today",
  "photoData": null,                          // Base64 or null (use photoURL instead)
  "photoURL": "https://storage.googleapis.com/...",
  "isCompleted": true,
  "receivedAt": "2025-10-03T09:05:00Z",
  "responseType": "text",                     // text, photo, both
  "isConfirmationResponse": false,
  "isPositiveConfirmation": false,
  "responseScore": 0.95,
  "processingNotes": "Sentiment: positive"
}
```

**Field Requirements:**
- `id` → UUID or Twilio SID
- `userId` → MUST match user document path
- `profileId` → MUST match parent profile document ID
- `taskId` → Optional, null for profile confirmation messages
- `receivedAt` → Required
- `responseType` → Enum: `text`, `photo`, `both`

---

### 5. Gallery Event Subcollection
**Path:** `/users/{firebaseUID}/gallery_events/{eventId}`

**Document ID Rule:**
- ✅ Use UUID.uuidString
- ❌ **NEVER** use timestamp alone (not unique)

**Structure:**
```json
{
  "id": "uuid-event-789",
  "userId": "firebase-auth-uid-abc123",
  "profileId": "+15551234567",
  "eventData": {
    "taskId": "uuid-habit-123",
    "profileName": "Grandma Rose",
    "profilePhotoURL": "https://storage.googleapis.com/...",
    "taskTitle": "Take Morning Medication",
    "textResponse": "Done! Feeling great",
    "photoData": "base64-encoded-image-data",
    "responseType": "both",
    "sentMessage": "Hello Mom 🌞 A gentle reminder to Take Morning Medication\n\nSnap a quick photo when you finish — it always brightens the day 🌿"  // NEW: Actual SMS sent (added ffd2878)
  },
  "eventType": "taskResponse",               // taskResponse, profileCreated
  "timestamp": "2025-10-03T09:05:00Z",
  "createdAt": "2025-10-03T09:05:00Z"
}
```

**Field Requirements:**
- `id` → UUID (unique per event)
- `userId` → MUST match user document path
- `profileId` → References the profile this event is for
- `eventData.sentMessage` → Optional, stores the actual SMS text sent to recipient (for display in gallery)
- `eventType` → Enum: `taskResponse`, `profileCreated`
- `timestamp` → Event creation time
- `responseType` → Enum: `text`, `photo`, `both`, `flexible`

**Event Types:**
- **taskResponse**: SMS response from elderly user completing a habit
  - Includes: taskId, taskTitle, textResponse, photoData, sentMessage
- **profileCreated**: Profile creation confirmation
  - Includes: profileName, profilePhotoURL

---

## 🚨 CRITICAL VIOLATIONS DETECTED

### Violation #1: Flat Collection Architecture ⚠️
**Current:**
```swift
// FirebaseDatabaseService.swift - Lines 16-24
private enum Collection: String {
    case users = "users"
    case profiles = "profiles"           // ❌ ROOT COLLECTION
    case tasks = "tasks"                 // ❌ ROOT COLLECTION
    case responses = "responses"         // ❌ ROOT COLLECTION
    case galleryEvents = "gallery_events"
}
```

**Should Be:**
```swift
private enum CollectionPath {
    case users
    case userProfiles(userId: String)
    case profileHabits(userId: String, profileId: String)
    case profileMessages(userId: String, profileId: String)

    var path: String {
        switch self {
        case .users:
            return "users"
        case .userProfiles(let userId):
            return "users/\(userId)/profiles"
        case .profileHabits(let userId, let profileId):
            return "users/\(userId)/profiles/\(profileId)/habits"
        case .profileMessages(let userId, let profileId):
            return "users/\(userId)/profiles/\(profileId)/messages"
        }
    }
}
```

**Impact:**
- ⚠️ Cannot use Firestore's native cascade delete
- ⚠️ Requires manual batch delete logic (error-prone)
- ⚠️ Security rules more complex
- ⚠️ Violates desired schema contract

---

### Violation #2: Inconsistent ID Generation Strategy 🔴
**Evidence from codebase:**

**Profile Creation (ProfileViewModel.swift:557):**
```swift
let profile = ElderlyProfile(
    id: UUID().uuidString,  // ❌ Using UUID
    userId: userId,
    phoneNumber: formattedPhone  // ✅ Should use THIS as ID
)
```

**SMSResponse Creation (SMSResponse.swift:130):**
```swift
return SMSResponse(
    id: UUID().uuidString,  // ✅ Acceptable for messages
    taskId: nil,
    profileId: profileId
)
```

**Task Creation (Task model):**
```swift
// Uses UUID().uuidString - ✅ Acceptable for tasks
```

**Problem:** No documented rule for when to use:
- Phone number as ID (predictable, allows upserts)
- UUID as ID (unique, prevents conflicts)
- Firebase auto-ID (server-generated)

**Recommended Rule:**
1. **User documents:** Use Firebase Auth UID (predictable)
2. **Profile documents:** Use normalized phone number (allows upsert logic)
3. **Habit documents:** Use UUID (unique per creation)
4. **Message documents:** Use UUID or Twilio SID

---

### Violation #3: Missing Cascade Delete Protection ⚠️
**Current Delete Logic (FirebaseDatabaseService.swift:118-151):**
```swift
func deleteElderlyProfile(_ profileId: String) async throws {
    let batch = db.batch()

    // ❌ Manually queries and deletes tasks
    let tasksQuery = db.collection("tasks")
        .whereField("profileId", isEqualTo: profileId)

    // ❌ Manually queries and deletes responses
    let responsesQuery = db.collection("responses")
        .whereField("profileId", isEqualTo: profileId)
}
```

**Problem:**
- Manual deletion is error-prone
- Batch size limit (500 operations)
- No guarantee all subcollections deleted
- Race conditions possible

**With Subcollections (Desired):**
```swift
func deleteProfile(_ profileId: String, userId: String) async throws {
    // ✅ Firestore automatically handles subcollection awareness
    let profileRef = db.collection("users/\(userId)/profiles").document(profileId)

    // Recursively delete subcollections (habits, messages)
    try await deleteDocumentRecursively(profileRef)
}

private func deleteDocumentRecursively(_ docRef: DocumentReference) async throws {
    // Delete all subcollections first
    let collections = ["habits", "messages"]
    for collectionName in collections {
        let snapshot = try await docRef.collection(collectionName).getDocuments()
        for doc in snapshot.documents {
            try await doc.reference.delete()
        }
    }
    // Then delete the document itself
    try await docRef.delete()
}
```

---

### Violation #4: User Document Creation Inconsistency 🔴
**FirebaseAuthenticationService.swift (Lines 173-206):**
```swift
// User document created manually on sign-in
if isNewUser {
    let userData: [String: Any] = [
        "id": user.id,
        "email": user.email,
        "profileCount": 0  // ✅ Good
    ]
    try await db.collection("users").document(user.id).setData(userData)
}
```

**vs DatabaseService:**
```swift
func createUser(_ user: User) async throws {
    let userData = try encodeToFirestore(user)
    try await db.collection("users").document(user.id).setData(userData)
}
```

**Problem:** Duplication - should use `DatabaseService.createUser()` in AuthService

---

### Violation #5: Model Field Mismatch with Firestore ⚠️
**User.swift (Lines 4-14):**
```swift
struct User: Codable {
    let id: String
    let email: String
    let fullName: String
    let phoneNumber: String
    let createdAt: Date
    let isOnboardingComplete: Bool
    let subscriptionStatus: SubscriptionStatus
    let trialEndDate: Date?
    let quizAnswers: [String: String]?
    // ❌ MISSING: profileCount, taskCount, updatedAt, lastSyncTimestamp
}
```

**Firestore Updates:**
```swift
// FirebaseDatabaseService.swift:713-724
try await db.collection("users").document(userId).updateData([
    "profileCount": profileCount,  // ❌ Field doesn't exist in User model
    "updatedAt": FieldValue.serverTimestamp()  // ❌ Field doesn't exist
])
```

**Problem:** Model doesn't match database writes - causes silent data loss

---

## 📊 SCHEMA COMPARISON TABLE

| Entity | Current Path | Desired Path | ID Strategy (Current) | ID Strategy (Desired) | Status |
|--------|--------------|--------------|----------------------|----------------------|---------|
| User | `/users/{uid}` | `/users/{uid}` ✅ | Firebase Auth UID ✅ | Firebase Auth UID ✅ | ✅ Correct |
| Profile | `/profiles/{id}` | `/users/{uid}/profiles/{id}` | UUID ⚠️ | Phone number | ❌ Wrong Path |
| Task/Habit | `/tasks/{id}` | `/users/{uid}/profiles/{pid}/habits/{id}` | UUID ✅ | UUID ✅ | ❌ Wrong Path |
| SMS Response | `/responses/{id}` | `/users/{uid}/profiles/{pid}/messages/{id}` | UUID ✅ | UUID/Twilio SID ✅ | ❌ Wrong Path |
| Gallery Event | `/gallery_events/{id}` | `/users/{uid}/gallery_events/{id}` | UUID ✅ | UUID ✅ | ⚠️ Should nest |

---

## ✅ CLEANUP TO-DO LIST

### Priority 1: Critical Schema Restructure (Breaking Changes)

#### TODO #1: Migrate to Nested Subcollections
**Files to Modify:**
- `FirebaseDatabaseService.swift` (Lines 16-24, all CRUD operations)
- `firestore.rules` (Lines 28-58)

**Actions:**
1. [ ] Create new `CollectionPath` enum with dynamic path building
2. [ ] Update all profile operations to use `/users/{uid}/profiles/{id}`
3. [ ] Update all task operations to use `/users/{uid}/profiles/{pid}/habits/{id}`
4. [ ] Update all response operations to use `/users/{uid}/profiles/{pid}/messages/{id}`
5. [ ] Write Firestore migration script to move existing data
6. [ ] Update security rules to reflect nested structure
7. [ ] Test cascading deletes work correctly

**Risk:** 🔴 Breaking change - requires data migration

**Estimated Effort:** 8-12 hours + testing

---

#### TODO #2: Standardize ID Generation Rules
**Files to Modify:**
- `ProfileViewModel.swift` (Line 557)
- Add new `IDGenerator.swift` utility

**Actions:**
1. [ ] Create `IDGenerator` utility with documented rules:
   ```swift
   enum IDGenerator {
       static func userID(firebaseUID: String) -> String {
           return firebaseUID  // Pass-through
       }

       static func profileID(phoneNumber: String) -> String {
           return phoneNumber.normalizedE164()  // Use phone as ID
       }

       static func habitID() -> String {
           return UUID().uuidString
       }

       static func messageID(twilioSID: String? = nil) -> String {
           return twilioSID ?? UUID().uuidString
       }
   }
   ```
2. [ ] Replace all `UUID().uuidString` calls with `IDGenerator.X()`
3. [ ] Update profile creation to use phone number as ID
4. [ ] Add phone normalization extension: `String.normalizedE164()`

**Risk:** 🟡 Medium - affects profile lookups

**Estimated Effort:** 4-6 hours

---

#### TODO #3: Fix User Model Field Mismatches
**Files to Modify:**
- `User.swift` (Lines 4-14)
- `FirebaseDatabaseService.swift` (Lines 713-737)

**Actions:**
1. [ ] Add missing fields to User struct:
   ```swift
   struct User: Codable {
       // ... existing fields
       var profileCount: Int         // Add
       var taskCount: Int            // Add
       var updatedAt: Date           // Add
       var lastSyncTimestamp: Date?  // Add
   }
   ```
2. [ ] Update all User model usages to include new fields
3. [ ] Ensure Firestore updates match model exactly

**Risk:** 🟢 Low - additive change

**Estimated Effort:** 2-3 hours

---

### Priority 2: Code Quality Improvements

#### TODO #4: Implement Recursive Delete Function
**Files to Create:**
- `FirebaseDatabaseService+Delete.swift` (extension)

**Actions:**
1. [ ] Create recursive delete helper:
   ```swift
   private func deleteDocumentRecursively(
       _ docRef: DocumentReference,
       subcollections: [String]
   ) async throws {
       // Delete all subcollections first
       for collectionName in subcollections {
           let snapshot = try await docRef.collection(collectionName)
               .limit(to: 500)  // Batch limit
               .getDocuments()

           for doc in snapshot.documents {
               try await deleteDocumentRecursively(
                   doc.reference,
                   subcollections: []  // Recursion
               )
           }
       }
       // Delete document itself
       try await docRef.delete()
   }
   ```
2. [ ] Replace manual batch delete logic in:
   - `deleteUser()` (Line 48)
   - `deleteElderlyProfile()` (Line 118)
   - `deleteTask()` (Line 295)
3. [ ] Add batch size handling for >500 documents

**Risk:** 🟢 Low - improves reliability

**Estimated Effort:** 3-4 hours

---

#### TODO #5: Centralize User Document Creation
**Files to Modify:**
- `FirebaseAuthenticationService.swift` (Lines 173-206, 120-153)

**Actions:**
1. [ ] Replace manual Firestore calls with:
   ```swift
   if isNewUser {
       let newUser = User(
           id: firebaseUser.uid,
           email: firebaseUser.email ?? "",
           fullName: firebaseUser.displayName ?? "",
           phoneNumber: "", // Get from profile later
           createdAt: Date(),
           isOnboardingComplete: false,
           subscriptionStatus: .trial,
           trialEndDate: Date().addingTimeInterval(14 * 24 * 3600),
           quizAnswers: nil,
           profileCount: 0,
           taskCount: 0,
           updatedAt: Date(),
           lastSyncTimestamp: nil
       )
       try await databaseService.createUser(newUser)
   }
   ```
2. [ ] Remove duplicate user creation logic (Google vs Apple sign-in)

**Risk:** 🟢 Low - reduces duplication

**Estimated Effort:** 2 hours

---

#### TODO #6: Add Firestore Indexes Documentation
**Files to Create:**
- `firestore.indexes.json` updates

**Actions:**
1. [ ] Document required composite indexes:
   ```json
   {
     "indexes": [
       {
         "collectionGroup": "habits",
         "queryScope": "COLLECTION",
         "fields": [
           { "fieldPath": "userId", "order": "ASCENDING" },
           { "fieldPath": "status", "order": "ASCENDING" },
           { "fieldPath": "nextScheduledDate", "order": "ASCENDING" }
         ]
       },
       {
         "collectionGroup": "messages",
         "queryScope": "COLLECTION",
         "fields": [
           { "fieldPath": "userId", "order": "ASCENDING" },
           { "fieldPath": "profileId", "order": "ASCENDING" },
           { "fieldPath": "receivedAt", "order": "DESCENDING" }
         ]
       }
     ]
   }
   ```
2. [ ] Test all queries work with indexes
3. [ ] Deploy to Firebase

**Risk:** 🟢 Low

**Estimated Effort:** 1-2 hours

---

### Priority 3: Testing & Validation

#### TODO #7: Add Schema Validation Tests
**Files to Create:**
- `FirebaseSchemaTests.swift`

**Actions:**
1. [ ] Create unit tests to validate:
   ```swift
   func testUserDocumentMatchesModel() {
       // Create user in Firestore
       // Read it back
       // Ensure all User fields present
   }

   func testProfileIDUsesPhoneNumber() {
       // Create profile
       // Assert ID == normalized phone
   }

   func testCascadeDeleteRemovesAllSubcollections() {
       // Create user → profile → habits → messages
       // Delete profile
       // Assert all subcollections deleted
   }

   func testNoOrphanedDocuments() {
       // Delete user
       // Query for any docs with that userId
       // Assert none exist
   }
   ```
2. [ ] Add Firebase emulator test setup
3. [ ] Run tests on CI/CD

**Risk:** 🟢 Low

**Estimated Effort:** 6-8 hours

---

#### TODO #8: Add Linter Rules for Schema Consistency
**Files to Create:**
- `.swiftlint.yml` custom rules

**Actions:**
1. [ ] Add regex rules to catch violations:
   ```yaml
   custom_rules:
     no_uuid_for_profiles:
       name: "Profiles must use phone number as ID"
       regex: 'ElderlyProfile\([\s\S]*?id:\s*UUID\(\)\.uuidString'
       message: "Use phone number as profile ID, not UUID"
       severity: error

     no_flat_firestore_paths:
       name: "Use nested subcollections"
       regex: 'db\.collection\("(profiles|tasks|responses)"\)'
       message: "Use nested paths: users/{uid}/profiles/{pid}/..."
       severity: error

     require_id_generator:
       name: "Use IDGenerator instead of UUID directly"
       regex: 'id:\s*UUID\(\)\.uuidString'
       message: "Use IDGenerator.X() for consistent ID generation"
       severity: warning
   ```
2. [ ] Install SwiftLint in Xcode project
3. [ ] Fix all violations

**Risk:** 🟢 Low

**Estimated Effort:** 2-3 hours

---

## 🧪 RECOMMENDED UNIT TESTS

### Test Suite 1: ID Consistency Tests
```swift
class IDGenerationTests: XCTestCase {
    func testUserIDMatchesFirebaseUID() {
        let firebaseUID = "abc123"
        let generatedID = IDGenerator.userID(firebaseUID: firebaseUID)
        XCTAssertEqual(generatedID, firebaseUID)
    }

    func testProfileIDNormalizesPhoneNumber() {
        let phone = "555-123-4567"
        let expectedID = "+15551234567"
        let generatedID = IDGenerator.profileID(phoneNumber: phone)
        XCTAssertEqual(generatedID, expectedID)
    }

    func testHabitIDIsUUID() {
        let id1 = IDGenerator.habitID()
        let id2 = IDGenerator.habitID()
        XCTAssertNotEqual(id1, id2)
        XCTAssertTrue(UUID(uuidString: id1) != nil)
    }
}
```

### Test Suite 2: Schema Path Tests
```swift
class FirestorePathTests: XCTestCase {
    func testProfilePathIsNested() {
        let userId = "user123"
        let profileId = "+15551234567"
        let expectedPath = "users/user123/profiles/+15551234567"

        let path = CollectionPath.userProfiles(userId: userId).path
        XCTAssertTrue(path.contains("users/\(userId)/profiles"))
    }

    func testHabitPathIsDoublyNested() {
        let userId = "user123"
        let profileId = "+15551234567"
        let expectedPath = "users/user123/profiles/+15551234567/habits"

        let path = CollectionPath.profileHabits(
            userId: userId,
            profileId: profileId
        ).path
        XCTAssertEqual(path, expectedPath)
    }
}
```

### Test Suite 3: Cascade Delete Tests
```swift
class CascadeDeleteTests: XCTestCase {
    func testDeletingProfileDeletesAllHabits() async throws {
        // Setup: Create user → profile → 3 habits
        let userId = "test-user"
        let profileId = "+15551234567"

        // Create test data
        try await createTestProfile(userId: userId, profileId: profileId)
        try await createTestHabit(userId: userId, profileId: profileId, id: "habit1")
        try await createTestHabit(userId: userId, profileId: profileId, id: "habit2")
        try await createTestHabit(userId: userId, profileId: profileId, id: "habit3")

        // Delete profile
        try await databaseService.deleteProfile(profileId, userId: userId)

        // Verify all habits deleted
        let habitsPath = "users/\(userId)/profiles/\(profileId)/habits"
        let snapshot = try await db.collection(habitsPath).getDocuments()
        XCTAssertEqual(snapshot.documents.count, 0)
    }

    func testDeletingUserDeletesAllNestedData() async throws {
        // Create user → 2 profiles → 3 habits each → 5 messages each
        // Delete user
        // Assert all profiles, habits, messages deleted
    }
}
```

### Test Suite 4: Model-Firestore Sync Tests
```swift
class ModelFirestoreSyncTests: XCTestCase {
    func testUserModelMatchesFirestoreSchema() async throws {
        let user = User(/* ... */)
        try await databaseService.createUser(user)

        let doc = try await db.collection("users").document(user.id).getDocument()
        let firestoreFields = Set(doc.data()?.keys ?? [])

        let mirror = Mirror(reflecting: user)
        let modelFields = Set(mirror.children.compactMap { $0.label })

        XCTAssertEqual(firestoreFields, modelFields)
    }
}
```

---

## 🔒 SECURITY RULES IMPACT

### Current Rules (Flat Structure):
```javascript
match /profiles/{profileId} {
  allow read, write: if isAuthenticated() &&
                    isOwner(resource.data.userId);
}
```

### Desired Rules (Nested Structure):
```javascript
match /users/{userId} {
  allow read, write: if isAuthenticated() && isOwner(userId);

  match /profiles/{profileId} {
    // Automatically scoped to parent user
    allow read, write: if isAuthenticated() && isOwner(userId);

    match /habits/{habitId} {
      allow read, write: if isAuthenticated() && isOwner(userId);
    }

    match /messages/{messageId} {
      allow read, write: if isAuthenticated() && isOwner(userId);
    }
  }
}
```

**Benefits:**
- ✅ Simpler rules (inheritance from parent)
- ✅ Automatic scoping to user
- ✅ No need to check `userId` field in nested docs

---

## 📈 MIGRATION STRATEGY

### Phase 1: Preparation (No Downtime)
1. Deploy new code with dual-read support (read from both old and new paths)
2. Write to both old and new structures (double-write)
3. Monitor for errors

### Phase 2: Migration (Scheduled Maintenance)
1. Run Firestore data migration script:
   ```javascript
   // Cloud Function or local script
   async function migrateToNestedStructure() {
     const users = await db.collection('users').get();

     for (const userDoc of users.docs) {
       const userId = userDoc.id;

       // Migrate profiles
       const profiles = await db.collection('profiles')
         .where('userId', '==', userId).get();

       for (const profileDoc of profiles.docs) {
         const profileData = profileDoc.data();
         await db.collection(`users/${userId}/profiles`)
           .doc(profileDoc.id).set(profileData);

         // Migrate habits for this profile
         // Migrate messages for this profile
       }
     }
   }
   ```
2. Verify data integrity
3. Switch to read-only from new structure

### Phase 3: Cleanup
1. Remove dual-write logic
2. Delete old collections (`/profiles`, `/tasks`, `/responses`)
3. Monitor for 7 days

---

## 🎯 CONFIDENCE SCORE: 8/10

**Why 8/10:**
- ✅ Complete understanding of current vs desired architecture
- ✅ Clear violations identified with specific line numbers
- ✅ Detailed migration plan with risk assessment
- ✅ Comprehensive test coverage recommendations

**Why not 10/10:**
- ⚠️ Migration requires production downtime
- ⚠️ Existing users may have data that violates new ID rules
- ⚠️ Need to verify Twilio integration doesn't break with nested paths

---

## 📚 REFERENCES

- [Firestore Data Model Best Practices](https://firebase.google.com/docs/firestore/best-practices)
- [Deleting Collections](https://firebase.google.com/docs/firestore/manage-data/delete-data#collections)
- [Security Rules for Subcollections](https://firebase.google.com/docs/firestore/security/rules-structure#subcollections)
- [SwiftUI + Firestore Patterns](https://peterfriese.dev/posts/swiftui-firebase-firestore/)

---

**Document Status:** ✅ Complete
**Next Steps:** Review with team → Prioritize TODOs → Begin Phase 1 migration
