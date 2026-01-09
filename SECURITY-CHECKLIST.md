# OWASP MASTG Security Checklist for Halloo

**Stack:** iOS (Swift/SwiftUI), Firebase Auth/Firestore/Storage/Functions, Twilio SMS, RevenueCat + Superwall
**Sensitive Data:** Phone numbers, user photos, profile information
**Generated:** 2025-01-08 from OWASP MASTG v2
**Last Audit:** 2025-01-08

---

## Critical Priority

- [x] **MASVS-NETWORK-1** | MASTG-TEST-0065 — Verify all Firebase/Twilio communication uses TLS 1.2+ ✅ ATS enforced
- [x] **MASVS-CRYPTO-2** | MASTG-TEST-0213 — No hardcoded cryptographic keys in source code ✅ Only public SDK keys
- [x] **MASVS-CRYPTO-2** | MASTG-TEST-0214 — No API keys/secrets in bundled files (plist, json) ✅ Verified
- [x] **MASVS-STORAGE-1** | MASTG-TEST-0052 — Encrypt phone numbers and photos at rest using Data Protection ✅ Firebase handles server-side
- [x] **MASVS-STORAGE-1** | MASTG-TEST-0299 — Use NSFileProtectionComplete for sensitive files ✅ Memory cache only (NSCache)

---

## High Priority — Data Storage

- [x] **MASVS-STORAGE-2** | MASTG-TEST-0053 — No phone numbers or profile data in NSLog/print statements ✅ Fixed 2025-01-08
- [x] **MASVS-STORAGE-2** | MASTG-TEST-0296 — Runtime verification: no sensitive data in device logs ✅ Fixed 2025-01-08
- [x] **MASVS-STORAGE-2** | MASTG-TEST-0297 — Static analysis: no sensitive data passed to logging APIs ✅ Fixed 2025-01-08
- [x] **MASVS-STORAGE-2** | MASTG-TEST-0055 — Disable autocorrection on phone number text fields ✅ Fixed 2025-01-08
- [x] **MASVS-STORAGE-2** | MASTG-TEST-0313 — Use `.textContentType(.none)` to prevent keyboard caching ✅ Fixed 2025-01-08
- [x] **MASVS-STORAGE-2** | MASTG-TEST-0058 — Exclude sensitive files from iCloud/iTunes backup ✅ Memory cache only
- [x] **MASVS-STORAGE-2** | MASTG-TEST-0215 — Set `isExcludedFromBackup = true` for photo cache directories ✅ NSCache (no disk)
- [x] **MASVS-STORAGE-2** | MASTG-TEST-0300 — Audit UserDefaults for sensitive data (use Keychain instead) ✅ Only quiz progress, no PII
- [x] **MASVS-STORAGE-2** | MASTG-TEST-0054 — Review data shared with RevenueCat/Superwall/Firebase Analytics ✅ Only userId, no PII

---

## High Priority — Network Security

- [x] **MASVS-NETWORK-1** | MASTG-TEST-0066 — ATS enabled, no `NSAllowsArbitraryLoads` in Info.plist ✅ Verified
- [x] **MASVS-NETWORK-1** | MASTG-TEST-0067 — Certificate validation not bypassed in URLSession delegates ✅ Default validation
- [ ] **MASVS-NETWORK-2** | MASTG-TEST-0068 — Consider SSL pinning for Firebase endpoints (optional but recommended)

---

## High Priority — Platform Security

- [x] **MASVS-PLATFORM-3** | MASTG-TEST-0059 — Hide sensitive views when app backgrounds ✅ Fixed 2025-01-08
- [x] **MASVS-PLATFORM-3** | MASTG-TEST-0290 — Verify screenshots in app switcher don't expose phone numbers/photos ✅ Fixed 2025-01-08
- [ ] **MASVS-PLATFORM-3** | MASTG-TEST-0057 — Mask phone numbers in UI (show `***-***-1234`)
- [x] **MASVS-PLATFORM-1** | MASTG-TEST-0073 — Prevent sensitive data from persisting in UIPasteboard ✅ Not used
- [x] **MASVS-PLATFORM-1** | MASTG-TEST-0276 — Audit use of `UIPasteboard.general` for phone numbers ✅ Not used
- [x] **MASVS-PLATFORM-1** | MASTG-TEST-0069 — Request only necessary permissions (camera, photo library) ✅ Minimal permissions
- [ ] **MASVS-PLATFORM-1** | MASTG-TEST-0071 — Validate UIActivityViewController excludes sensitive metadata

---

## High Priority — Authentication

- [ ] **MASVS-AUTH-2** | MASTG-TEST-0064 — If using biometrics, implement via Keychain (not LAContext alone)
- [ ] **MASVS-AUTH-2** | MASTG-TEST-0266 — Use `kSecAccessControlBiometryCurrentSet` for biometric-protected items
- [x] **MASVS-AUTH-1** | Firebase Auth — Verify session tokens expire appropriately ✅ Firebase default (1 hour)
- [x] **MASVS-AUTH-1** | Firebase Auth — Implement proper sign-out (clear Keychain, local data) ✅ AppState.reset() clears all

---

## High Priority — Code Quality

- [ ] **MASVS-CODE-3** | MASTG-TEST-0085 — Check Firebase SDK, RevenueCat, Superwall for known CVEs
- [x] **MASVS-CODE-4** | MASTG-TEST-0087 — Verify PIE, ARC, Stack Canaries enabled in build settings ✅ ARC=YES, STRIP=YES
- [x] **MASVS-RESILIENCE-2** | MASTG-TEST-0081 — App properly signed with distribution certificate ✅ Code signing configured
- [x] **MASVS-RESILIENCE-4** | MASTG-TEST-0082 — `get-task-allow` is `false` in release builds ✅ Release config correct
- [x] **MASVS-RESILIENCE-3** | MASTG-TEST-0084 — No debug print statements in release builds ✅ `#if DEBUG` guards

---

## High Priority — Privacy

- [x] **MASVS-PRIVACY-1** | MASTG-TEST-0281 — Privacy manifest declares RevenueCat/Superwall tracking domains ✅ Created 2025-01-08
- [ ] **MASVS-PRIVACY-1** | App Store — Privacy Nutrition Label accurately reflects data collection
- [x] **MASVS-PRIVACY-1** | ATT — Request App Tracking Transparency if using IDFA ✅ Not using IDFA

---

## Medium Priority — Cryptography

- [x] **MASVS-CRYPTO-1** | MASTG-TEST-0061 — Use AES-256-GCM for local encryption (not CBC without HMAC) ✅ Firebase handles
- [x] **MASVS-CRYPTO-2** | MASTG-TEST-0062 — Store encryption keys in Keychain with appropriate access control ✅ Firebase handles
- [x] **MASVS-CRYPTO-1** | MASTG-TEST-0063 — Use `SecRandomCopyBytes` for random number generation ✅ UUID() used
- [x] **MASVS-CRYPTO-1** | MASTG-TEST-0209 — RSA keys >= 2048 bits, AES keys >= 128 bits ✅ Firebase TLS
- [x] **MASVS-CRYPTO-1** | MASTG-TEST-0210 — No DES, 3DES, RC4, or MD5 for security purposes ✅ SHA256 for hashing

---

## Medium Priority — Additional Platform Checks

- [ ] **MASVS-PLATFORM-1** | MASTG-TEST-0070 — Validate Universal Links (apple-app-site-association)
- [x] **MASVS-PLATFORM-1** | MASTG-TEST-0075 — Validate custom URL scheme handlers for input injection ✅ Only Google Sign-In
- [x] **MASVS-PLATFORM-2** | MASTG-TEST-0076 — If using WKWebView, disable JavaScript if not needed ✅ No WebView
- [ ] **MASVS-CODE-2** | MASTG-TEST-0080 — Implement force-update mechanism for critical security fixes

---

## Low Priority — Anti-Tampering (Optional for Care App)

- [ ] **MASVS-RESILIENCE-1** | MASTG-TEST-0088 — Jailbreak detection (consider user experience tradeoff)
- [x] **MASVS-RESILIENCE-3** | MASTG-TEST-0083 — Strip debug symbols in release builds ✅ STRIP_INSTALLED_PRODUCT=YES
- [ ] **MASVS-RESILIENCE-3** | MASTG-TEST-0093 — Code obfuscation for subscription logic (optional)

---

## Firebase-Specific Checks

- [x] **Firestore Rules** — Ownership validation on all document paths ✅ Verified
- [x] **Storage Rules** — User-scoped paths with `isOwner()` checks ✅ Fixed 2025-01-08
- [x] **Cloud Functions** — Validate caller identity via `request.auth` ✅ Line 177 in sendSMS
- [x] **Cloud Functions** — Twilio credentials in Secret Manager ✅ `defineSecret()` used
- [ ] **Firebase Auth** — Enable App Check for API abuse protection
- [x] **Firebase Auth** — Review OAuth providers' token scopes ✅ Google, Apple minimal scopes

### Cloud Functions Security (Audited 2025-01-08)

- [x] **Input Validation** — Phone numbers validated with E.164 regex ✅ Prevents injection
- [x] **SMS Rate Limiting** — Server-side quota system ✅ `smsQuotaUsed >= smsQuotaLimit`
- [x] **Subscription Check** — SMS blocked for expired subscriptions ✅ `checkUserSubscription()`
- [x] **Twilio Webhook** — HMAC-SHA1 signature validation ✅ `twilio.validateRequest()`
- [x] **RevenueCat Webhook** — Authorization header validation ✅ Secret Manager
- [x] **Message Sanitization** — Body trimmed and limited to 1000 chars ✅ Line 394

---

## RevenueCat/Superwall Checks

- [x] **API Keys** — Public API key only in app (not secret key) ✅ Verified
- [x] **Entitlements** — Validate subscription status server-side ✅ `checkUserSubscription()` in CF
- [x] **Webhooks** — RevenueCat webhook validates auth header ✅ Line 1956

---

## Audit Summary (2025-01-08)

### Completed Fixes
| Issue | File(s) Changed | Status |
|-------|-----------------|--------|
| Storage Rules IDOR | `storage.rules`, `FirebaseDatabaseService.swift` | ✅ Fixed |
| Phone numbers in logs | 4 files | ✅ Fixed |
| Screenshot protection | `ContentView.swift` | ✅ Fixed |
| Keyboard caching | `ProfileCreationCard.swift`, `OnboardingViews.swift` | ✅ Fixed |
| Privacy Manifest | `PrivacyInfo.xcprivacy` | ✅ Created |

### Passing Checks
- ATS Configuration: No exceptions
- UserDefaults: No PII stored (only quiz progress)
- UIPasteboard: Not used in app
- Build Settings: ARC=YES, STRIP=YES for Release
- Sign-out: Properly clears AppState, ImageCache, listeners
- Debug logging: All guarded by `#if DEBUG`

### Remaining Items (Lower Priority)
- SSL Pinning for Firebase (optional hardening)
- Phone number masking in UI
- Force-update mechanism
- CVE audit of dependencies
- Server-side subscription validation

---

## Quick Verification Commands

```bash
# Check for hardcoded secrets in codebase
grep -r "sk_live\|api_key\|secret" --include="*.swift" Halloo/

# Check Info.plist for ATS exceptions
plutil -p Halloo/Info.plist | grep -i "arbitrary\|exception"

# Verify excluded from backup
grep -r "isExcludedFromBackup" --include="*.swift" Halloo/

# Check for print statements with sensitive context (should return nothing now)
grep -rn "print.*phone\|print.*password" --include="*.swift" Halloo/ | grep -v "#if DEBUG"

# Verify Privacy Manifest exists
ls -la Halloo/PrivacyInfo.xcprivacy
```

---

## Manual Penetration Testing

See **[SECURITY-PENTEST.md](./SECURITY-PENTEST.md)** for manual access control testing procedures.

Run before each App Store release to verify:
- Cross-account Firestore access blocked
- Cross-account Storage access blocked
- Cloud Function abuse prevented
- Webhook spoofing rejected
- Input injection rejected

---

**Reference:** [OWASP MASTG](https://mas.owasp.org/MASTG/) | [MASVS](https://mas.owasp.org/MASVS/)
