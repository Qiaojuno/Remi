# Legal Documents Setup - Privacy Policy & Terms and Conditions

**Date:** November 7, 2025
**Status:** ✅ Complete and Deployed

---

## Overview

Privacy Policy and Terms & Conditions are now hosted on Firebase Hosting and accessible from the app's Settings screen. This meets Apple App Store requirements for legal documentation.

---

## What Was Set Up

### 1. Firebase Hosting Configuration ✅

**File:** `/firebase.json`
- Added `hosting` configuration
- Public directory: `/public`
- Emulator port: 5000

### 2. Legal Documents Created ✅

**Files Created:**
- `/public/privacy.md` - Privacy Policy (markdown source)
- `/public/terms.md` - Terms and Conditions (markdown source)
- `/public/privacy.html` - Privacy Policy (web version)
- `/public/terms.html` - Terms & Conditions (web version)
- `/public/index.html` - Landing page with links to both documents

**Content:**
- Comprehensive privacy policy covering data collection, usage, storage, and user rights
- Terms and Conditions covering acceptable use, subscriptions, disclaimers, and legal terms
- Based on your original detailed markdown content

### 3. iOS App Integration ✅

**Files Modified:**
- `/Halloo/Views/Components/SharedHeaderSection.swift`
  - Added Privacy Policy and Terms & Conditions menu items to Settings
  - Added state management for document presentation

**Files Created:**
- `/Halloo/Views/Components/LegalDocumentView.swift`
  - SafariViewController wrapper for displaying legal documents
  - Enum for document types (privacy, terms)
  - Custom header matching app design

### 4. Deployment ✅

**Hosting URL:** https://remi-ios-9ad1c.web.app

**Deployed Pages:**
- Privacy Policy: https://remi-ios-9ad1c.web.app/privacy.html
- Terms & Conditions: https://remi-ios-9ad1c.web.app/terms.html
- Index: https://remi-ios-9ad1c.web.app/index.html

---

## How It Works

### User Flow:
1. User opens Settings from the app header (person icon)
2. User taps "Privacy Policy" or "Terms & Conditions"
3. App opens Safari View Controller with the Firebase-hosted document
4. User can read, scroll, and go back to Settings

### Technical Implementation:
- Legal documents are hosted on Firebase Hosting (free, fast CDN)
- App uses `SFSafariViewController` to display documents (Apple recommended approach)
- Documents are styled with responsive CSS matching app design
- Back navigation returns to Settings seamlessly

---

## What You Need to Update

### Before App Store Submission:

1. **Replace Placeholder Email Addresses:**
   - `/public/privacy.md` - Replace `[YOUR EMAIL ADDRESS]` with your support email
   - `/public/terms.md` - Replace `[YOUR EMAIL ADDRESS]` with your support email

2. **Replace Placeholder Business Information:**
   - `/public/terms.md` - Replace `[YOUR BUSINESS NAME]` with your company/LLC name
   - `/public/terms.md` - Replace `[YOUR JURISDICTION]` with your province/state (e.g., "British Columbia, Canada")
   - `/public/privacy.md` - Replace `[YOUR EMAIL ADDRESS]` in Contact section

3. **Add Subscription Pricing (if applicable):**
   - `/public/terms.md` - Section 7.1 - Add your actual subscription tiers and prices

4. **Redeploy After Updates:**
   ```bash
   cd /Users/nich/Desktop/Halloo/public
   node convert-md.js  # Regenerate HTML from markdown
   cd ..
   firebase deploy --only hosting  # Deploy to Firebase
   ```

---

## App Store Requirements Met ✅

### Required for App Store Approval:

1. ✅ **Privacy Policy URL** - Accessible in app and for App Store Connect
2. ✅ **Terms of Service URL** - Required for subscription apps
3. ✅ **Accessible from Settings** - Users can easily find legal documents
4. ✅ **Hosted Externally** - Firebase Hosting provides public URLs
5. ✅ **GDPR/CCPA Compliance** - Privacy policy covers data rights

### App Store Connect Submission:

When submitting to App Store Connect, you'll need to provide:
- **Privacy Policy URL:** https://remi-ios-9ad1c.web.app/privacy.html
- **Terms of Service URL:** https://remi-ios-9ad1c.web.app/terms.html
- **Support URL (optional):** https://remi-ios-9ad1c.web.app

---

## Files Structure

```
Halloo/
├── firebase.json (updated with hosting config)
├── public/ (new)
│   ├── index.html (landing page)
│   ├── privacy.md (source markdown)
│   ├── privacy.html (deployed version)
│   ├── terms.md (source markdown)
│   ├── terms.html (deployed version)
│   ├── convert-md.js (markdown → HTML converter)
│   ├── package.json
│   └── node_modules/
├── Halloo/
│   └── Views/
│       └── Components/
│           ├── SharedHeaderSection.swift (updated)
│           └── LegalDocumentView.swift (new)
└── LEGAL_DOCUMENTS_SETUP.md (this file)
```

---

## Maintenance

### Updating Legal Documents:

1. Edit the markdown files:
   - `/public/privacy.md`
   - `/public/terms.md`

2. Regenerate HTML:
   ```bash
   cd /Users/nich/Desktop/Halloo/public
   node convert-md.js
   ```

3. Deploy updates:
   ```bash
   cd /Users/nich/Desktop/Halloo
   firebase deploy --only hosting
   ```

4. No app update required! Legal documents are hosted externally and update immediately.

### Testing:

**Local Testing (Emulator):**
```bash
firebase emulators:start --only hosting
# Visit: http://localhost:5000
```

**Production Testing:**
- Visit: https://remi-ios-9ad1c.web.app
- Test links in iOS app Settings

---

## Notes

- **Firebase Hosting is FREE** for your usage level (no costs expected)
- **No app update required** when you update legal documents (they're hosted externally)
- **Version History:** Firebase Hosting keeps deployment history (can rollback if needed)
- **CDN:** Documents are served via Google's CDN (fast worldwide)
- **SSL/HTTPS:** Automatically provided by Firebase Hosting

---

## Next Steps

1. ✅ Complete - Firebase Hosting configured and deployed
2. ✅ Complete - Legal documents created and accessible in app
3. ⏳ **TODO:** Replace placeholder emails and business info before App Store submission
4. ⏳ **TODO:** Have legal counsel review Privacy Policy and Terms & Conditions (recommended)
5. ⏳ **TODO:** Add URLs to App Store Connect when submitting for review

---

**Questions?** Contact Firebase Support or Apple Developer Support for guidance on legal document requirements.
