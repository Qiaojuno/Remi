# OWASP MASTG Security Checklist for Halloo

**Stack:** iOS (Swift/SwiftUI), Firebase Auth/Firestore/Storage/Functions, Twilio SMS, RevenueCat + Superwall
**Sensitive Data:** Phone numbers, user photos, profile information
**Generated:** 2025-01-08 from OWASP MASTG v2

---

## Critical Priority

- [ ] **MASVS-NETWORK-1** | MASTG-TEST-0065 — Verify all Firebase/Twilio communication uses TLS 1.2+
- [ ] **MASVS-CRYPTO-2** | MASTG-TEST-0213 — No hardcoded cryptographic keys in source code
- [ ] **MASVS-CRYPTO-2** | MASTG-TEST-0214 — No API keys/secrets in bundled files (plist, json)
- [ ] **MASVS-STORAGE-1** | MASTG-TEST-0052 — Encrypt phone numbers and photos at rest using Data Protection
- [ ] **MASVS-STORAGE-1** | MASTG-TEST-0299 — Use NSFileProtectionComplete for sensitive files

---

## High Priority — Data Storage

- [ ] **MASVS-STORAGE-2** | MASTG-TEST-0053 — No phone numbers or profile data in NSLog/print statements
- [ ] **MASVS-STORAGE-2** | MASTG-TEST-0296 — Runtime verification: no sensitive data in device logs
- [ ] **MASVS-STORAGE-2** | MASTG-TEST-0297 — Static analysis: no sensitive data passed to logging APIs
- [ ] **MASVS-STORAGE-2** | MASTG-TEST-0055 — Disable autocorrection on phone number text fields (`autocorrectionDisabled()`)
- [ ] **MASVS-STORAGE-2** | MASTG-TEST-0313 — Use `.textContentType(.none)` to prevent keyboard caching
- [ ] **MASVS-STORAGE-2** | MASTG-TEST-0058 — Exclude sensitive files from iCloud/iTunes backup
- [ ] **MASVS-STORAGE-2** | MASTG-TEST-0215 — Set `isExcludedFromBackup = true` for photo cache directories
- [ ] **MASVS-STORAGE-2** | MASTG-TEST-0300 — Audit UserDefaults for sensitive data (use Keychain instead)
- [ ] **MASVS-STORAGE-2** | MASTG-TEST-0054 — Review data shared with RevenueCat/Superwall/Firebase Analytics

---

## High Priority — Network Security

- [ ] **MASVS-NETWORK-1** | MASTG-TEST-0066 — ATS enabled, no `NSAllowsArbitraryLoads` in Info.plist
- [ ] **MASVS-NETWORK-1** | MASTG-TEST-0067 — Certificate validation not bypassed in URLSession delegates
- [ ] **MASVS-NETWORK-2** | MASTG-TEST-0068 — Consider SSL pinning for Firebase endpoints (optional but recommended)

---

## High Priority — Platform Security

- [ ] **MASVS-PLATFORM-3** | MASTG-TEST-0059 — Hide sensitive views when app backgrounds (implement `scenePhase` blur)
- [ ] **MASVS-PLATFORM-3** | MASTG-TEST-0290 — Verify screenshots in app switcher don't expose phone numbers/photos
- [ ] **MASVS-PLATFORM-3** | MASTG-TEST-0057 — Mask phone numbers in UI (show `***-***-1234`)
- [ ] **MASVS-PLATFORM-1** | MASTG-TEST-0073 — Prevent sensitive data from persisting in UIPasteboard
- [ ] **MASVS-PLATFORM-1** | MASTG-TEST-0276 — Audit use of `UIPasteboard.general` for phone numbers
- [ ] **MASVS-PLATFORM-1** | MASTG-TEST-0069 — Request only necessary permissions (camera, photo library)
- [ ] **MASVS-PLATFORM-1** | MASTG-TEST-0071 — Validate UIActivityViewController excludes sensitive metadata

---

## High Priority — Authentication

- [ ] **MASVS-AUTH-2** | MASTG-TEST-0064 — If using biometrics, implement via Keychain (not LAContext alone)
- [ ] **MASVS-AUTH-2** | MASTG-TEST-0266 — Use `kSecAccessControlBiometryCurrentSet` for biometric-protected items
- [ ] **MASVS-AUTH-1** | Firebase Auth — Verify session tokens expire appropriately
- [ ] **MASVS-AUTH-1** | Firebase Auth — Implement proper sign-out (clear Keychain, local data)

---

## High Priority — Code Quality

- [ ] **MASVS-CODE-3** | MASTG-TEST-0085 — Check Firebase SDK, RevenueCat, Superwall for known CVEs
- [ ] **MASVS-CODE-4** | MASTG-TEST-0087 — Verify PIE, ARC, Stack Canaries enabled in build settings
- [ ] **MASVS-RESILIENCE-2** | MASTG-TEST-0081 — App properly signed with distribution certificate
- [ ] **MASVS-RESILIENCE-4** | MASTG-TEST-0082 — `get-task-allow` is `false` in release builds
- [ ] **MASVS-RESILIENCE-3** | MASTG-TEST-0084 — No debug print statements in release builds

---

## High Priority — Privacy

- [ ] **MASVS-PRIVACY-1** | MASTG-TEST-0281 — Privacy manifest declares RevenueCat/Superwall tracking domains
- [ ] **MASVS-PRIVACY-1** | App Store — Privacy Nutrition Label accurately reflects data collection
- [ ] **MASVS-PRIVACY-1** | ATT — Request App Tracking Transparency if using IDFA

---

## Medium Priority — Cryptography

- [ ] **MASVS-CRYPTO-1** | MASTG-TEST-0061 — Use AES-256-GCM for local encryption (not CBC without HMAC)
- [ ] **MASVS-CRYPTO-2** | MASTG-TEST-0062 — Store encryption keys in Keychain with appropriate access control
- [ ] **MASVS-CRYPTO-1** | MASTG-TEST-0063 — Use `SecRandomCopyBytes` for random number generation
- [ ] **MASVS-CRYPTO-1** | MASTG-TEST-0209 — RSA keys >= 2048 bits, AES keys >= 128 bits
- [ ] **MASVS-CRYPTO-1** | MASTG-TEST-0210 — No DES, 3DES, RC4, or MD5 for security purposes

---

## Medium Priority — Additional Platform Checks

- [ ] **MASVS-PLATFORM-1** | MASTG-TEST-0070 — Validate Universal Links (apple-app-site-association)
- [ ] **MASVS-PLATFORM-1** | MASTG-TEST-0075 — Validate custom URL scheme handlers for input injection
- [ ] **MASVS-PLATFORM-2** | MASTG-TEST-0076 — If using WKWebView, disable JavaScript if not needed
- [ ] **MASVS-CODE-2** | MASTG-TEST-0080 — Implement force-update mechanism for critical security fixes

---

## Low Priority — Anti-Tampering (Optional for Care App)

- [ ] **MASVS-RESILIENCE-1** | MASTG-TEST-0088 — Jailbreak detection (consider user experience tradeoff)
- [ ] **MASVS-RESILIENCE-3** | MASTG-TEST-0083 — Strip debug symbols in release builds
- [ ] **MASVS-RESILIENCE-3** | MASTG-TEST-0093 — Code obfuscation for subscription logic (optional)

---

## Firebase-Specific Checks

- [ ] **Firestore Rules** — Ownership validation on all document paths ✅ (verified)
- [ ] **Storage Rules** — User-scoped paths with `isOwner()` checks ✅ (fixed 2025-01-08)
- [ ] **Cloud Functions** — Validate caller identity via `context.auth`
- [ ] **Cloud Functions** — Twilio credentials in Secret Manager (not environment variables)
- [ ] **Firebase Auth** — Enable App Check for API abuse protection
- [ ] **Firebase Auth** — Review OAuth providers' token scopes

---

## RevenueCat/Superwall Checks

- [ ] **API Keys** — Public API key only in app (not secret key)
- [ ] **Entitlements** — Validate subscription status server-side for sensitive features
- [ ] **Webhooks** — If using webhooks, verify signature in Cloud Functions

---

## Quick Verification Commands

```bash
# Check for hardcoded secrets in codebase
grep -r "sk_live\|api_key\|secret" --include="*.swift" .

# Check Info.plist for ATS exceptions
plutil -p Info.plist | grep -i "arbitrary\|exception"

# Verify excluded from backup
grep -r "isExcludedFromBackup" --include="*.swift" .

# Check for print statements with sensitive context
grep -rn "print.*phone\|print.*password\|NSLog" --include="*.swift" .
```

---

**Reference:** [OWASP MASTG](https://mas.owasp.org/MASTG/) | [MASVS](https://mas.owasp.org/MASVS/)
