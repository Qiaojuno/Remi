# Firebase Cloud Functions - Twilio SMS Backend

Secure backend for handling Twilio SMS integration.

## Setup

### 1. Install Dependencies
```bash
cd functions
npm install
```

### 2. Configure Environment Variables

**For Local Development (Emulator):**
The `.env` file is already configured with your Twilio credentials.

**For Production Deployment:**
```bash
firebase functions:config:set \
  twilio.account_sid="YOUR_TWILIO_ACCOUNT_SID" \
  twilio.auth_token="YOUR_TWILIO_AUTH_TOKEN" \
  twilio.phone_number="YOUR_TWILIO_PHONE_NUMBER"
```

### 3. Deploy Functions

```bash
# Deploy to Firebase
firebase deploy --only functions
```

## Available Functions

### `sendSMS`
Sends SMS via Twilio with quota management and audit logging.

**iOS Usage:**
```swift
let functions = Functions.functions()
let sendSMS = functions.httpsCallable("sendSMS")

let data: [String: Any] = [
    "to": "+17788143739",
    "message": "Hi! Time to take your vitamins",
    "profileId": "profile-uuid",
    "messageType": "taskReminder"
]

sendSMS.call(data) { result, error in
    if let error = error {
        print("Error: \(error)")
        return
    }

    if let response = result?.data as? [String: Any] {
        print("SMS sent: \(response)")
    }
}
```

### `twilioWebhook`
Receives incoming SMS and status callbacks from Twilio.

**Twilio Configuration:**
Set this as your webhook URL in Twilio Console:
```
https://us-central1-{your-project-id}.cloudfunctions.net/twilioWebhook
```

### `cleanupOldGalleryEvents`
Automated data retention - runs daily at midnight PST.

**What it does:**
- Finds gallery events older than 90 days
- Archives photos to Cloud Storage (organized by user/profile/year/month)
- Deletes all text data and metadata from Firestore
- Runs automatically every 24 hours

**Why:**
- **Privacy**: Deletes sensitive SMS text after 3 months
- **Cost**: Reduces Firestore reads by 75% (~$1.50/user/year savings)
- **Memories**: Keeps photos forever in cheaper Cloud Storage

**Manual testing:**
```bash
curl -X POST http://localhost:5001/{your-project-id}/us-central1/manualCleanup \
  -H "Content-Type: application/json" \
  -d '{"daysOld": 7}'
```

### `manualCleanup`
HTTP endpoint for manual cleanup testing.

**Parameters:**
- `daysOld`: Number of days old events must be (default: 90)

**Usage:**
```bash
# Test with events older than 7 days
curl -X POST https://us-central1-{your-project-id}.cloudfunctions.net/manualCleanup \
  -H "Content-Type: application/json" \
  -d '{"daysOld": 7}'
```

## Local Testing

```bash
# Start emulators
firebase emulators:start

# Functions will be available at:
# http://localhost:5001/{your-project-id}/us-central1/sendSMS
```

## Security Features

- ✅ Authentication required (Firebase Auth)
- ✅ SMS quota enforcement (prevents abuse)
- ✅ E.164 phone number validation
- ✅ Audit logging (all SMS tracked in Firestore)
- ✅ Opt-out keyword handling (STOP, UNSUBSCRIBE, etc.)
- ✅ Credentials secured on server-side

## Firestore Structure

```
users/{userId}/
  └── smsLogs/{logId}       - Audit trail of all SMS
  └── profiles/{profileId}/
      └── messages/{msgId}  - Incoming SMS from elderly users
```
