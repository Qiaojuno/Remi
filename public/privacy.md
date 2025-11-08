# Privacy Policy for Remi (Remi)

**Last Updated:** November 7, 2025
**Effective Date:** November 7, 2025

---

## 1. Introduction

Remi ("we," "our," or "us") is a family coordination app that helps you stay connected with elderly loved ones through automated SMS reminders and photo confirmations. This Privacy Policy explains how we collect, use, store, and protect your personal information when you use the Remi mobile application (the "App").

**Important:** Remi is designed as a reminder and coordination tool for family use. It is not a medical device, healthcare service, or medication management system. Always consult healthcare professionals for medical advice.

**Age Requirement:** You must be 18 years or older to use Remi.

---

## 2. Information We Collect

### 2.1 Information You Provide Directly

**Account Information:**
- Full name
- Email address
- Authentication credentials (when using Google Sign-In or Apple Sign-In)

**Profile Information:**
- Elderly recipient's name
- Elderly recipient's phone number (E.164 format, +1 only - US/Canada)
- Relationship to recipient
- Profile photo (optional)

**Reminder Content:**
- Reminder titles and descriptions
- Scheduled times and recurrence patterns
- Custom reminder messages

**Photos:**
- Photos uploaded by elderly recipients via SMS in response to reminders
- EXIF metadata (GPS location, device information, timestamps) is automatically stripped from all photos before storage to protect privacy

**Communications:**
- SMS message content sent to and received from elderly recipients
- Text responses from elderly recipients

### 2.2 Information Collected Automatically

**Device Information:**
- Device type and model
- Operating system version (iOS)
- App version
- Unique device identifiers (for push notifications via Firebase Cloud Messaging)
- Timezone information (for accurate reminder scheduling)

**Usage Information:**
- App feature usage
- Reminder creation and completion statistics
- Login timestamps
- Error logs and crash reports (stored in Firebase for debugging purposes)

**Push Notification Tokens:**
- Firebase Cloud Messaging (FCM) tokens for sending you app notifications

### 2.3 Information We Do NOT Collect

- We do NOT collect precise geolocation data
- We do NOT use analytics or tracking services (Firebase Analytics is disabled)
- We do NOT display advertisements (Firebase Ads is disabled)
- We do NOT collect browsing history
- We do NOT use cookies or tracking pixels

---

## 3. How We Use Your Information

We use your personal information for the following purposes:

### 3.1 Core App Functionality

**Automated Reminder System:**
- Sending scheduled SMS reminders to elderly recipients via Twilio
- Processing SMS responses (photos and text confirmations)
- Marking reminders as completed
- Creating photo gallery events

**Cloud Functions Automated Processing:**
Our system uses Firebase Cloud Functions that run automatically without human intervention to:
- Check every 1 minute for reminders that are due (within a 5-minute scheduling window)
- Send SMS reminders via Twilio when habits are scheduled
- Process incoming SMS responses via Twilio webhook
- Validate photo and text responses
- Mark tasks as completed automatically
- Recover "stuck" reminders every hour by advancing schedule dates

**Important Disclosure on Automated Decision-Making:**
These automated systems make decisions that may affect whether an elderly recipient receives a reminder. You have the right to:
- Manually override automated reminder schedules
- Pause or delete reminders at any time
- Contact us to report issues with missed reminders
- Request human review of reminder delivery problems

### 3.2 Account Management
- Authenticating your identity via Google Sign-In or Apple Sign-In
- Maintaining your account and profile information
- Sending push notifications about app activity
- Providing customer support

### 3.3 Service Improvement
- Diagnosing and fixing technical issues
- Analyzing error logs to improve app stability (no personal identifiers in logs)
- Understanding usage patterns to enhance features (aggregate data only)

### 3.4 Legal Compliance
- Complying with applicable laws and regulations
- Responding to legal requests and preventing fraud
- Enforcing our Terms of Service

---

## 4. How We Share Your Information

### 4.1 Third-Party Service Providers

We share your information with the following trusted third parties who process data on our behalf:

**Twilio Inc. (SMS Provider)**
- **Purpose:** Sending and receiving SMS messages
- **Data Shared:** Elderly recipient phone numbers, SMS message content (reminders and responses), photos sent via MMS
- **Location:** United States (US1 region - eastern United States)
- **Retention:** Twilio stores SMS message records for 13 months by default. Media (MMS photos) are automatically deleted by Twilio after 13 months.
- **Encryption:** TLS v1.2 in transit, AES encryption at rest
- **Compliance:** SOC 2 Type II certified
- **DPA:** We have a Data Processing Agreement with Twilio
- **Learn More:** https://www.twilio.com/legal/privacy

**Google Firebase (Backend Infrastructure)**
- **Purpose:** Authentication, database storage, cloud storage, cloud functions, push notifications
- **Data Shared:** All app data including profiles, reminders, photos, messages, account information
- **Services Used:**
  - Firebase Authentication (Google/Apple Sign-In)
  - Cloud Firestore (database)
  - Cloud Storage (photo storage)
  - Cloud Functions (automated reminder processing)
  - Firebase Cloud Messaging (push notifications)
- **Location:** United States (us-central1 region)
- **NOT Used:** Firebase Analytics (disabled), Firebase Crashlytics (not implemented), Firebase Performance Monitoring (not implemented)
- **Compliance:** ISO 27001, SOC 2/3, GDPR-compliant
- **Learn More:** https://firebase.google.com/support/privacy

**Apple Inc. (Sign In with Apple)**
- **Purpose:** Authentication service (if you choose Apple Sign-In)
- **Data Shared:** Apple ID, email address (optional - you can hide your email)
- **Learn More:** https://www.apple.com/legal/privacy/

**Google LLC (Google Sign-In)**
- **Purpose:** Authentication service (if you choose Google Sign-In)
- **Data Shared:** Google account email, profile name, profile photo (optional)
- **Learn More:** https://policies.google.com/privacy

### 4.2 Data We Do NOT Share

- We do NOT sell your personal information to advertisers or data brokers
- We do NOT share your data with marketing companies
- We do NOT use your data for cross-app tracking
- We do NOT share data with social media platforms (beyond authentication)

### 4.3 Legal Requirements

We may disclose your information if required by law, such as:
- In response to a valid court order or subpoena
- To protect our legal rights or defend against legal claims
- To prevent fraud or protect user safety
- In connection with a business transfer (merger, acquisition, bankruptcy)

---

## 5. Data Retention and Deletion

### 5.1 How Long We Keep Your Data

**Active Account Data:**
- Profile information: Stored until you delete the profile or your account
- Reminder history: Stored indefinitely until you delete the profile
- Completed reminders: Stored indefinitely (for historical records)

**Photos:**
- Photos uploaded by elderly recipients: **Stored indefinitely until you delete the recipient's profile or your account**
- **Important:** Once an elderly recipient sends a photo via SMS, it is stored in your Firebase account permanently until you take action to delete it

**SMS Messages:**
- SMS content stored in gallery events indefinitely until you delete them

**Deleted Accounts:**
- When you delete your account, all data is permanently deleted within 30 days

### 5.2 Account Deletion

**When You Delete Your Account:**
- All profile information is permanently deleted
- All reminders and reminder history are permanently deleted
- All photos stored in Firebase are permanently deleted
- All SMS message records in Firebase are permanently deleted
- Your authentication record is permanently deleted from Firebase Auth

**How to Delete Your Account:**
1. Contact us at [YOUR EMAIL ADDRESS]
2. We will process your deletion request within 30 days

---

## 6. Data Security

We take reasonable measures to protect your information from unauthorized access, alteration, disclosure, or destruction:

### 6.1 Technical Safeguards

**Encryption:**
- All data transmitted between the app and our servers uses HTTPS/TLS encryption
- Twilio uses TLS v1.2 for SMS transmission
- Firebase uses AES encryption for data at rest
- Cloud Storage uses Google's encryption for stored photos

**Authentication:**
- Secure OAuth 2.0 authentication via Google and Apple
- No passwords are stored in our systems (handled by Google/Apple)

**Access Controls:**
- Firebase security rules restrict data access to authenticated users
- Users can only access their own data (no cross-user data access)
- Cloud Functions use service accounts with minimal permissions

### 6.2 Data Privacy Protections

**EXIF Data:**
- We automatically strip EXIF metadata from all photos before storage
- This removes GPS location coordinates, device information, timestamps, and camera settings
- This protects the privacy and location of elderly recipients who may be vulnerable

---

## 7. Your Privacy Rights

Depending on your location, you may have the following rights:

### 7.1 Access and Portability
- **Right to Access:** You can view all your data within the app
- **Right to Data Portability:** Contact us to request a copy of your data

### 7.2 Correction and Deletion
- **Right to Correct:** You can edit profiles, reminders, and account information directly in the app
- **Right to Delete:** You can delete profiles, reminders, or your entire account at any time

### 7.3 How to Exercise Your Rights

To exercise any of these rights:
- **Email Us:** [YOUR EMAIL ADDRESS] with subject line "Privacy Rights Request"
- We will respond within 30 days of receiving your request

---

## 8. Children's Privacy

Remi is not intended for use by individuals under 18 years of age.

- We do not knowingly collect personal information from children under 18
- If you are under 18, do not use this app or provide any information to us

---

## 9. Changes to This Privacy Policy

We may update this Privacy Policy from time to time. We will notify you of changes by:
- Updating the "Last Updated" date
- Sending an in-app notification for material changes

---

## 10. Contact Us

If you have questions, concerns, or requests regarding this Privacy Policy, please contact us:

**Email:** [YOUR EMAIL ADDRESS]

---

**By using Remi, you acknowledge that you have read, understood, and agree to this Privacy Policy.**
