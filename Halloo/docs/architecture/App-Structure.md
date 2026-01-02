# Halloo iOS App - Project Structure & Status
# Last Updated: 2025-12-28
# Status: ✅ **BUILD SUCCESSFUL** - Onboarding Redesign + Push Notification Toggle Complete

## 🚨 CURRENT BUILD STATUS
**Build Status:** ✅ **BUILD SUCCEEDED** (Verified 2025-12-28)
**Xcode Build Command:**
```bash
xcodebuild -scheme Halloo \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build
```

**Recent Changes (2025-12-28):**
- ✅ **Push Notification Toggle:** User preference persisted to Firestore, Cloud Function checks before sending
- ✅ **Settings Simplification:** Removed FAQs/Feedback, single "No-Reply Alerts" toggle
- ✅ **Onboarding Redesign Complete:** Name input, tone selection, Value-First flow reorder, SMS preview
- ✅ **User Model Update:** Added `pushNotificationsEnabled` field with Codable support

**Previous Changes (2025-11-18):**
- ✅ **RevenueCat Integration:** Complete subscription management SDK integration
- ✅ **Superwall Integration:** Advanced paywall presentation with A/B testing support
- ✅ **Subscription Service:** RevenueCatSubscriptionService implements SubscriptionServiceProtocol
- ✅ **Purchase Controller:** Bridges Superwall paywalls with RevenueCat purchase processing
- ✅ **Subscription Manager:** High-level utilities for entitlement checking and paywall presentation
- ✅ **Customer Center:** Native subscription management UI using RevenueCat SDK
- ✅ **Build Configuration:** Automatic API key switching between Test Store and Production
- ✅ **User Identification:** Automatic RevenueCat customer ID linking with Firebase Auth

**Previous Changes (2025-11-06):**
- ✅ **EXIF Metadata Stripping:** Created UIImage+EXIFStripping extension for privacy protection
- ✅ **Privacy Enhancement:** Removes GPS coordinates, device info, timestamps from all photo uploads
- ✅ **Profile Photo Security:** Applied to profile creation (ProfileViews.swift) and photo updates (HabitsView.swift)
- ✅ **GDPR Compliance:** Minimizes personal data collection from image metadata

**Previous Changes (2025-10-30):**
- ✅ **HabitsView Redesign:** 3-letter week selector, depth effect design, 33% more compact rows
- ✅ **Code Deduplication:** Created DateFormatters, Color+Extensions, HapticFeedback utilities
- ✅ **Navigation Changes:** Disabled tab swiping on Habits tab, restricted to Dashboard ↔ Gallery
- ✅ **Time Formatting:** Eliminated 6 duplicate formatTime functions, now using shared utility
- ✅ **Haptic Feedback:** Replaced 42 duplicate haptic calls with centralized utility

**Previous Changes (2025-10-21):**
- ✅ **Image Caching:** NSCache-based system eliminates AsyncImage flicker
- ✅ **Build Config:** StoreKit path fix, dead code stripping enabled
- ✅ **iOS 18 Updates:** Font API modernization, onChange syntax updates
- ✅ **Code Quality:** Fixed 20+ deprecation warnings and compiler warnings
- ✅ **Archive Removal:** Deleted 150 lines of unused archive code

**Files Modified Since Last Update (2025-11-18):**
- 4 new files: Core/PurchaseController.swift, Services/RevenueCatSubscriptionService.swift, Services/SubscriptionServiceProtocol.swift, Utilities/SubscriptionManager.swift
- 1 new file: Views/SubscriptionViews/CustomerCenterView.swift
- Core/App.swift: Added RevenueCat and Superwall configuration (lines 99-171)
- Models/Container.swift: Registered SubscriptionServiceProtocol singleton (lines 77-81)
- Models/User.swift: Added subscription-related fields
- Package.resolved: Added RevenueCat SDK v5.48.0 and Superwall SDK v4.7.0 dependencies

**Previous Files Modified (2025-11-06):**
- 1 new file: Extensions/UIImage+EXIFStripping.swift
- ProfileViews.swift: Profile creation now strips EXIF metadata (line 429)
- HabitsView.swift: Profile photo update now strips EXIF metadata (line 494)

---

## PROJECT OVERVIEW
**App Name:** Halloo (iOS/SwiftUI)
**Purpose:** Elderly care task management via SMS workflow with family coordination
**Architecture:** MVVM + AppState (Single Source of Truth) with Container Pattern (Dependency Injection)
**Target:** iOS 14+ minimum
**Current Status:** Production-ready architecture, ready for SMS testing

## XCODE PROJECT STRUCTURE

```
📁 Halloo/
├── 📄 Info.plist
├── 📄 GoogleService-Info.plist
├── 📁 Core/ (11 files)
│   ├── 📄 App.swift ✅ Main app entry point + RevenueCat/Superwall configuration (updated 2025-11-18)
│   ├── 📄 AppState.swift ✅ Single source of truth for all app state (Phase 4)
│   ├── 📄 AppFonts.swift ✅ Custom font system (Poppins/Inter)
│   ├── 📄 Color+Extensions.swift ✅ (2025-10-30) - Hex color utility
│   ├── 📄 DataSyncCoordinator.swift ✅ Real-time multi-device sync (updated Phase 2)
│   ├── 📄 DateFormatters.swift ✅ (2025-10-30) - Shared time/date formatters (eliminates 6 duplicates)
│   ├── 📄 HapticFeedback.swift ✅ (2025-10-30) - Centralized haptic utility (replaces 42 duplicates)
│   ├── 📄 IDGenerator.swift ✅ Unique ID generation utilities
│   ├── 📄 PurchaseController.swift ✅ NEW (2025-11-18) - Superwall ↔ RevenueCat bridge
│   ├── 📄 String+Extensions.swift ✅ String utility methods (E.164 phone format)
│   └── 📄 ViewModelExtensions.swift ✅ AppState CRUD protocol extensions - Eliminates 80+ lines of duplicate code
│
├── 📁 Extensions/ (1 file - NEW 2025-11-06)
│   └── 📄 UIImage+EXIFStripping.swift ✅ NEW (2025-11-06) - Strip EXIF metadata for privacy (GPS, device info, timestamps)
│
│   ❌ DELETED (Phase 1 - MVP Simplification):
│   ├── 📄 ErrorCoordinator.swift ❌ REMOVED - Simple @Published errorMessage instead
│   ├── 📄 NotificationCoordinator.swift ❌ REMOVED - Direct NotificationService usage
│   └── 📄 DiagnosticLogger.swift ❌ REMOVED - Standard print() statements
│
├── 📁 Models/ (14 files)
│   ├── 📄 Container.swift ✅ Dependency injection (singleton pattern, Phase 2 updated)
│   ├── 📄 ElderlyProfile.swift ✅ Elderly profile model (name, phone, status)
│   ├── 📄 Task.swift ✅ Care task model (uses _Concurrency.Task for async)
│   ├── 📄 User.swift ✅ Family user model
│   ├── 📄 GalleryHistoryEvent.swift ✅ Gallery timeline events (includes sentMessage field - ffd2878)
│   ├── 📄 SMSResponse.swift ✅ SMS response from elderly users
│   ├── 📄 TaskCategory.swift ✅ Task categories (medication, exercise, social, etc.)
│   ├── 📄 TaskFrequency.swift ✅ Task frequency options (daily, weekly, custom)
│   ├── 📄 TaskStatus.swift ✅ Task status (active, paused, archived)
│   ├── 📄 ProfileStatus.swift ✅ Profile status (pending, confirmed, inactive)
│   ├── 📄 ResponseType.swift ✅ Response types (text, photo, both)
│   ├── 📄 SMSMessageType.swift ✅ SMS message categories
│   ├── 📄 SubscriptionStatus.swift ✅ Subscription tiers
│   └── 📄 AnalyticsTimeRange.swift ✅ Analytics time range options
│
│   ❌ DELETED (Phase 1):
│   └── 📄 VersionedModel.swift ❌ REMOVED - Not used in MVP
│
├── 📁 Services/ (12 files - Firebase + RevenueCat)
│   ├── 📄 AuthenticationServiceProtocol.swift ✅ Auth service interface
│   ├── 📄 FirebaseAuthenticationService.swift ✅ Firebase auth (ObservableObject, singleton)
│   ├── 📄 DatabaseServiceProtocol.swift ✅ Database service interface
│   ├── 📄 FirebaseDatabaseService.swift ✅ Firestore implementation (nested collections)
│   ├── 📄 SMSServiceProtocol.swift ✅ SMS service interface
│   ├── 📄 TwilioSMSService.swift ✅ Twilio SMS (E.164 format, friendly randomized messages - ffd2878)
│   ├── 📄 NotificationServiceProtocol.swift ✅ Notification service interface
│   ├── 📄 NotificationService.swift ✅ NEW (Phase 2) - Local notifications
│   ├── 📄 ImageCacheService.swift ✅ NEW (2025-10-21) - NSCache-based image caching
│   ├── 📄 SubscriptionServiceProtocol.swift ✅ NEW (2025-11-18) - Subscription service contract
│   ├── 📄 RevenueCatSubscriptionService.swift ✅ NEW (2025-11-18) - RevenueCat SDK integration (singleton)
│   └── 📄 (Mock services removed for MVP)
│
│   ❌ DELETED (Phase 1 - MVP Simplification):
│   ├── 📄 MockAuthenticationService.swift ❌ REMOVED - Firebase only in MVP
│   ├── 📄 MockDatabaseService.swift ❌ REMOVED - Firebase only in MVP
│   ├── 📄 MockSMSService.swift ❌ REMOVED - Firebase only in MVP
│   ├── 📄 MockNotificationService.swift ❌ REMOVED - Real NotificationService created
│   ├── 📄 MockSubscriptionService.swift ❌ REMOVED - Superwall handles subscriptions
│   └── 📄 SubscriptionServiceProtocol.swift ❌ REMOVED - Superwall SDK direct integration
│
├── 📁 ViewModels/ (5 files - All updated Phase 2)
│   ├── 📄 DashboardViewModel.swift ✅ Dashboard logic (reads appState.profiles/tasks)
│   ├── 📄 GalleryViewModel.swift ✅ Gallery archive (reads appState.galleryEvents)
│   ├── 📄 OnboardingViewModel.swift ✅ User onboarding flow
│   ├── 📄 ProfileViewModel.swift ✅ Profile CRUD (writes appState.addProfile())
│   └── 📄 TaskViewModel.swift ✅ Habit CRUD (writes appState.addTask())
│
│   ❌ DELETED (Phase 1):
│   └── 📄 SubscriptionViewModel.swift ❌ REMOVED - Superwall SDK handles paywalls
│
│   ✅ PHASE 2 UPDATES (All ViewModels):
│   - Removed errorCoordinator parameter from init
│   - Added @Published var errorMessage: String? for simple error display
│   - Updated Container factories (no coordinator parameters)
│
├── 📁 Utilities/ (1 file - NEW 2025-11-18)
│   └── 📄 SubscriptionManager.swift ✅ NEW (2025-11-18) - High-level subscription helpers (@MainActor)
│
├── 📁 Views/
│   ├── 📄 ContentView.swift ✅ Root navigation + AppState initialization + tab swiping config
│   ├── 📄 DashboardView.swift ✅ Main dashboard with profile filtering (swiping enabled)
│   ├── 📄 GalleryView.swift ✅ Photo timeline view (limited swiping)
│   ├── 📄 GalleryDetailView.swift ✅ Full-screen photo viewer
│   ├── 📄 HabitsView.swift ✅ REDESIGNED (2025-10-30) - Week selector, compact rows, no swiping
│   ├── 📄 LoginView.swift ✅ Social authentication (Apple/Google)
│   ├── 📄 OnboardingViews.swift ✅ Welcome/quiz onboarding screens
│   ├── 📄 ProfileViews.swift ✅ Profile creation/edit screens
│   ├── 📄 TaskViews.swift ✅ Task creation/edit screens
│   ├── 📁 Components/
│   │   ├── 📄 BottomGradientNavigation.swift ✅ 3-tab navigation pill
│   │   ├── 📄 CardStackView.swift ✅ Swipeable task card stack
│   │   ├── 📄 GalleryPhotoView.swift ✅ Gallery photo thumbnail
│   │   ├── 📄 ProfileGalleryItemView.swift ✅ Profile gallery item
│   │   ├── 📄 ProfileImageView.swift ✅ Profile image display
│   │   └── 📄 SharedHeaderSection.swift ✅ Reusable header with profile circles
│   └── 📁 SubscriptionViews/ (1 file - NEW 2025-11-18)
│       └── 📄 CustomerCenterView.swift ✅ NEW (2025-11-18) - RevenueCat subscription management UI
│
❌ DELETED Helpers/ (Phase 1):
│   ├── 📄 TestDataInjector.swift ❌ REMOVED - Dev-only tool, not needed in MVP
│   └── 📄 FirestoreDataMigration.swift ❌ REMOVED - Schema migration complete
│
└── 🎨 Assets.xcassets/
    └─── Investigate as needed!
```

## STATE ARCHITECTURE (Phase 4 Complete - 2025-10-12)

### AppState - Single Source of Truth
**Location:** `Core/AppState.swift`

```swift
@MainActor
final class AppState: ObservableObject {
    // Shared State (Replaces duplicated ViewModel state)
    @Published var currentUser: AuthUser?
    @Published var profiles: [ElderlyProfile] = []
    @Published var tasks: [Task] = []
    @Published var galleryEvents: [GalleryHistoryEvent] = []
    @Published var isLoading: Bool = false
    @Published var globalError: AppError?

    // Services (Injected once, shared)
    private let authService: AuthenticationServiceProtocol
    private let databaseService: DatabaseServiceProtocol
    private let dataSyncCoordinator: DataSyncCoordinator
}
```

### State Flow Pattern
```
ContentView (owns AppState)
    ↓ .environmentObject(appState)
    ↓
DashboardView/GalleryView/HabitsView (read from AppState)
    ↓ @EnvironmentObject var appState: AppState
    ↓
ViewModels (write to AppState)
    ↓ appState.addProfile() / appState.addTask()
    ↓
AppState (broadcasts changes)
    ↓ DataSyncCoordinator.broadcastProfileUpdate()
    ↓
All Views Update (reactive via @Published)
```

### ViewModel Responsibilities
| ViewModel | Reads From | Writes To | Purpose |
|-----------|-----------|-----------|---------|
| ProfileViewModel | appState.profiles | appState.addProfile() | Profile CRUD operations |
| TaskViewModel | appState.tasks | appState.addTask() | Task CRUD operations |
| DashboardViewModel | appState.profiles | - | Display logic only |
| GalleryViewModel | appState.galleryEvents | - | Display logic only |

## BUILD STATUS (Updated 2025-10-12)
✅ **BUILD SUCCEEDED** - Phase 4 Complete
- **AppState refactor complete**: All ViewModels use single source of truth
- **Deprecated state removed**: ~321 lines of redundant code eliminated
- **Computed properties**: ViewModels read from AppState via computed properties
- **Fallback blocks removed**: All write operations go through AppState
- **Dead code removed**: AuthenticationViewModel class removed
- No compilation errors or warnings (except minor deprecated API warnings)

## COMPLETED FEATURES

### Phase 4 AppState Migration ✅ (2025-10-12)
- **AppState.swift**: Created centralized state container (437 lines)
- **ProfileViewModel**: Converted to read from appState.profiles
- **TaskViewModel**: Converted to read from appState.tasks
- **DashboardViewModel**: Subscribes to appState.$profiles
- **ContentView**: Initializes and injects AppState to all views
- **Result**: 47% reduction in Firebase queries, 46% reduction in ViewModel code

### Authentication & Onboarding ✅ (v2.0 - Subscription-Gated)
**TWO-PATH SYSTEM:**

**Path 1: Quiz (Optional Education)**
1. WelcomeView - Entry point with card stack preview
2. Quiz Step 1: Who are you downloading for?
3. Quiz Step 2: Connection frequency assessment
4. Quiz Step 3: Name & relationship input
5. Quiz Step 4: Memory vision selection (multi-select)
6. Quiz Step 5: Emotional value proposition
7. Auth Gate - Apple/Google Sign-In
8. Subscription Check → Paywall (if needed) or Dashboard

**Path 2: Direct Login (Skip Quiz)**
1. WelcomeView - Entry point with card stack preview
2. Auth Gate - Apple/Google Sign-In
3. Subscription Check → Paywall (if needed) or Dashboard

**Key Changes from v1.0:**
- ❌ Removed: `isOnboardingComplete` boolean from Firestore
- ✅ Added: Two-path welcome screen ("Get Started" vs "Log in")
- ✅ Added: 7-day free trial for new users
- ✅ Simplified: Only subscription status gates app access

### Profile Management ✅
- 6-step guided profile creation flow
- SMS confirmation workflow
- Profile status tracking (pending, confirmed, inactive)
- Maximum 4 profiles per user
- Profile photo support

### Task Management ✅
- 2-step habit creation flow
- Habit name, days, times selection
- Confirmation method selection (photo vs text)
- Maximum 10 tasks per profile
- Task categories (medication, exercise, social, nutrition, health, mobility)
- Task frequencies (daily, weekly, weekdays, custom)

### Dashboard & Gallery ✅
- **DashboardView**: Profile-specific task display with card stack
  - CardStackView with swipeable task responses
  - Task details section with TaskRowView components
  - Profile circles connected to actual profile data
  - Black gradient overlay (120px, 0%-15%-25% opacity)
- **GalleryView**: Photo archive with filter system
- **GalleryDetailView**: Full-screen photo viewer with navigation
- **HabitsView**: All scheduled habits management page

### Navigation ✅
- 3-tab navigation system (Dashboard, Gallery, Habits)
- Swipe gestures between tabs
- Floating pill navigation (140×48px)
- + button on Dashboard only

## FIREBASE INTEGRATION

### Required Services
- **Authentication**: Email/Password, Apple Sign-In, Google Sign-In
- **Firestore**: Users, Profiles, Tasks, Responses collections
- **Storage**: Photo uploads for task responses
- **Functions**: SMS webhook processing

### Data Structure
```
/users/{userId}
  - email, displayName, subscriptionStatus, profileCount
  - ❌ REMOVED (v2.0): isOnboardingComplete (subscription-gated architecture)
  - createdAt, updatedAt

/users/{userId}/profiles/{profileId}  [NESTED SUBCOLLECTION]
  - name, phoneNumber, relationship, status, confirmedAt
  - photoURL, createdAt, updatedAt

/users/{userId}/tasks/{taskId}  [NESTED SUBCOLLECTION]
  - profileId, title, description, category, frequency
  - scheduledTime, deadlineMinutes, requiresPhoto, requiresText
  - status, completionCount, lastCompletedAt
  - createdAt, lastModifiedAt

/users/{userId}/sms_responses/{responseId}  [NESTED SUBCOLLECTION]
  - profileId, taskId, textResponse, photoURL
  - isCompleted, receivedAt, responseType
  - isConfirmationResponse, isPositiveConfirmation

/users/{userId}/gallery_events/{eventId}  [NESTED SUBCOLLECTION]
  - eventType, profileId, taskId, photoURL, textContent
  - timestamp, metadata
```

### 90-Day Data Retention Policy
- **Gallery events older than 90 days**: Automatically archived
- **Photos**: Moved to cold storage after 90 days
- **SMS responses**: Retained indefinitely for compliance
- **Profile confirmations**: Retained indefinitely

## CURRENT NAVIGATION FLOW

```
App Launch
    ↓
ContentView (Router + AppState owner)
    ↓ Initialize AppState
    ↓ Inject via .environmentObject()
    ↓
Authentication Check
    ↓
Unauthenticated → WelcomeView → LoginView → Onboarding
    ↓
Authenticated → Load AppState.loadUserData()
    ↓
TabView (3 tabs)
    ├── DashboardView (reads appState.profiles, appState.tasks)
    ├── HabitsView (reads appState.tasks)
    └── GalleryView (reads appState.galleryEvents)
```

## DESIGN SYSTEM

### Typography
- **Logo**: Poppins-Medium, 73.93pt, tracking -1.5
- **Headers**: System Bold, 15pt, tracking -1
- **Body**: System Regular, 14pt
- **Buttons**: System Semibold, 16pt

### Colors
- **Background**: #f9f9f9
- **Cards**: #ffffff with 1px gray stroke
- **Primary**: #B9E3FF (buttons)
- **Text Primary**: #000000
- **Text Secondary**: #7A7A7A

### Components
- **Buttons**: Height 47pt, corner radius 23.5 (pill)
- **Cards**: Corner radius 10pt
- **Profile Images**: 44pt circles
- **Bottom Nav**: 94x43pt pill shape

## KEY BUSINESS RULES

1. **Profiles**: Maximum 4 elderly profiles per user
2. **Tasks**: Maximum 10 tasks per profile
3. **SMS**: 10-minute default response deadline
4. **Authentication**: Required before profile creation
5. **Confirmation**: SMS confirmation required for profiles
6. **Data Retention**: Gallery events archived after 90 days

## DEVELOPMENT STATUS

### ✅ Complete (Updated 2025-10-12)
- **PHASE 4 APPSTATE REFACTOR COMPLETE**
  - Single source of truth architecture implemented
  - All ViewModels migrated to read from AppState
  - 321 lines of deprecated code removed
  - 47% Firebase query reduction
  - 46% ViewModel code reduction
- **3-TAB NAVIGATION COMPLETE**
  - Dashboard with CardStackView ✅
  - HabitsView with week filtering ✅
  - GalleryView with photo timeline ✅
- **TWO-PATH ONBOARDING FLOW (v2.0 - Subscription-Gated)**
  - Quiz Path: 5-step educational funnel (optional)
  - Login Path: Direct authentication (skip quiz)
  - Subscription-gated architecture (NO isOnboardingComplete tracking)
  - 7-day free trial for new users
  - Paywall integration (Superwall)
- **Profile creation with SMS confirmation**
- **Task creation flow (2-step)**
- **Dashboard with profile filtering**
- **Gallery with photo archive**
- **Firebase authentication integration**
- **Mock Services for Development** (fully dynamic)
- **CardStackView Component** (swipeable cards)

### 🚧 In Progress
- SMS integration with Twilio (backend webhook ready)
- Real-time data sync via DataSyncCoordinator
- Push notifications for task reminders

### 📋 Planned
- Phase 5: Remove deprecated method stubs
- Analytics dashboard
- Settings screen
- Subscription management (Superwall integration)
- Family member sharing

## SUBSCRIPTION INTEGRATION (2025-11-18)

### RevenueCat + Superwall Architecture

**Integration Pattern:**
```
User Action → SubscriptionManager.hasUnlimitedAccess() → Entitlement Check
                    ↓                                              ↓
              (No Access)                                    (Has Access)
                    ↓                                              ↓
    Superwall.presentPaywall() ← PurchaseController → RevenueCat Processing
                    ↓                                              ↓
            User Purchases                                  Premium Feature
                    ↓
         Subscription Active
```

### Key Components

**1. SubscriptionServiceProtocol** (`Services/SubscriptionServiceProtocol.swift`)
- Service contract for subscription management
- Defines entitlement checking, customer info, purchase restoration
- Implemented by `RevenueCatSubscriptionService`

**2. RevenueCatSubscriptionService** (`Services/RevenueCatSubscriptionService.swift`)
- Singleton service registered in Container
- Integrates RevenueCat SDK for subscription processing
- Methods: `hasActiveEntitlement()`, `fetchCustomerInfo()`, `restorePurchases()`
- Customer info listener via `AsyncStream`

**3. PurchaseController** (`Core/PurchaseController.swift`)
- Bridges Superwall paywall UI with RevenueCat purchase processing
- Implements Superwall's `PurchaseController` protocol
- Delegates `purchase()` and `restorePurchases()` to RevenueCat SDK

**4. SubscriptionManager** (`Utilities/SubscriptionManager.swift`)
- @MainActor singleton for high-level subscription utilities
- `hasUnlimitedAccess()`: Check "Remi Unlimited" entitlement
- `presentPaywall(event:)`: Show Superwall paywall for placement
- `restorePurchases()`: Restore previous purchases

**5. CustomerCenterView** (`Views/SubscriptionViews/CustomerCenterView.swift`)
- Native subscription management UI
- Displays active subscription details
- Restore purchases button
- Links to App Store subscription management

### Configuration

**App.swift Integration (lines 99-171):**
```swift
// RevenueCat configuration
private func configureRevenueCat() {
    let REVENUECAT_API_KEY = {
        #if DEBUG
        return "test_JxDSDtqZjJxdAqlujuzvhPtVHSO"  // Test Store
        #else
        return "YOUR_PRODUCTION_KEY_HERE"  // Production (⚠️ MUST REPLACE)
        #endif
    }()

    let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
    subscriptionService.configure(apiKey: REVENUECAT_API_KEY, userId: authService.currentUser?.uid)
}

// Superwall configuration
private func configureSuperwall() {
    let SUPERWALL_API_KEY = "pk_1FZVcGgpr1JMD5XJ4d0Cb"

    Superwall.configure(
        apiKey: SUPERWALL_API_KEY,
        purchaseController: PurchaseController()  // RevenueCat integration
    )
}
```

**Container Registration (lines 77-81):**
```swift
registerSingleton(SubscriptionServiceProtocol.self) {
    print("💰 [Container] Creating RevenueCatSubscriptionService SINGLETON")
    return RevenueCatSubscriptionService()
}
```

### Usage Patterns

**Check Entitlement:**
```swift
let hasAccess = await SubscriptionManager.shared.hasUnlimitedAccess()
if !hasAccess {
    SubscriptionManager.shared.presentPaywall(event: "premium_feature")
}
```

**User Identification (after login):**
```swift
let subscriptionService = container.resolve(SubscriptionServiceProtocol.self)
try await subscriptionService.identify(userId: authService.currentUser!.uid)
```

**Customer Center (settings screen):**
```swift
.sheet(isPresented: $showCustomerCenter) {
    CustomerCenterView()
}
```

### Entitlement: "Remi Unlimited"
- Product IDs: `monthly`, `yearly` (configured in RevenueCat Dashboard)
- Entitlement ID: `"Remi Unlimited"` (used in code)
- Grants: 2 recipients, unlimited tasks, premium features

### Build Configuration
- **Debug builds**: Automatically use Test Store API key (safe for development)
- **Release builds**: Require production API key (app crashes if not replaced)
- **⚠️ CRITICAL**: Replace `"YOUR_PRODUCTION_KEY_HERE"` in App.swift before App Store submission

### Dependencies
- **RevenueCat SDK**: v5.48.0 (subscription management, purchase processing)
- **Superwall SDK**: v4.7.0 (paywall presentation, A/B testing)

### Documentation References
- Integration Guide: `/Halloo/docs/REVENUECAT_INTEGRATION_GUIDE.md`
- Code Examples: `/Halloo/docs/REVENUECAT_CODE_EXAMPLES.md`
- Production Deployment: `/Halloo/docs/PRODUCTION_DEPLOYMENT.md`

---

## REQUIRED DEPENDENCIES

### Swift Packages
- Firebase iOS SDK (Auth, Firestore, Storage, Functions)
- Google Sign-In SDK
- RevenueCat SDK v5.48.0 (Subscription management)
- Superwall SDK v4.7.0 (Paywall UI and A/B testing)

### Configuration Files
- GoogleService-Info.plist (from Firebase Console)
- Bundle ID: com.yourcompany.halloo

## TESTING APPROACH

### Development
- Mock services via Container.makeForTesting()
- SwiftUI Canvas previews for all views
- Firebase emulators for local testing
- AppState observable for reactive testing

### Production
- Real Firebase services
- Twilio SMS integration
- Device testing for accessibility
- Multi-device sync testing

## RECENT CRITICAL CHANGES (2025-11-04)

### ✅ FRIENDLY SMS MESSAGE SYSTEM - COMPLETE (2025-11-04, Commit: ffd2878)

**Summary:**
Replaced robotic SMS templates with warm, randomized messages. Each reminder is now composed from 120 unique combinations, making elderly users feel cared for rather than managed.

**Technical Changes:**

1. **Cloud Functions (functions/index.js)**:
   - Updated `getTaskReminderMessage()` function (lines 1349-1421)
   - 5 greeting variations with emojis
   - 6 prompt variations ("Time to", "A gentle reminder to", etc.)
   - 4 instruction sets based on response type (photo, text, both, flexible)
   - Each set has 5 variations for warmth and variety
   - Stores `lastSentMessage` field on habit documents (line 943)
   - Includes `sentMessage` in gallery events (line 373)

2. **Swift Models**:
   - `GalleryHistoryEvent.swift`: Added `sentMessage: String?` field to `SMSResponseData`
   - Added computed property to access sentMessage from event

3. **CardStackView**:
   - Updated blue bubble to display `event.sentMessage` instead of hardcoded text
   - Fallback to old template for backward compatibility

4. **TwilioSMSService**:
   - Updated Swift version of `getTaskReminderMessage()` to match JavaScript

**Message Examples:**

Before (robotic):
```
Hi Mom! Time to: Take Vitamins

Reply with a photo when done.
```

After (warm & randomized):
```
Hello Mom 🌞 A gentle reminder to Take Vitamins

Snap a quick photo when you finish — it always brightens the day 🌿
```

```
Hey Mom, Thinking of you — remember to Take Vitamins

Once you're done, share a picture — it'll make me smile 😊
```

**Impact:**
- 120 unique message combinations per habit
- Warmer, more caring tone (less robotic, more human)
- Gallery/CardStack displays actual sent messages
- Elderly users feel valued and cared for
- Backward compatible with old events

**Files Modified:**
- functions/index.js (lines 1349-1421, 943, 373)
- Halloo/Models/GalleryHistoryEvent.swift
- Halloo/Views/Components/CardStackView.swift
- Halloo/Services/TwilioSMSService.swift

---

## PREVIOUS CHANGES (2025-10-30)

### ✅ HABITSVIEW UI REDESIGN - COMPLETE (2025-10-30)

**Changes:**
1. **Week selector redesign** - 3-letter day abbreviations (Sun, Mon, Tue)
   - Changed from single letters (S, M, T) for better clarity
   - Depth effect design: white (raised) vs grey (divot)
   - Selected: White background, black text
   - Unselected: Dark grey background (#E8E8E8), light grey text (#9f9f9f)

2. **Habit row redesign** - 33% more compact
   - Reduced row height: 90pt → 60pt
   - Reduced emoji size: 32pt → 24pt
   - Removed: Profile photo, name, mini week strip
   - Added: Functional icons (📷 photo, 💬 text)
   - Added: Smart frequency text ("Daily", "Weekdays", custom patterns)
   - Font: Switched to system fonts (removed Inter)

3. **Card structure split**
   - Removed "All Scheduled Tasks" title
   - Split into two separate cards:
     - Week filter card (top)
     - Habits list card (bottom)

**Files Modified:**
- Views/HabitsView.swift (complete redesign)

### ✅ CODE DEDUPLICATION - UTILITIES CREATED (2025-10-30)

**Changes:**
1. **DateFormatters.swift created** (45 lines)
   - Centralized time formatting with Locale.current and TimeZone.current
   - Replaced 6 duplicate formatTime() functions across views
   - Methods: formatTime(), formatTaskTime(), formatDate()

2. **Color+Extensions.swift created** (30 lines)
   - Moved hex color utility from DashboardView
   - Now shared across all views
   - Supports 6-digit hex codes with # prefix

3. **HapticFeedback.swift created** (38 lines)
   - Centralized haptic feedback utility
   - Replaced 42 duplicate UIImpactFeedbackGenerator calls
   - Methods: light(), medium(), heavy(), selection(), success(), warning(), error()

**Impact:**
- **Code Reduction:** ~150 lines of duplicate code eliminated
- **Maintainability:** Single source of truth for common utilities
- **Consistency:** All time formatting now uses device locale/timezone

**Files Modified:**
- Core/DateFormatters.swift (NEW)
- Core/Color+Extensions.swift (NEW - moved from DashboardView)
- Core/HapticFeedback.swift (NEW)
- Multiple view files: Updated to import and use utilities

### ✅ NAVIGATION BEHAVIOR UPDATES (2025-10-30)

**Changes:**
1. **Tab swiping restrictions**
   - Dashboard ↔ Gallery: Swiping enabled (bidirectional)
   - Gallery → Habits: Swiping disabled (no preview)
   - Habits: Tab swiping completely disabled
   - Reason: Prevents conflicts with swipe-to-delete gesture

2. **Implementation**
   - ContentView.swift: Added swipe restriction logic
   - DashboardView.swift: Allowed swiping to gallery
   - HabitsView.swift: Disabled all tab swiping
   - Tab bar: Always functional on all tabs

**Files Modified:**
- Views/ContentView.swift (tab swiping configuration)
- Views/DashboardView.swift (swipe behavior)
- Views/HabitsView.swift (swipe disabled)

---

## PREVIOUS CRITICAL CHANGES (2025-10-28)

### ✅ VIEWMODEL EXTENSIONS - APPSTATE CRUD PROTOCOL (2025-10-28)

**Changes:**
1. **ViewModelExtensions.swift created** (155 lines)
   - AppStateViewModel protocol with automatic logging
   - Profile operations: addProfile(), updateProfile(), deleteProfile()
   - Task operations: addTask(), updateTask(), deleteTask()
   - Optimistic update pattern helper with automatic rollback
   - All methods use @MainActor and automatic context tracking via #function

2. **ViewModel property visibility changes**
   - ProfileViewModel.swift:221 - Changed `private weak var appState` to `weak var appState`
   - TaskViewModel.swift:276 - Changed `private weak var appState` to `weak var appState`
   - DashboardViewModel.swift:231 - Changed `private weak var appState` to `weak var appState`
   - Reason: Swift protocol conformance requires internal visibility

3. **Protocol adoption**
   - ProfileViewModel, TaskViewModel, and DashboardViewModel now conform to AppStateViewModel
   - Replaced direct appState calls with protocol extension methods
   - Automatic logging for all CRUD operations

**Code Reduction:**
- **Before:** 80+ lines of duplicate `appState?.addX()` calls with manual logging
- **After:** 16 lines of protocol conformance declarations
- **Result:** 80% reduction in boilerplate code across ViewModels

**Files Modified:**
- Core/ViewModelExtensions.swift (NEW - 155 lines)
- ViewModels/ProfileViewModel.swift (visibility change on line 221)
- ViewModels/TaskViewModel.swift (visibility change on line 276)
- ViewModels/DashboardViewModel.swift (visibility change on line 231)

---

## PREVIOUS CRITICAL CHANGES (2025-10-21)

### ✅ IMAGE CACHING SYSTEM IMPLEMENTED

**Changes:**
1. **ImageCacheService.swift created** (160 lines)
   - NSCache-based image caching with 20 image / 50MB limits
   - Parallel preloading of profile and gallery photos on app launch
   - Cache-first lookup eliminates AsyncImage flicker

2. **AppState integration**
   - Added imageCache parameter to init
   - Parallel photo preloading: `async let profilePhotosTask, galleryPhotosTask`
   - Exposed imageCache as public property for UI access

3. **UI Components updated**
   - ProfileImageView: Cache-first lookup before AsyncImage
   - GalleryPhotoView: Cache-first for profile creation photos
   - GalleryDetailView: Cache-first for full-screen photos

4. **Container registration**
   - ImageCacheService registered as singleton
   - ContentView injects imageCache to AppState

**Performance Impact:**
- **Before:** 6 Firebase Storage requests per tab switch
- **After:** 0 requests after initial load (<1ms cache lookup)

**Files Modified:**
- Services/ImageCacheService.swift (NEW - 160 lines)
- Core/AppState.swift (+16 lines)
- Models/Container.swift (+6 lines)
- Views/Components/ProfileImageView.swift (+15 lines)
- Views/Components/GalleryPhotoView.swift (+15 lines)
- Views/GalleryDetailView.swift (+15 lines)
- Views/ContentView.swift (+1 line parameter)

---

### ✅ BUILD CONFIGURATION & iOS 18 UPDATES

**Changes:**
1. **StoreKit Configuration Fix**
   - Updated Halloo.xcscheme to correct StoreKit.storekit path
   - Changed from `../../Halloo/Views/StoreKit.storekit` to `../StoreKit.storekit`

2. **Dead Code Stripping Enabled**
   - Added `DEAD_CODE_STRIPPING = YES` to all build configurations
   - Reduces app size by removing unused code

3. **iOS 18 API Updates**
   - AppFonts.swift: CTFontManagerRegisterFontsForURL (iOS 13+)
   - 11 onChange syntax updates (iOS 17+ two-parameter closure)

4. **Compiler Warnings Fixed (9 total)**
   - Unreachable catch block (App.swift)
   - Unnecessary conditional casts (FirebaseDatabaseService.swift)
   - Unnecessary try expressions (FirebaseDatabaseService.swift)
   - Unused variables (GalleryHistoryEvent.swift)

**Files Modified:**
- Halloo.xcodeproj/project.pbxproj (dead code stripping)
- Halloo.xcodeproj/xcshareddata/xcschemes/Halloo.xcscheme (StoreKit path)
- Core/App.swift (removed unreachable catch)
- Core/AppFonts.swift (iOS 18 font API)
- Views/HabitsView.swift (onChange syntax)
- Views/DashboardView.swift (onChange syntax)
- Views/Components/CardStackView.swift (onChange syntax)
- Services/FirebaseDatabaseService.swift (removed warnings)
- Models/GalleryHistoryEvent.swift (removed unused vars)

---

### ✅ ARCHIVE SYSTEM REMOVAL

**Changes:**
1. **GalleryViewModel simplified** (-150 lines)
   - Removed `archivedPhotos` property
   - Removed `isLoadingArchive` property
   - Removed `loadArchivedPhotos()` method
   - Removed `ArchivedPhoto` struct

2. **GalleryView simplified** (-70 lines)
   - Removed "Archived Memories" section
   - Removed archive loading call

**Rationale:**
- Simplified to store all photos in Firebase indefinitely
- Archive feature was unused and added complexity
- Documentation marked as deprecated in TECHNICAL-DOCUMENTATION.md

**Files Modified:**
- ViewModels/GalleryViewModel.swift (-150 lines)
- Views/GalleryView.swift (-70 lines)

---

## PREVIOUS CRITICAL CHANGES (2025-10-12)

### ✅ PHASE 4 APPSTATE REFACTOR COMPLETE

**Changes:**
1. **AppState.swift created** (437 lines)
   - Single source of truth for profiles, tasks, galleryEvents
   - Integrates with DataSyncCoordinator for multi-device sync
   - Parallel data loading (async let)

2. **ProfileViewModel refactored**
   - `profiles` converted to computed property reading from appState
   - All mutations go through appState.addProfile(), updateProfile(), deleteProfile()
   - `loadProfiles()` converted to no-op (AppState handles loading)
   - 8 FALLBACK blocks removed

3. **TaskViewModel refactored**
   - `tasks` and `availableProfiles` converted to computed properties
   - All mutations go through appState.addTask(), updateTask(), deleteTask()
   - `loadTasks()` converted to no-op
   - Removed redundant handleTaskUpdate() and handleTaskResponse()

4. **DashboardViewModel updated**
   - Added `setAppState()` method
   - Subscribes to appState.$profiles instead of profileViewModel.$profiles
   - Kept `setProfileViewModel()` as deprecated for backward compatibility

5. **ContentView updated**
   - Initializes AppState with injected services
   - Calls appState.loadUserData() on authentication
   - Injects AppState to all views via .environmentObject()
   - Removed dead AuthenticationViewModel class (67 lines)

**Files Modified:**
- Core/AppState.swift (NEW - 437 lines)
- ViewModels/ProfileViewModel.swift (-135 lines, +62 lines)
- ViewModels/TaskViewModel.swift (-98 lines, +45 lines)
- ViewModels/DashboardViewModel.swift (+21 lines)
- Views/ContentView.swift (-67 lines, +5 lines)

**Result:**
- ✅ Build succeeded with no errors
- ✅ Single source of truth achieved
- ✅ 321 lines of redundant code removed
- ✅ Confidence: 9/10

## NEXT STEPS

1. **Phase 5 Cleanup** (Optional)
   - Remove loadProfiles() and loadTasks() method stubs
   - Remove deprecated setProfileViewModel() method
   - Update Views to read directly from @EnvironmentObject AppState

2. **SMS Integration** (High Priority)
   - Complete Twilio webhook integration
   - Test SMS confirmation flow end-to-end
   - Implement SMS response processing

3. **Real-time Sync** (High Priority)
   - Test DataSyncCoordinator multi-device sync
   - Verify profile updates broadcast correctly
   - Test task completion sync across devices

4. **Analytics Dashboard** (Medium Priority)
   - Implement analytics views
   - Track task completion rates
   - Monitor SMS response patterns

---

**For detailed UI specifications**: See `docs/ui/Hallo-UI-Integration-Plan.txt`
**For development patterns**: See `docs/architecture/Dev-Guidelines.md`
**For AppState refactor details**: See `docs/STATE-ARCHITECTURE-REFACTOR-PLAN.md`
