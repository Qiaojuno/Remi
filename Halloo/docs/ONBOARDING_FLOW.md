# Onboarding Flow Architecture (v2.0)

**Last Updated:** 2025-11-12
**Status:** ✅ **ACTIVE** - Subscription-Gated Architecture
**Location:** `Halloo/Views/Onboarding/`

---

## Overview

The onboarding system provides **two entry paths** for users:
1. **Quiz Path**: Educational funnel for new users to learn about the app
2. **Login Path**: Direct authentication for returning users

**Gate:** Only **subscription status** determines app access (no onboarding completion tracking)

---

## Architecture Philosophy

### OLD System (Deprecated)
```
❌ Track onboarding completion in Firestore (isOnboardingComplete: Bool)
❌ Complex edge cases: What if user closes app mid-quiz?
❌ Required checking multiple states: quiz complete? authenticated? subscribed?
```

### NEW System (Current)
```
✅ NO Firestore tracking of onboarding state
✅ isComplete is LOCAL flag only (OnboardingViewModel)
✅ SINGLE gate: Subscription status
✅ Quiz is OPTIONAL education, not required
```

---

## Flow Architecture

```
Welcome Screen
├── Button 1: "Get Started" → Quiz Path
│   ├── Step 1: Who For?
│   ├── Step 2: Connection Frequency
│   ├── Step 3: Name & Relationship
│   ├── Step 4: Memory Vision (multi-select)
│   ├── Step 5: Emotional Hook
│   ├── Auth Gate (Apple/Google Sign-In)
│   ├── Subscription Check
│   │   ├── Has Active Subscription → Dashboard
│   │   └── Needs Subscription → Paywall
│   └── Dashboard
│
└── Button 2: "Already signed up? Log in" → Direct Login Path
    ├── Auth Gate (Apple/Google Sign-In)
    ├── Subscription Check
    │   ├── Has Active Subscription → Dashboard
    │   └── Needs Subscription → Paywall
    └── Dashboard
```

**Total Steps (Quiz Path):** 5 quiz steps + Auth + Optional Paywall
**Total Steps (Login Path):** Auth + Optional Paywall

---

## Welcome Screen

**File:** `OnboardingViews.swift` (lines 235-340)

### UI Elements
- **Card stack preview**: Interactive swipeable task cards
- **Tagline**: "Keep your parents healthy automatically"
- **Primary Button**: "Get Started" (Black, pill-shaped)
- **Secondary Button**: "Already signed up? Log in" (Text button)

### Button Actions
```swift
// Primary: Start quiz funnel
Button("Get Started") {
    viewModel.startQuiz() // → Step 1
}

// Secondary: Skip to auth
Button("Already signed up? Log in") {
    viewModel.goToLogin() // → Auth gate
}
```

---

## Quiz Path (Optional Education)

### Purpose
- Educate new users about app features
- Collect personalization data (optional)
- Build emotional connection
- NOT required to use the app

### Step 1: Who For?
**File:** `OnboardingQuizSteps.swift` (lines 17-37)
**Type:** Single-select radio buttons

**Question:** "Who are you downloading Remi for?"

**Options:**
1. My parent
2. My grandparent
3. My partner
4. Someone else I care about

**Data Stored:** `viewModel.userAnswers["who_for"] = selectedOption`

---

### Step 2: Connection Frequency
**File:** `OnboardingQuizSteps.swift` (lines 41-62)
**Type:** Single-select radio buttons

**Question:** "How often do you think about them?"

**Options:**
1. Every day
2. A few times a week
3. Once a week
4. Not as often as I'd like

**Data Stored:** `viewModel.userAnswers["connection_frequency"] = selectedOption`

---

### Step 3: Name & Relationship
**File:** `OnboardingQuizSteps.swift` (lines 66-142)
**Type:** Text input + single-select

**Questions:**
1. **Their name** (text input)
2. **Your relationship** (buttons: Mom, Dad, Grandma, Grandpa, Partner, Other)

**Data Stored:**
```swift
viewModel.userAnswers["loved_one_name"] = lovedOneName
viewModel.userAnswers["relationship"] = selectedRelationship
```

---

### Step 4: Memory Vision
**File:** `OnboardingQuizSteps.swift` (lines 146-200)
**Type:** Multi-select checkboxes

**Question:** "What kind of daily moments would you love to capture with [loved one's name]?"

**Options:**
1. ☕ Morning coffee rituals
2. 💊 Medication taken successfully
3. 📸 Photos from their day
4. 💬 Simple check-ins
5. 🍽️ Meals they're proud of
6. 🚶 Walks and activities

**Data Stored:** `viewModel.selectedMoments: Set<String>`

**Purpose:** Understand desired habit types for personalized recommendations

---

### Step 5: Emotional Hook
**File:** `OnboardingQuizSteps.swift` (lines 204-304)
**Type:** Single-select with visual grid

**Visual:** 3x4 grid of placeholder memory tiles (animated fade-in)

**Question:** "Imagine a year with [loved one's name]..."
**Subtitle:** "What would that collection mean to you?"

**Options:**
1. A priceless family treasure
2. Daily peace of mind
3. Staying close despite distance
4. Creating lasting memories

**Data Stored:** `viewModel.emotionalValue = selectedValue`

---

## Authentication Gate

**File:** `OnboardingViews.swift` (SaveYourProgressView)
**Placement:** After Step 5 (quiz) OR immediately (direct login)

### Authentication Methods
- **Sign in with Apple** (recommended)
- **Sign in with Google**

### What Happens After Auth

```swift
// OnboardingViewModel.swift: handleSuccessfulAuthentication()

if existingUser {
    // Returning user
    if user.subscriptionStatus == .active || user.isTrialActive {
        → Go to Dashboard (subscribed)
    } else {
        → Show Paywall (needs subscription)
    }
} else {
    // New user - create with 7-day trial
    User(subscriptionStatus: .trial, trialEndDate: +7 days)
    → Go to Dashboard (trial active)
}
```

**Trial:** New users get 7 days free trial automatically

---

## Subscription Check (ONLY Gate)

### Logic
```swift
// This is the ONLY check that matters
if user.subscriptionStatus == .active || user.isTrialActive {
    allowAccess = true
} else {
    showPaywall = true
}
```

### Subscription States
| Status | Access | Action |
|--------|--------|--------|
| `.trial` (within 7 days) | ✅ Full access | None |
| `.trial` (expired) | ❌ Blocked | Show paywall |
| `.active` | ✅ Full access | None |
| `.expired` | ❌ Blocked | Show paywall |
| `.cancelled` | ❌ Blocked | Show paywall |

---

## Data Model

### User Model (Firestore)
**File:** `Models/User.swift`

```swift
struct User {
    let id: String
    let email: String
    let subscriptionStatus: SubscriptionStatus  // ← ONLY gate
    let trialEndDate: Date?
    let quizAnswers: [String: String]?  // Optional - analytics only

    // ❌ REMOVED: isOnboardingComplete: Bool
}
```

### OnboardingViewModel (Local State)
**File:** `ViewModels/OnboardingViewModel.swift`

```swift
@Published var isComplete: Bool = false  // ← LOCAL flag only
@Published var userAnswers: [String: String] = [:]
@Published var selectedMoments: Set<String> = []
@Published var emotionalValue: String = ""
```

---

## Using Quiz Data (Optional Personalization)

Quiz answers are **optional** and stored in `User.quizAnswers` for analytics/personalization.

### Proposed Uses

#### 1. Personalized Habit Recommendations
```swift
if let moments = user.quizAnswers?["selected_moments"] {
    if moments.contains("Medication") {
        suggestMedicationHabit()
    }
}
```

#### 2. Personalized Messaging
```swift
let lovedOneName = user.quizAnswers?["loved_one_name"] ?? "your loved one"
"Create a reminder for \(lovedOneName)"
```

#### 3. Default Reminder Frequency
```swift
switch user.quizAnswers?["connection_frequency"] {
case "Every day":
    defaultFrequency = .daily
case "A few times a week":
    defaultFrequency = .weekly(days: [.monday, .wednesday, .friday])
default:
    defaultFrequency = .weekly(days: [.sunday])
}
```

---

## Component Architecture

### Reusable Components
**Location:** `Halloo/Views/Onboarding/OnboardingComponents.swift`

#### OnboardingUI (Constants)
```swift
enum OnboardingUI {
    static let backgroundColor = Color(hex: "f9f9f9")
    static let horizontalPadding: CGFloat = 24
    static let totalSteps = 9
}
```

#### Key Components
1. **OnboardingProgressBar** - Back button + progress bar
2. **OnboardingGradientBackground** - Off-white background with gradient
3. **OnboardingNextButton** - Responsive enabled/disabled state
4. **OnboardingStepHeader** - Title + subtitle with fade-in
5. **QuizOptionButton** - Numbered circle with success green
6. **OnboardingStepContainer** - Wraps all steps with consistent layout
7. **QuizSelectionStep** - Generic template for single-select steps

---

## Code Metrics

### Before Refactor (v1.0)
- **Tracked:** `isOnboardingComplete: Bool` in Firestore
- **Edge Cases:** 8+ conditional branches for onboarding state
- **Complexity:** High (quiz tracking + auth state + subscription state)

### After Refactor (v2.0)
- **Tracked:** Subscription status only
- **Edge Cases:** 2 conditional branches (subscribed vs not)
- **Complexity:** Low (single gate)
- **Code Reduction:** ~150 lines of conditional logic removed

---

## Migration Strategy

### For Existing Users
Old Firestore documents may still have `isOnboardingComplete: Bool` field.

**Strategy:**
- **Ignore field** during decode (not in CodingKeys)
- **Only check** subscription status going forward
- **No migration script needed** (field is benign)

### For New Users
User documents created WITHOUT `isOnboardingComplete` field:
```swift
User(
    subscriptionStatus: .trial,
    trialEndDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())
    // NO isOnboardingComplete field
)
```

---

## Key Differences from v1.0

| Aspect | OLD (v1.0) | NEW (v2.0) |
|--------|-----------|-----------|
| **Quiz Required?** | Yes (to set `isOnboardingComplete: true`) | No (optional education) |
| **Firestore Tracking** | `isOnboardingComplete: Bool` | None (subscription only) |
| **Login Button** | Hidden (showed LoginSheetView) | Prominent (skips quiz) |
| **Gate Logic** | Quiz complete? Auth? Subscribed? | Subscribed? |
| **Edge Cases** | 8+ conditional branches | 2 conditional branches |
| **Returning Users** | Must check onboarding status | Just check subscription |

---

## Testing Checklist

### Manual Testing
- [ ] Welcome screen: Both buttons render
- [ ] "Get Started": Starts quiz at Step 1
- [ ] "Log in": Skips to auth gate
- [ ] Quiz steps: All render correctly
- [ ] Auth gate: Apple/Google sign-in work
- [ ] New user: Gets 7-day trial automatically
- [ ] Returning user with trial: Goes to dashboard
- [ ] Returning user expired: Shows paywall
- [ ] Quiz data: Saves to Firestore correctly
- [ ] Direct login: Skips quiz, saves no answers

### Build Verification
```bash
xcodebuild -project Halloo.xcodeproj -scheme Halloo build -sdk iphonesimulator
```

---

## Files Reference

### Core Files
- `Halloo/Views/Onboarding/OnboardingComponents.swift` - Reusable UI components
- `Halloo/Views/Onboarding/OnboardingQuizSteps.swift` - Steps 1-5 implementation
- `Halloo/Views/OnboardingViews.swift` - Welcome, auth, confirmation views
- `Halloo/ViewModels/OnboardingViewModel.swift` - State management, navigation
- `Halloo/Models/User.swift` - User model (NO `isOnboardingComplete` field)
- `Halloo/Views/ContentView.swift` - Navigation logic

---

## Future Improvements

1. **A/B Testing**
   - Test quiz vs no-quiz conversion rates
   - Test different quiz lengths (5-step vs 3-step)
   - Measure: Subscription conversion, Day 1/7/30 retention

2. **Analytics**
   - Track quiz completion rate
   - Track skip-to-login rate
   - Track step abandonment points
   - Measure personalization impact

3. **Enhanced Personalization**
   - Use quiz answers for onboarding recommendations
   - Suggest habits based on selected moments
   - Customize SMS language based on relationship

---

**Last Reviewed:** 2025-11-12
**Next Review:** After collecting analytics from two-path system
**Architecture Version:** v2.0 (Subscription-Gated)
