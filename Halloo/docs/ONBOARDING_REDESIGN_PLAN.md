# Onboarding Redesign Implementation Plan

**Version:** 1.1
**Created:** 2025-12-25
**Updated:** 2025-12-25
**Status:** ✅ APPROVED - Ready for Implementation
**Objective:** Transform "clinical questionnaire" into "conversational profile builder" with minimal code changes

---

## Executive Summary

This plan implements the behavioral architecture redesign proposed in the research document while prioritizing:
1. **Minimal code changes** - Leverage existing component architecture
2. **Preserve existing inputs** - Reuse `userAnswers` storage keys where possible
3. **Phased rollout** - Ship value incrementally, validate assumptions
4. **Value-First Architecture** - Establish user motivation before logistical questions

The existing architecture is well-suited for this transformation. Most changes are **copy updates** (strings/labels), not structural rewrites.

---

## Approved Flow Order (Hybrid Approach)

The following flow order has been approved. It preserves all existing steps while reordering them per the "Value-First" psychological arc:

```
PHASE 1: IDENTITY & MOTIVATION (Who + Why)
┌─────────────────────────────────────────────────────┐
│ 1.  Who For? (Mom/Dad/Both/Other)                   │
│ 2.  Name Input (NEW) - "What's their first name?"   │
│ 3.  What Matters Most? (MOVED from step 13)         │  ← North Star
│     "Peace of mind / Staying connected / Consistency"│
└─────────────────────────────────────────────────────┘

PHASE 2: OBJECTION HANDLING (Tech Fear → Promise)
┌─────────────────────────────────────────────────────┐
│ 4.  Tech Comfort + Immediate Reassurance Banner     │
│     "That's why we built Remi. No download needed." │
└─────────────────────────────────────────────────────┘

PHASE 3: PAIN AMPLIFICATION (Problem → Empathy)
┌─────────────────────────────────────────────────────┐
│ 5.  Medication Problem (info screen - $300B crisis) │
│ 6.  Current Reminders (multi-select)                │
│ 7.  Satisfaction Level                              │
│ 8.  Current Frustration                             │
│ 9.  Empathy Break (1.5s delay, sage background)     │
└─────────────────────────────────────────────────────┘

PHASE 4: CO-CREATION / IKEA EFFECT (Build the Solution)
┌─────────────────────────────────────────────────────┐
│ 10. Habit Focus (meds/water/walks/photos)           │
│ 11. Tone Selection (NEW) - "How should Remi speak?" │
│ 12. Proof Screen (40% improvement stat)             │
└─────────────────────────────────────────────────────┘

PHASE 5: LOGISTICS LAST (Dry Details)
┌─────────────────────────────────────────────────────┐
│ 13. Reminder Timing (morning/evening/etc)           │
│ 14. Reminder Frequency (MOVED from step 2)          │  ← Logistics last
└─────────────────────────────────────────────────────┘

PHASE 6: SOCIAL PROOF & CONVERSION
┌─────────────────────────────────────────────────────┐
│ 15. Notification Promise                            │
│ 16. Notification Permission                         │
│ 17. Referral Source (Doctor?)                       │
│ 18. Social Proof (reviews)                          │
│ 19. Plan Ready Teaser                               │
│ 20. Loading Plan                                    │
│ 21. Personalized Plan (with SMS preview)            │
│ 22. Auth Gate                                       │
│ 23. Free Trial Intro                                │
│ 24. Free Trial Reminder                             │
│ 25. Paywall - "Be Present, Not the Manager"         │
└─────────────────────────────────────────────────────┘
```

### Key Changes from Current Flow

| Change | Rationale |
|--------|-----------|
| Name Input added at step 2 | Personalization over logistics; treat parent as person immediately |
| What Matters moved to step 3 | Value-First; establish WHY before asking HOW |
| Tech Comfort + Promise at step 4 | Raise objection, then squash it immediately |
| Frequency moved to step 14 | Logistics Last; dry details after emotional buy-in |
| Tone Selection added at step 11 | IKEA Effect; user "builds" the bot's personality |
| Paywall copy: "Be Present, Not the Manager" | Gender-neutral, identity-based value prop |

---

## Current Architecture Analysis

### Strengths (Leverage These)
| Component | Why It Works |
|-----------|--------------|
| `userAnswers: [String: String]` dictionary | Flexible key-value storage; new questions just add keys |
| `OnboardingStep` enum | Easy to add/reorder steps; flow controlled in one place |
| `QuizOptionButton` / `QuizMultiSelectButton` | Reusable; copy changes don't require new components |
| `OnboardingStepContainer` | Consistent layout wrapper; no changes needed |
| Dynamic name interpolation | Already uses `recipientName` in views |

### Existing Data Keys (Preserve These)
```swift
// Current keys - DO NOT CHANGE (backwards compatibility)
userAnswers["who_to_help"]           // "👩 Mom", "👨 Dad", etc.
userAnswers["reminder_frequency"]    // "🔔 Often", etc.
userAnswers["tech_comfort"]          // "Very comfortable with tech", etc.
userAnswers["current_reminders"]     // Multi-select, comma-separated
userAnswers["satisfaction_level"]    // "Pretty well - I like my system", etc.
userAnswers["current_frustration"]   // "I forget to remind them", etc.
userAnswers["reminder_timing"]       // "Morning routine", etc.
userAnswers["what_matters_most"]     // From step5WhatMatters
userAnswers["referral_source"]       // "Yes" / "No"
selectedMoments: Set<String>         // Habit selections
```

### New Keys to Add
```swift
// NEW keys for redesign
userAnswers["loved_one_name"]        // Text input: "Mary", "Dad", etc.
userAnswers["remi_tone"]             // "warm", "polite", "direct", "playful"
userAnswers["support_level"]         // Replaces frequency with softer framing
```

---

## Phased Implementation

### Phase 1: Copy-Only Changes (LOW RISK)
**Effort:** ~2-3 hours
**Files Changed:** `OnboardingQuizSteps.swift` only
**Risk:** Minimal - no structural changes

Update question text and option labels to conversational tone:

| Step | Current Copy | New Copy |
|------|-------------|----------|
| Step 1 | "Who would you like to help with Remi?" | "Let's build a support circle. Who are we caring for today?" |
| Step 1 subtitle | "We'll use this to generate your custom plan" | "We'll tailor Remi's voice to fit their specific needs." |
| Step 2 | "How often do they need reminders?" | "How much support does [Name] need right now?" |
| Step 2 options | "🔔 Often" / "⏰ As needed" / "🌿 Rarely" | "Full Support" / "Daily Routine" / "Light Touch" |
| Step 4a | "How comfortable are [name] with technology?" | "How does [Name] feel about technology?" |
| Step 4 (reminders) | "What type of reminders do you currently use?" | "How are you currently managing [Name]'s routine?" |
| Step 4b | "How well is this working for you?" | Keep same (this is good) |
| Step 5a | "What frustrates you most about your current system?" | "What's the hardest part about that for you?" |
| Habit Focus | "What would you like to remind [name] about?" | "Let's design [Name]'s healthy day. What habits should we support?" |

**Implementation:**
```swift
// Example: Step1View.swift change
// BEFORE:
Text("Who would you like to help with Remi?")

// AFTER:
Text("Let's build a support circle. Who are we caring for today?")
```

---

### Phase 2: Name Collection Step (MEDIUM RISK)
**Effort:** ~1-2 hours
**Files Changed:** `OnboardingQuizSteps.swift`, `OnboardingViewModel.swift`
**Risk:** Low - adds new step, doesn't modify existing

#### 2.1 Add Name Input Step

Insert new step after Step 1 (Who For):

```swift
// NEW: Add to OnboardingQuizSteps.swift
struct NameInputStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var name: String = ""
    @State private var showContent = false

    var body: some View {
        OnboardingStepContainer(
            progress: $viewModel.progress,
            onBack: viewModel.previousStep,
            showProgressBar: viewModel.showsProgressBar
        ) {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Text("What's their first name?")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(-1.0)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)

                    TextField("Enter name", text: $name)
                        .font(.system(size: 20))
                        .textFieldStyle(.plain)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .padding(.horizontal, OnboardingUI.horizontalPadding)

                Spacer()

                OnboardingNextButton(
                    isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty,
                    action: {
                        viewModel.userAnswers["loved_one_name"] = name
                        viewModel.nextStep()
                    }
                )
            }
        }
        .onAppear {
            if let saved = viewModel.userAnswers["loved_one_name"], !saved.isEmpty {
                name = saved
            }
        }
    }
}
```

#### 2.2 Add Step to Enum

```swift
// OnboardingViewModel.swift - Add to OnboardingStep enum
enum OnboardingStep: String, CaseIterable {
    case welcome
    case step1WhoFor
    case nameInput           // NEW
    case step2ReminderFrequency
    // ... rest unchanged
}
```

#### 2.3 Update Flow Navigation

```swift
// OnboardingViewModel.swift - Update nextStep() and previousStep()
case .step1WhoFor:
    currentStep = .nameInput  // NEW: Go to name input

case .nameInput:              // NEW
    currentStep = .step2ReminderFrequency
```

#### 2.4 Use Name Throughout

All existing views already have `recipientName` computed property:
```swift
private var recipientName: String {
    viewModel.userAnswers["loved_one_name"] ?? "them"
}
```

Just ensure this is used in all headers.

---

### Phase 3: Enhanced Empathy Break (LOW RISK)
**Effort:** ~1 hour
**Files Changed:** `OnboardingQuizSteps.swift`
**Risk:** Minimal - visual changes only

#### 3.1 Add Delayed Button Appearance

```swift
// EmpathyBreakView - Update to add 1.5s delay on button
struct EmpathyBreakView: View {
    @State private var showButton = false  // NEW

    // In body, update button:
    OnboardingNextButton(...)
        .opacity(showButton ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: showButton)

    // In onAppear:
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showButton = true  // 1.5s delay per research doc
        }
    }
}
```

#### 3.2 Update Background Color

```swift
// Add to OnboardingUI constants
static let empathyBreakBackground = Color(hex: "E8F5E9")  // Sage green

// In EmpathyBreakView, wrap content:
.background(OnboardingUI.empathyBreakBackground)
```

---

### Phase 4: Tech Comfort Immediate Reassurance (MEDIUM RISK)
**Effort:** ~1-2 hours
**Files Changed:** `OnboardingQuizSteps.swift`
**Risk:** Low - adds conditional UI element

When user selects "Not tech-savvy" or "Prefers simple solutions", show immediate reassurance:

```swift
// Step4aTechComfortView - Add reassurance banner
@State private var showReassurance = false

// After option selection:
.onChange(of: selectedComfort) { _, newValue in
    if newValue == "Prefers simple solutions" || newValue == "Not tech-savvy at all" {
        withAnimation(.spring()) {
            showReassurance = true
        }
    } else {
        showReassurance = false
    }
}

// Add banner below options:
if showReassurance {
    HStack(spacing: 12) {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(OnboardingUI.successGreen)
        Text("That's exactly why we built Remi. \(recipientName) won't need to download anything.")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.black)
    }
    .padding()
    .background(Color.green.opacity(0.1))
    .cornerRadius(12)
    .transition(.move(edge: .bottom).combined(with: .opacity))
}
```

---

### Phase 5: Remi Tone Selection Step (MEDIUM RISK)
**Effort:** ~2-3 hours
**Files Changed:** `OnboardingQuizSteps.swift`, `OnboardingViewModel.swift`
**Risk:** Medium - new step with preview functionality

#### 5.1 Add Tone Selection View

```swift
struct ToneSelectionView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var selectedTone: String? = nil

    let toneOptions = [
        ("Polite & Respectful", "Good morning, [Name]. It's time for your medication.", "polite"),
        ("Warm & Cheerful", "Hi [Name]! Hope you're having a lovely day. Don't forget your water!", "warm"),
        ("Direct & Short", "Reminder: Take 2pm pills.", "direct"),
        ("Fun & Playful", "Ready to rock the day, [Name]? Time for a walk!", "playful")
    ]

    private var recipientName: String {
        viewModel.userAnswers["loved_one_name"] ?? "Mom"
    }

    var body: some View {
        OnboardingStepContainer(...) {
            VStack(spacing: 24) {
                Text("How should Remi speak to \(recipientName)?")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-1.0)

                ForEach(toneOptions, id: \.2) { option in
                    ToneOptionCard(
                        title: option.0,
                        preview: option.1.replacingOccurrences(of: "[Name]", with: recipientName),
                        isSelected: selectedTone == option.2,
                        onTap: { selectedTone = option.2 }
                    )
                }
            }

            OnboardingNextButton(
                isEnabled: selectedTone != nil,
                action: {
                    viewModel.userAnswers["remi_tone"] = selectedTone ?? "warm"
                    viewModel.nextStep()
                }
            )
        }
    }
}

struct ToneOptionCard: View {
    let title: String
    let preview: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)

                // SMS bubble preview
                HStack {
                    Text(preview)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                    Spacer()
                }
            }
            .padding()
            .background(isSelected ? Color.black.opacity(0.05) : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.black : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
    }
}
```

#### 5.2 Insert into Flow

Place after Habit Focus (step4HabitFocus), before Proof Screen:

```swift
// OnboardingStep enum
case step4HabitFocus
case toneSelection        // NEW
case step3bProofScreen

// nextStep()
case .step4HabitFocus:
    currentStep = .toneSelection
case .toneSelection:
    currentStep = .step3bProofScreen
```

---

### Phase 6: Flow Reorder (MEDIUM RISK) - ✅ APPROVED
**Effort:** ~2-3 hours
**Files Changed:** `OnboardingViewModel.swift`
**Risk:** Medium - significant reordering, but no data model changes

Implement the approved hybrid flow order. Key changes to `nextStep()` and `previousStep()`:

```swift
// OnboardingViewModel.swift - New flow order
enum OnboardingStep: String, CaseIterable {
    case welcome

    // PHASE 1: Identity & Motivation
    case step1WhoFor
    case nameInput                    // NEW
    case step5WhatMatters             // MOVED from step 13

    // PHASE 2: Objection Handling
    case step4aTechComfort            // Shows reassurance banner

    // PHASE 3: Pain Amplification
    case step3MedicationProblem
    case step4CurrentReminders
    case step4bSatisfaction
    case step5aCurrentFrustration
    case empathyBreak

    // PHASE 4: Co-Creation
    case step4HabitFocus
    case toneSelection                // NEW
    case step3bProofScreen

    // PHASE 5: Logistics Last
    case reminderTiming
    case step2ReminderFrequency       // MOVED from step 2

    // PHASE 6: Social Proof & Conversion
    case step6NotificationPromise
    case notificationPermission
    case referralSource
    case step7SocialProof
    case planReadyTeaser
    case loadingPlan
    case personalizedPlan
    case saveYourProgress
    case freeTrialIntro
    case freeTrialReminder
    case step6Paywall
    case profileSetupConfirmation
    case preferences
}
```

Update `nextStep()` to follow this order, and `previousStep()` to reverse it.

---

### Phase 7: Paywall Copy Updates (LOW RISK)
**Effort:** ~30 minutes
**Files Changed:** Superwall dashboard or local paywall view
**Risk:** Minimal - copy change only

Update paywall headline (gender-neutral):
- **Current:** "Choose Your Plan" / "Start your personalized memory plan"
- **New:** "Be Present, Not the Manager" / "Let Remi handle the logistics for less than a coffee."

This is gender-neutral and focuses on identity transformation rather than product features.

---

### Phase 8: Personalized Plan Preview Enhancement (MEDIUM RISK)
**Effort:** ~2-3 hours
**Files Changed:** `OnboardingQuizSteps.swift` (PersonalizedPlanView)
**Risk:** Medium - UI enhancement

Add SMS preview mockup using collected data:

```swift
// In PersonalizedPlanView, add iPhone mockup:
struct SMSPreviewMockup: View {
    let recipientName: String
    let tone: String
    let userName: String  // From auth or "Sarah"

    var messageText: String {
        switch tone {
        case "warm":
            return "Hi \(recipientName)! Just a friendly reminder to take your heart meds. Love, \(userName) & Remi"
        case "direct":
            return "Reminder: Time for your medication."
        default:
            return "Good morning, \(recipientName). It's time for your medication."
        }
    }

    var body: some View {
        // iPhone frame with SMS bubble
        VStack {
            // Message header
            Text("Messages")
                .font(.system(size: 12, weight: .semibold))

            // SMS bubble
            HStack {
                Text(messageText)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(16)
                Spacer()
            }
            .padding()
        }
        .frame(width: 280)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 10)
    }
}
```

---

## Implementation Priority Matrix

| Phase | Impact | Effort | Risk | Priority |
|-------|--------|--------|------|----------|
| 6. Flow Reorder | **Critical** | Medium | Medium | **P0 - Do First** |
| 1. Copy-Only Changes | High | Low | Low | **P0 - Do First** |
| 2. Name Collection | High | Medium | Low | **P0 - Do First** |
| 5. Tone Selection | High | Medium | Medium | **P0 - Do First** |
| 3. Enhanced Empathy Break | Medium | Low | Low | **P1** |
| 4. Tech Reassurance | Medium | Low | Low | **P1** |
| 7. Paywall Copy | Medium | Low | Low | **P1** |
| 8. SMS Preview | Medium | Medium | Medium | **P2** |

### P0 Bundle (Ship Together)
These four changes are interdependent and should ship as one release:
1. **Flow Reorder** - New psychological arc
2. **Copy Changes** - Conversational tone throughout
3. **Name Input** - Required for personalization in later steps
4. **Tone Selection** - IKEA Effect; core to the redesign

### Recommended Implementation Order
```
1. Update OnboardingStep enum with new order + new cases
2. Update nextStep() / previousStep() navigation
3. Add NameInputStepView
4. Add ToneSelectionView
5. Update all copy strings
6. Update progress bar calculation
7. Test full flow end-to-end
```

---

## Migration & Backwards Compatibility

### User Data Migration
**No migration required.** The `userAnswers` dictionary is additive:
- Existing keys remain unchanged
- New keys (`loved_one_name`, `remi_tone`) are simply added
- Old user data continues to work

### Analytics Considerations
New events to track:
```swift
// New analytics events
Analytics.log("onboarding_name_entered", properties: ["has_name": true])
Analytics.log("onboarding_tone_selected", properties: ["tone": selectedTone])
Analytics.log("onboarding_tech_reassurance_shown", properties: ["comfort_level": selectedComfort])
```

---

## Testing Checklist

### Phase 1 (Copy Changes)
- [ ] All question text displays correctly
- [ ] No truncation on smaller devices
- [ ] Accessibility labels updated
- [ ] Existing answer storage still works

### Phase 2 (Name Input)
- [ ] Name input accepts text
- [ ] Name persists across app restart
- [ ] Name appears in subsequent steps
- [ ] Empty name shows "them" fallback
- [ ] Back navigation works correctly

### Phase 3-4 (Empathy & Reassurance)
- [ ] Empathy break button delays 1.5s
- [ ] Tech reassurance banner animates in
- [ ] Banner dismisses if user changes selection

### Phase 5 (Tone Selection)
- [ ] All 4 tone options render
- [ ] SMS preview shows recipient name
- [ ] Selection persists
- [ ] Tone stored in userAnswers

---

## Files to Modify (Summary)

| File | Phases | Type of Change |
|------|--------|----------------|
| `OnboardingQuizSteps.swift` | 1, 2, 3, 4, 5, 8 | Copy, new views, UI enhancements |
| `OnboardingViewModel.swift` | 2, 5, 6 | New enum cases, flow navigation |
| `OnboardingComponents.swift` | 3 | New color constant |
| `OnboardingContainerView.swift` | 2, 5 | Route new steps |
| Superwall Dashboard | 7 | Paywall copy |

---

## Resolved Decisions

| Question | Decision | Rationale |
|----------|----------|-----------|
| Name Input Placement | After "Who For" (step 2) | Personalization over logistics |
| Flow Reorder | Hybrid approach approved | Preserves existing steps, adopts Value-First arc |
| Paywall Copy | "Be Present, Not the Manager" | Gender-neutral, identity-focused |

## Open Questions (P1/P2)

1. **Tone Selection Scope:** Should tone selection affect actual SMS templates in production, or is it for perceived personalization only (IKEA Effect)?

2. **Empathy Break Duration:** Is 1.5s button delay optimal, or should we A/B test 1.0s vs 2.0s?

3. **Option Labels:** Should we keep emojis in option labels (current) or remove them for more professional tone?

---

## Success Metrics

| Metric | Current Baseline | Target |
|--------|-----------------|--------|
| Quiz Completion Rate | TBD | +15% |
| Empathy Break Drop-off | TBD | <5% |
| Free Trial Conversion | TBD | +10% |
| Day 1 Retention | TBD | +5% |

---

## Next Steps

### Immediate (P0 Bundle)
1. ✅ Plan approved - ready for implementation
2. Create feature branch: `feature/onboarding-redesign-v2`
3. Implement in order:
   - Flow reorder (enum + navigation)
   - Name input step
   - Tone selection step
   - Copy updates
   - Progress bar recalculation
4. Test full flow on device
5. Ship and measure

### Follow-up (P1)
- Enhanced empathy break (1.5s delay, sage background)
- Tech reassurance banner
- Paywall copy update in Superwall

### Later (P2)
- SMS preview in personalized plan screen
- A/B testing infrastructure
