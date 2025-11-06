# Hallo iOS App - Development Guidelines & Patterns
# Last Updated: 2025-11-06
# Critical patterns and fixes for future development

## RECENT LESSONS LEARNED (2025-11-06)

### Image Privacy Pattern - EXIF Metadata Stripping

**Critical Pattern:** Always strip EXIF metadata from photos before uploading to protect user privacy

**Problem:** Photos contain sensitive metadata
```swift
// ❌ WRONG - Uploads photo with GPS, device info, timestamps
let photoData = image.jpegData(compressionQuality: 0.8)
uploadToFirebase(photoData)

// User's photo now contains:
// - GPS coordinates (home address)
// - Device model (iPhone 14 Pro)
// - Timestamp (activity patterns)
// - Device owner name
```

**Solution:** Use UIImage+EXIFStripping extension
```swift
// ✅ CORRECT - Strip all metadata before upload
guard let photoData = image.jpegDataWithoutEXIF(compressionQuality: 0.8) else {
    print("❌ Failed to strip EXIF metadata")
    return
}

// Safe to upload - no GPS, device info, or timestamps
try await databaseService.uploadProfilePhoto(photoData, for: profile.id, userId: profile.userId)
```

**Why This Matters:**
- **Privacy Risk**: GPS coordinates reveal home addresses of vulnerable elderly individuals
- **Security Risk**: Timestamps reveal activity patterns (when people are home/away)
- **GDPR Compliance**: Minimizes personal data collection (Article 5(1)(c) - Data Minimization)
- **Trust**: Builds confidence with privacy-conscious family members

**When to Use:**
- ✅ Profile photo creation (ProfileViews.swift)
- ✅ Profile photo updates (HabitsView.swift)
- ✅ Task response photos (future implementation)
- ✅ ANY photo uploaded to Firebase Storage

**Performance:**
- Processing time: ~50-100ms per 12MP photo
- Network savings: 60-70% file size reduction (compression + metadata removal)
- Memory overhead: Minimal (temporary graphics context)

**File Reference:** `/Halloo/Extensions/UIImage+EXIFStripping.swift`

---

## PREVIOUS LESSONS LEARNED (2025-10-30)

### Code Deduplication with Utility Files

**Critical Pattern:** Consolidate duplicate code into shared utility files in Core/ directory

**Problem:** Duplicate functions across multiple view files
```swift
// ❌ BEFORE - 6 duplicate formatTime() functions
// DashboardView.swift
func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "ha"
    return formatter.string(from: date)
}

// HabitsView.swift (duplicate)
func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "ha"
    return formatter.string(from: date)
}

// 4 more duplicates in other files...
```

**Solution:** Create shared utility in Core/
```swift
// ✅ AFTER - Single source of truth
// Core/DateFormatters.swift
struct DateFormatters {
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current      // Device locale
        formatter.timeZone = TimeZone.current  // Device timezone
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// All views import and use
let timeString = DateFormatters.formatTime(task.scheduledTime)
```

**Benefits:**
- **Code Reduction:** 6 functions → 1 utility (~60 lines eliminated)
- **Consistency:** All views use same formatting logic
- **Maintainability:** Update once, affects all views
- **Locale Support:** Respects device locale/timezone settings

### Time Formatting Pattern

**Critical Pattern:** Always use Locale.current and TimeZone.current for time formatting

```swift
// ❌ WRONG - Ignores device locale/timezone
let formatter = DateFormatter()
formatter.dateFormat = "ha"  // Hardcoded US format
return formatter.string(from: date)

// ✅ CORRECT - Respects device settings
let formatter = DateFormatter()
formatter.locale = Locale.current      // User's locale
formatter.timeZone = TimeZone.current  // User's timezone
formatter.timeStyle = .short           // Semantic style
return formatter.string(from: date)
```

**Why This Matters:**
- US users see "5:00 PM"
- European users see "17:00" (24-hour format)
- Respects user's timezone when traveling
- Accessibility: VoiceOver reads time correctly

### Haptic Feedback Pattern

**Critical Pattern:** Use centralized haptic utility for consistent feedback

```swift
// ❌ WRONG - Duplicate haptic calls (42 occurrences)
UIImpactFeedbackGenerator(style: .light).impactOccurred()
UISelectionFeedbackGenerator().selectionChanged()

// ✅ CORRECT - Semantic haptic utility
HapticFeedback.light()      // Button taps
HapticFeedback.selection()  // Picker changes
HapticFeedback.success()    // Task completion
HapticFeedback.error()      // Validation errors
```

**Common Patterns:**
- **Light impact**: Minor interactions, button taps
- **Selection**: Week selector, picker changes
- **Success**: Habit completion, successful save
- **Error**: Form validation failures

**File Reference:** `/Halloo/Core/HapticFeedback.swift`

### Navigation Swiping Restrictions

**Critical Pattern:** Disable tab swiping when view uses swipe gestures

```swift
// ❌ WRONG - Tab swiping conflicts with swipe-to-delete
HabitsView()
    .tag(2)
// User tries to swipe-to-delete habit, accidentally switches tabs

// ✅ CORRECT - Disable tab swiping on gesture-heavy views
HabitsView()
    .tag(2)
    .gesture(DragGesture())  // Blocks TabView swipe
```

**When to Disable Swiping:**
- Views with swipe-to-delete functionality
- Views with horizontal scrolling content
- Views with custom swipe gestures

**Alternative Navigation:**
- Always keep tab bar buttons functional
- Disable only swipe gestures, not taps

## PREVIOUS LESSONS LEARNED (2025-10-28)

### AppState CRUD Protocol Extensions Pattern

**Critical Pattern:** Use protocol extensions to eliminate duplicate AppState CRUD calls across ViewModels

**Problem:** Duplicate boilerplate code across ViewModels
```swift
// ❌ BEFORE - 80+ lines of duplicate code across ViewModels
class ProfileViewModel {
    weak var appState: AppState?

    func createProfile() {
        appState?.addProfile(profile)
        print("✅ [ProfileViewModel] Profile added: \(profile.name) - createProfile()")
    }
}

class TaskViewModel {
    weak var appState: AppState?

    func createTask() {
        appState?.addTask(task)
        print("✅ [TaskViewModel] Task added: \(task.title) - createTask()")
    }
}
```

**Solution:** Protocol extensions with automatic logging and context tracking
```swift
// ✅ AFTER - 16 lines of protocol conformance
protocol AppStateViewModel: AnyObject {
    var appState: AppState? { get }
}

extension AppStateViewModel {
    @MainActor
    func addProfile(_ profile: ElderlyProfile, context: String = #function) {
        appState?.addProfile(profile)
        print("✅ [\(type(of: self))] Profile added: \(profile.name) - \(context)")
    }
}

// ViewModels just conform to protocol
extension ProfileViewModel: AppStateViewModel {}
extension TaskViewModel: AppStateViewModel {}

// Usage
profileViewModel.addProfile(newProfile)  // Automatic logging with caller context
```

**Benefits:**
- **Code Reduction:** 80 lines → 16 lines (80% reduction)
- **Automatic Logging:** Context captured via `#function` macro
- **Type Safety:** Automatic ViewModel name via `type(of: self)`
- **Consistency:** All CRUD operations follow same pattern
- **Maintainability:** Single source of truth for AppState operations

**Key Features:**
1. **Automatic Context Tracking:** `context: String = #function` captures calling function name
2. **MainActor Safety:** All methods marked `@MainActor` for thread safety
3. **Optimistic Update Pattern:** Helper method for UI updates with automatic rollback
4. **Profile Operations:** addProfile(), updateProfile(), deleteProfile()
5. **Task Operations:** addTask(), updateTask(), deleteTask()

**Important Note:** Protocol conformance requires `appState` property to have internal visibility (not private)

```swift
// ❌ WRONG - Protocol conformance fails
class ProfileViewModel {
    private weak var appState: AppState?  // Too restrictive
}

// ✅ CORRECT - Internal visibility for protocol
class ProfileViewModel {
    weak var appState: AppState?  // Default internal access
}
```

**File Reference:** `/Halloo/Core/ViewModelExtensions.swift` (lines 1-154)

---

## PREVIOUS LESSONS LEARNED (2025-10-21)

### Image Caching Pattern

**Critical Pattern:** Use NSCache-based image service to eliminate AsyncImage flicker

```swift
// ❌ WRONG - AsyncImage reloads on every view appearance
AsyncImage(url: URL(string: profile.photoURL)) { image in
    image.resizable()
} placeholder: {
    ProgressView() // Shows every time user switches tabs
}

// ✅ CORRECT - Cache-first lookup for instant display
if let cachedImage = appState.imageCache.getCachedImage(for: profile.photoURL) {
    // Synchronous, no loading state
    Image(uiImage: cachedImage)
        .resizable()
} else {
    // Fallback to AsyncImage only on first load
    AsyncImage(url: URL(string: profile.photoURL)) { /* ... */ }
}
```

**Best Practices:**
- Preload images in parallel on app launch (`async let`)
- Use NSCache for automatic memory management (50MB limit)
- Provide cache-first lookup in all image views
- Keep AsyncImage as fallback for cache misses

### iOS 17+ onChange Syntax

**Critical Pattern:** Use two-parameter closure for onChange modifier

```swift
// ❌ DEPRECATED - Single parameter (iOS 14-16)
.onChange(of: selectedProfile) { newValue in
    updateView(with: newValue)
}

// ✅ CORRECT - Two parameters (iOS 17+)
.onChange(of: selectedProfile) { oldValue, newValue in
    updateView(with: newValue)
}
```

### iOS 18 Font Registration

**Critical Pattern:** Use URL-based font registration instead of deprecated API

```swift
// ❌ DEPRECATED - CTFontManagerRegisterGraphicsFont (iOS 18+)
guard let font = CGFont(provider) else { return }
CTFontManagerRegisterGraphicsFont(font, &error)

// ✅ CORRECT - CTFontManagerRegisterFontsForURL (iOS 13+)
guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: ext) else { return }
CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error)
```

## PREVIOUS LESSONS LEARNED (2025-10-03)

### Profile Creation & User Document Management

**Critical Pattern:** Always ensure user document exists before creating related entities

```swift
// ❌ WRONG - assumes user document exists
func createElderlyProfile(_ profile: ElderlyProfile) async throws {
    // ... save profile
    try await updateUserProfileCount(profile.userId) // FAILS if user doc missing
}

// ✅ CORRECT - create user document on sign-in
func signInWithGoogle() async throws -> AuthResult {
    let result = try await auth.signIn(with: credential)
    let isNewUser = result.additionalUserInfo?.isNewUser ?? false

    if isNewUser {
        // Create user document immediately
        let userData = [
            "id": user.id,
            "email": user.email,
            "profileCount": 0 // Critical for updateUserProfileCount
        ]
        try await db.collection("users").document(user.id).setData(userData)
    }
}
```

### SwiftUI ForEach ID Selection

**Critical Pattern:** Always use unique, stable identifiers for ForEach, never indices

```swift
// ❌ WRONG - using index/offset as ID
ForEach(Array(profiles.prefix(2).enumerated()), id: \.offset) { index, profile in
    ProfileView(profile: profile)
}
// Problem: SwiftUI can't track changes when array is modified

// ✅ CORRECT - using unique profile ID
ForEach(Array(profiles.prefix(2).enumerated()), id: \.element.id) { index, profile in
    ProfileView(profile: profile)
}
// SwiftUI properly tracks each profile by its unique ID
```

### ViewModel Initialization & Authentication

**Critical Pattern:** Reload data after authentication completes

```swift
// ❌ WRONG - load profiles in init (user not authenticated yet)
init(...) {
    loadProfiles() // Fails silently because user is nil
}

// ✅ CORRECT - reload after authentication
func handleSuccessfulLogin() {
    isAuthenticated = true
    profileViewModel.loadProfiles() // Now user is authenticated
}
```

### Async/Await in Profile Creation

**Critical Pattern:** Properly await async operations before dismissing views

```swift
// ❌ WRONG - dismisses before profile is saved
_Concurrency.Task {
    profileViewModel.createProfile() // Not awaited!
    try? await Task.sleep(nanoseconds: 500_000_000)
    onDismiss() // View closes before save completes
}

// ✅ CORRECT - await completion before dismiss
_Concurrency.Task {
    await profileViewModel.createProfileAsync() // Waits for completion
    onDismiss() // Only dismiss after save succeeds
}
```

## CRITICAL DEVELOPMENT PATTERNS

### Task Naming Conflicts
**Issue:** Swift naming conflicts between app Task model and Swift Concurrency Task
**Solution:** Always use `_Concurrency.Task` for Swift concurrency operations

```swift
// ❌ WRONG - causes naming conflict
Task { @MainActor in
    await someOperation()
}

// ✅ CORRECT - explicit Concurrency namespace  
_Concurrency.Task { @MainActor in
    await someOperation()
}
```

### UIKit Dependencies
**Rule:** This is a SwiftUI-only project - no UIKit imports allowed
**Alternative Patterns:**

```swift
// ❌ UIKit dependency
import UIKit
UIApplication.shared...
UIDevice.current...

// ✅ SwiftUI/Foundation alternatives
import SwiftUI
// Use SwiftUI's native components and Foundation APIs
```

### Asset Naming
**Critical:** Use exact case-sensitive names consistently

```swift
// Asset files in Xcode:
Character.imageset/Mascot.png
Bird1.imageset/Bird.png
Bird2.imageset/Bird.png

// Code references:
Image("Mascot")    // ✅ CORRECT
Image("Bird1")     // ✅ CORRECT
Image("mascot")    // ❌ WRONG - case mismatch
```

## KEY DESIGN PATTERNS

### Core Utilities (NEW 2025-10-30)

**Available Utilities:**

1. **DateFormatters** - Time/date formatting
```swift
import DateFormatters

// Format time (respects locale/timezone)
DateFormatters.formatTime(date)          // "5:00 PM" or "17:00"
DateFormatters.formatTaskTime(date)      // "5PM"
DateFormatters.formatDate(date, style: .medium)  // "Oct 30, 2025"
```

2. **Color+Extensions** - Hex color support
```swift
// Use hex colors anywhere
Color(hex: "f9f9f9")   // Background
Color(hex: "B9E3FF")   // Buttons
Color(hex: "#7A7A7A")  // Text (# prefix optional)
```

3. **HapticFeedback** - Centralized haptics
```swift
// Semantic haptic feedback
HapticFeedback.light()      // Button taps
HapticFeedback.selection()  // Picker/selector changes
HapticFeedback.success()    // Successful actions
HapticFeedback.error()      // Validation failures
HapticFeedback.warning()    // Warning states
```

**Best Practices:**
- Always use utilities instead of duplicating code
- Import at file level, not inside functions
- Prefer semantic methods over raw UIKit calls
- Keep utilities lightweight and stateless

### AppState CRUD Protocol Extensions
**File:** `/Halloo/Core/ViewModelExtensions.swift`

**Pattern:** Unified CRUD operations via protocol extensions

```swift
// 1. Define protocol
protocol AppStateViewModel: AnyObject {
    var appState: AppState? { get }
}

// 2. Add protocol extensions for operations
extension AppStateViewModel {
    @MainActor
    func addProfile(_ profile: ElderlyProfile, context: String = #function) {
        appState?.addProfile(profile)
        print("✅ [\(type(of: self))] Profile added: \(profile.name) - \(context)")
    }

    // ... other CRUD methods
}

// 3. ViewModels conform to protocol
extension ProfileViewModel: AppStateViewModel {}
extension TaskViewModel: AppStateViewModel {}

// 4. Use in ViewModels
func createProfile() async {
    addProfile(newProfile)  // Automatic logging, context tracking
}
```

**Optimistic Update Pattern:**
```swift
await optimisticUpdate(
    updatedTask,
    update: { self.updateTask(updatedTask) },
    rollback: {
        if let original = self.tasks.first(where: { $0.id == updatedTask.id }) {
            self.updateTask(original)
        }
    },
    operation: { try await self.databaseService.updateTask(updatedTask) }
)
```

**Best Practices:**
- Always use protocol extensions instead of duplicate CRUD calls
- Let `#function` macro capture context automatically
- Keep `appState` property internal (not private) for protocol conformance
- Use optimistic update pattern for better UX

### Container Dependency Injection
```swift
// Service Factory Pattern
extension Container {
    func makeDashboardViewModel() -> DashboardViewModel {
        return DashboardViewModel(
            databaseService: resolve(DatabaseServiceProtocol.self),
            analyticsService: resolve(AnalyticsServiceProtocol.self),
            authService: resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: resolve(DataSyncCoordinator.self),
            errorCoordinator: resolve(ErrorCoordinator.self)
        )
    }
}
```

### Mock Service Pattern
```swift
class MockAnalyticsService: AnalyticsServiceProtocol {
    // Return realistic mock data with proper types
    func getWeeklyAnalytics(for userId: String) async throws -> WeeklyAnalytics {
        return WeeklyAnalytics(
            userId: userId,                    // PRESERVE INPUT
            completionRate: 0.8,              // REALISTIC DATA
            dailyCompletion: [0.8, 0.9, 0.7], // MOCK ARRAY
            generatedAt: Date()               // CURRENT TIME
        )
    }
}
```

### Canvas Preview Safety
```swift
// ProfileViewModel Canvas-safe initialization
init(skipAutoLoad: Bool = false) {
    if !skipAutoLoad {
        loadProfiles() // Production behavior
    }
    // Canvas skips auto-loading
}

// Container Canvas-specific factory
func makeProfileViewModelForCanvas() -> ProfileViewModel {
    return ProfileViewModel(skipAutoLoad: true)
}
```

## COMMON VARIABLE NAMING PATTERNS

### ID Relationships
- `userId`: Links to User.id (owner of data)
- `profileId`: Links to ElderlyProfile.id (elderly person)  
- `taskId`: Links to Task.id (specific care task)
- `responseId`: Links to SMSResponse.id (SMS reply)

### Status Enums Pattern
- `ProfileStatus`: .pendingConfirmation → .confirmed → .inactive
- `TaskStatus`: .active → .paused → .completed  
- `ErrorSeverity`: .low → .medium → .high → .critical

### Date Variables
- `createdAt`: Initial creation timestamp
- `lastActiveAt`: Most recent activity
- `confirmedAt`: SMS confirmation timestamp  
- `receivedAt`: SMS response timestamp
- `scheduledTime`: When to send SMS reminder

## COMPONENT REUSABILITY PATTERNS

### Shared Components (NEW 2025-09-29)
**Rule:** Always reuse components when possible to maintain consistency

```swift
// SharedHeaderSection - Used in all main views
SharedHeaderSection(selectedProfileIndex: $selectedProfileIndex)

// FloatingPillNavigation - Unified 3-tab design
FloatingPillNavigation(selectedTab: $selectedTab, onTabTapped: nil)

// TaskRowView - Reusable task display component
TaskRowView(task: task, profile: profile, showViewButton: false, onViewButtonTapped: nil)
```

### Animation Handling
**Rule:** Disable animations for instant transitions

```swift
// Remove animations from view transitions
.animation(nil)
.transition(.identity)

// Use Transaction for navigation without animation
var transaction = Transaction()
transaction.disablesAnimations = true
withTransaction(transaction) {
    // Navigation code
}
```

### Gradient Implementation
**Pattern:** Bottom gradient for navigation visibility

```swift
LinearGradient(
    gradient: Gradient(colors: [
        Color.black.opacity(0),
        Color.black.opacity(0.15),
        Color.black.opacity(0.25)
    ]),
    startPoint: .top,
    endPoint: .bottom
)
.frame(height: 120)
.allowsHitTesting(false)
```

## FIREBASE INTEGRATION PATTERNS

### Authentication Flow
```swift
func signInWithGoogle() async throws -> AuthResult {
    // Modern iOS window management
    guard let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let presentingViewController = await windowScene.windows.first?.rootViewController else {
        throw AuthenticationError.unknownError("Unable to get root view controller")
    }
    
    // GIDSignIn.sharedInstance.signIn() with proper token handling
    // Firebase credential creation with GoogleAuthProvider
}
```

### Firestore Data Models
```swift
// Always include these fields
struct DatabaseModel: Codable {
    let id: String          // PRIMARY KEY
    let userId: String      // OWNER REFERENCE
    let createdAt: Date     // TIMESTAMP
    var updatedAt: Date     // LAST MODIFIED
}
```

## UI IMPLEMENTATION PATTERNS

### Consistent Button Styling
```swift
// Standard button implementation
Button(action: { /* action */ }) {
    Text("Button Text")
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, minHeight: 47)
        .background(Color(hex: "B9E3FF"))
        .cornerRadius(23.5) // Half of height for pill shape
}
```

### Profile Color System
```swift
// Fixed colors assigned to profile slots
private let profileColors: [Color] = [
    Color.blue.opacity(0.6),
    Color.red.opacity(0.6),
    Color.green.opacity(0.6),
    Color.purple.opacity(0.6)
]

// Profile gets color based on slot, not random
let profileColor = profileColors[profileIndex % 4]
```

### Bottom Gradient Effect
```swift
.background(
    ZStack(alignment: .bottom) {
        Color(hex: "f9f9f9")
        LinearGradient(
            gradient: Gradient(colors: [
                Color.clear,
                Color(hex: "B3B3B3")
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 451)
        .offset(y: 225)
    }
    .ignoresSafeArea()
)
```

## TESTING PATTERNS

### Mock Data Consistency
```swift
// Use consistent IDs across mock services
let mockUserId = "mock-user-1"
let mockProfileId = "mock-profile-1"
let mockTaskId = "mock-task-1"
```

### Canvas Preview Pattern
```swift
#Preview("View Name") {
    MyView()
        .inject(container: Container.makeForTesting())
        .environmentObject(mockViewModel)
}
```

## ERROR HANDLING PATTERNS

### Comprehensive Error Types
```swift
enum ServiceError: LocalizedError {
    case networkError(String)
    case authenticationRequired
    case insufficientPermissions
    case dataNotFound
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        // ... other cases
        }
    }
}
```

### Error Coordination
```swift
// Always use ErrorCoordinator for user-facing errors
errorCoordinator.handleError(error, context: "Loading profiles")
```

## PERFORMANCE OPTIMIZATIONS

### Image Loading
- Use `.resizable().scaledToFit()` for dynamic image sizing
- Lazy load images in lists with `LazyVStack`/`LazyVGrid`
- Cache profile images in memory when possible

### Data Fetching
- Use `@Published` properties for reactive updates
- Implement pagination for large data sets
- Cache frequently accessed data locally

## ACCESSIBILITY REQUIREMENTS

### Text Sizing
- Support Dynamic Type for all text
- Minimum touch target: 44x44 points
- High contrast mode support

### VoiceOver
- Add `.accessibilityLabel()` to all interactive elements
- Group related elements with `.accessibilityElement(children: .combine)`
- Provide hints for complex interactions

## BUILD ERROR RESOLUTION CHECKLIST

When encountering build errors:

1. **Check Task conflicts**: Replace `Task` with `_Concurrency.Task`
2. **Remove UIKit imports**: Use SwiftUI/Foundation alternatives
3. **Verify asset names**: Ensure exact case-sensitive matching
4. **Check protocol conformance**: Implement all required methods
5. **Verify Codable conformance**: All stored properties must be Codable
6. **Check type definitions**: Look for duplicates in protocol files
7. **Verify service dependencies**: Ensure Container can resolve all services

## DEPLOYMENT CHECKLIST

Before deploying:

1. ✅ Add GoogleService-Info.plist from Firebase Console
2. ✅ Configure bundle ID to match Firebase project
3. ✅ Install Firebase SDK via Swift Package Manager
4. ✅ Set up Twilio credentials in environment
5. ✅ Test on physical device for:
   - Camera/photo access
   - SMS functionality
   - Push notifications
   - Accessibility features
6. ✅ Deploy Firebase security rules
7. ✅ Configure Firebase indexes for queries
8. ✅ Set up Firebase Storage rules

## COMMON PITFALLS TO AVOID

1. **Don't use `Task` without namespace** - Always use `_Concurrency.Task`
2. **Don't import UIKit** - This is a pure SwiftUI project
3. **Don't hardcode colors** - Use the design system colors
4. **Don't skip protocol methods** - Implement all required protocol methods
5. **Don't use random profile colors** - Use slot-based color assignment
6. **Don't forget Canvas safety** - Use skipAutoLoad for ViewModels in previews
7. **Don't mix asset name cases** - Use exact case-sensitive names
8. **Don't upload photos without stripping EXIF** - Always use `jpegDataWithoutEXIF()` to protect user privacy

## CONFIDENCE SCORING

When implementing features, rate confidence 1-10:
- 10/10: Feature complete, tested, follows all patterns
- 8-9/10: Feature works, minor polish needed
- 6-7/10: Basic functionality, needs refinement
- Below 6/10: Needs significant work, seek clarification

Always include confidence score with "YARRR!" when confident (8+/10).

---

**For project structure**: See `Hallo-iOS-App-Structure.txt`
**For UI specifications**: See `Hallo-UI-Integration-Plan.txt`