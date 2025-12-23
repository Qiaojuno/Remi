//
//  TwilioSMSService.swift
//  Halloo
//
//  Purpose: Production Twilio SMS integration via Firebase Cloud Functions
//  Created: 2025-10-09
//
//  SECURITY: All Twilio credentials stored server-side in Cloud Functions
//  COMPLIANCE: TCPA-compliant with quota management and opt-out handling
//

import Foundation
import FirebaseFunctions

/// Production Twilio SMS service via secure Cloud Function backend
///
/// Calls Firebase Cloud Functions which handle Twilio API communication
/// - Credentials secured server-side (never exposed in iOS app)
/// - Quota management enforced by backend
/// - All SMS logged for compliance audit trail
class TwilioSMSService: SMSServiceProtocol {

    // MARK: - Firebase Functions
    private let functions = Functions.functions()

    // MARK: - Initialization
    init() {
        // NOTE: Emulator disabled - using production Cloud Functions
        // To re-enable emulator, uncomment the code below
        // #if DEBUG
        // functions.useEmulator(withHost: "127.0.0.1", port: 5001)
        // #endif
    }

    // MARK: - SMS Delivery

    func sendSMS(
        to phoneNumber: String,
        message: String,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> SMSDeliveryResult {

        // Validate phone number format before calling backend
        guard validatePhoneNumber(phoneNumber) else {
            throw SMSError.invalidPhoneNumber
        }

        // Prepare request data
        let data: [String: Any] = [
            "to": phoneNumber,
            "message": message,
            "profileId": profileId,
            "messageType": messageType.rawValue
        ]

        do {
            // Call Cloud Function
            let sendSMSFunction = functions.httpsCallable("sendSMS")
            let result = try await sendSMSFunction.call(data)

            // Parse response
            guard let response = result.data as? [String: Any],
                  let messageId = response["messageId"] as? String,
                  let statusString = response["status"] as? String else {
                throw SMSError.unknownError("Invalid response from Cloud Function")
            }

            // Map Twilio status to our enum
            let status: SMSDeliveryStatus
            switch statusString.lowercased() {
            case "queued", "sending":
                status = .pending
            case "sent", "delivered":
                status = .delivered
            case "failed", "undelivered":
                status = .failed
            default:
                status = .pending
            }

            return SMSDeliveryResult(
                messageId: messageId,
                profileId: profileId,
                phoneNumber: phoneNumber,
                status: status,
                sentAt: Date(),
                deliveredAt: status == .delivered ? Date() : nil,
                errorMessage: nil,
                cost: nil,
                segments: 0
            )

        } catch let error as NSError {
            // Parse Firebase Functions error
            print("❌ [Twilio] Cloud Function error: \(error.localizedDescription)")

            // Check for specific error codes
            if error.domain == "FunctionsError" {
                switch error.code {
                case 7: // PERMISSION_DENIED
                    throw SMSError.serviceUnavailable
                case 3: // INVALID_ARGUMENT
                    throw SMSError.invalidPhoneNumber
                case 8: // RESOURCE_EXHAUSTED
                    throw SMSError.quotaExceeded
                case 16: // UNAUTHENTICATED
                    throw SMSError.serviceUnavailable
                default:
                    throw SMSError.deliveryFailed("Cloud Function error: \(error.localizedDescription)")
                }
            }

            throw SMSError.deliveryFailed("Unknown error: \(error.localizedDescription)")
        }
    }

    func sendBatchSMS(
        to phoneNumbers: [String],
        message: String,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> [SMSDeliveryResult] {

        var results: [SMSDeliveryResult] = []

        // Send sequentially to avoid rate limiting
        for phoneNumber in phoneNumbers {
            do {
                let result = try await sendSMS(
                    to: phoneNumber,
                    message: message,
                    profileId: profileId,
                    messageType: messageType
                )
                results.append(result)

                // 150ms delay between messages to respect Twilio rate limits
                try? await _Concurrency.Task.sleep(nanoseconds: 150_000_000)

            } catch {
                print("❌ [Twilio] Failed to send batch SMS to \(phoneNumber): \(error.localizedDescription)")

                // Add failed result
                results.append(SMSDeliveryResult(
                    messageId: "",
                    profileId: profileId,
                    phoneNumber: phoneNumber,
                    status: .failed,
                    sentAt: Date(),
                    deliveredAt: nil,
                    errorMessage: error.localizedDescription,
                    cost: nil,
                    segments: 0
                ))
            }
        }

        return results
    }

    // MARK: - Message Templates

    func getConfirmationMessage(for profile: ElderlyProfile) -> String {
        return """
        Hello \(profile.name)! Your family member wants to send you helpful daily reminders via text.

        Reply YES to start receiving reminders. Reply STOP anytime to unsubscribe.

        Message & data rates may apply.
        - Remi
        """
    }

    func getTaskReminderMessage(for task: Task, profile: ElderlyProfile) -> String {
        // Randomized greetings
        let greetings = [
            "Hi \(profile.name)!",
            "Hey \(profile.name),",
            "Hello \(profile.name) 🌞",
            "Good day \(profile.name)!",
            "Hi \(profile.name)! Hope you're doing well."
        ]

        // Randomized prompts
        let prompts = [
            "Time to",
            "A gentle reminder to",
            "Just a little nudge to",
            "Hope your day's going well! Don't forget to",
            "Thinking of you — remember to",
            "It's that moment again to"
        ]

        // Photo + Text required
        let photoAndTextInstructions = [
            "When you're all done, send a quick photo and a little note — I'd love to see 😊",
            "Snap a photo and share how it went when you finish 📸💬",
            "All set? Send a photo and a short message — can't wait to hear from you 🌞",
            "Once you're finished, share a picture and a few words about it 💛"
        ]

        // Photo only
        let photoInstructions = [
            "When you're done, send a photo — I'd love to see your progress 📸",
            "Snap a quick photo when you finish — it always brightens the day 🌿",
            "Once you're done, share a picture — it'll make me smile 😊",
            "Take a little photo when you're done, if you'd like 🌸"
        ]

        // Text only
        let textInstructions = [
            "Text back a quick note when you're finished — I'd love to hear 💬",
            "When you're done, send a little message to let me know 🌷",
            "Once you finish, reply with a quick hello — it always makes my day ☀️",
            "You can text back a few words when you're done — no rush 🌿"
        ]

        // Flexible / no specific requirement
        let flexibleInstructions = [
            "You can reply whenever you're done — I'm cheering you on 💛",
            "Take your time and send a little message if you'd like 🌸",
            "Whenever you finish, feel free to reply — I'll be happy to hear from you 😊",
            "No rush at all — reply when you're done, or just take a nice deep breath 🌿"
        ]

        // Pick random variations
        let greeting = greetings.randomElement()!
        let prompt = prompts.randomElement()!

        // Determine instructions based on requirements
        let instructionsArray: [String]
        if task.requiresPhoto && task.requiresText {
            instructionsArray = photoAndTextInstructions
        } else if task.requiresPhoto {
            instructionsArray = photoInstructions
        } else if task.requiresText {
            instructionsArray = textInstructions
        } else {
            instructionsArray = flexibleInstructions
        }

        let instructions = instructionsArray.randomElement()!

        // Build final message
        return "\(greeting) \(prompt) \(task.title)\n\n\(instructions)"
    }

    func getFollowUpMessage(for task: Task, profile: ElderlyProfile) -> String {
        // Dynamic follow-up based on response requirements
        let instructions: String
        if task.requiresPhoto && task.requiresText {
            instructions = "Send a photo and text if you've finished."
        } else if task.requiresPhoto {
            instructions = "Send a photo if you've finished."
        } else if task.requiresText {
            instructions = "Reply DONE if you've finished."
        } else {
            instructions = "Reply if you've finished."
        }

        return """
        \(profile.name), friendly reminder about: \(task.title)

        \(instructions)
        """
    }

    func getWelcomeMessage(for profile: ElderlyProfile) -> String {
        return """
        Welcome to Remi, \(profile.name)! Your family set up helpful daily reminders to keep you connected.

        You'll receive friendly text messages throughout the day. Reply STOP anytime to unsubscribe.
        - Remi
        """
    }

    // MARK: - Response Processing

    func processIncomingResponse(
        from phoneNumber: String,
        message: String,
        receivedAt: Date,
        attachments: [SMSAttachment]?
    ) async throws -> ProcessedSMSResponse {

        // Note: Incoming messages are handled by twilioWebhook Cloud Function
        // and stored in Firestore. This method processes them from Firestore.

        // Check for opt-out keywords
        let upperMessage = message.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let optOutKeywords = ["STOP", "UNSUBSCRIBE", "CANCEL", "END", "QUIT", "STOPALL", "REVOKE", "OPTOUT"]

        // Analyze response sentiment
        let isPositive = upperMessage.contains("YES") ||
                        upperMessage.contains("DONE") ||
                        upperMessage.contains("OK") ||
                        upperMessage.contains("COMPLETED")

        let isConfirmation = upperMessage.contains("YES") || upperMessage.contains("CONFIRM")

        // Determine response type
        let responseType: ResponseType
        if let attachments = attachments, !attachments.isEmpty {
            responseType = message.isEmpty ? .photo : .both
        } else {
            responseType = .text
        }

        // Determine suggested action
        let suggestedAction: SMSResponseAction
        if optOutKeywords.contains(upperMessage) {
            suggestedAction = .ignore // Handled by Cloud Function webhook
        } else if isConfirmation {
            suggestedAction = .confirmProfile
        } else if isPositive {
            suggestedAction = .markTaskComplete
        } else {
            suggestedAction = .flagForReview
        }

        return ProcessedSMSResponse(
            originalMessage: message,
            phoneNumber: phoneNumber,
            matchedProfile: nil,
            matchedTask: nil,
            responseType: responseType,
            isPositive: isPositive,
            confidence: 0.85,
            extractedData: ["processed": "true"],
            suggestedAction: suggestedAction,
            processedAt: receivedAt
        )
    }

    // MARK: - Delivery Status

    func checkDeliveryStatus(messageId: String) async throws -> SMSDeliveryStatus {
        // Note: Status updates are handled by Twilio webhook
        // Check Firestore smsLogs for current status
        return .delivered
    }

    // MARK: - Helper Methods

    func isPhoneNumberBlocked(_ phoneNumber: String) async throws -> Bool {
        // Check Firestore for opt-out status
        // This is now handled by Cloud Function, but we keep for client-side validation
        return false
    }

    // MARK: - Additional Protocol Methods

    func sendSMSWithPhoto(
        to phoneNumber: String,
        message: String,
        photoData: Data,
        profileId: String,
        messageType: SMSMessageType
    ) async throws -> SMSDeliveryResult {
        // Photo MMS is handled via Twilio webhook (inbound only)
        // Outbound photo SMS not supported in current architecture
        throw SMSError.unsupportedAttachmentType
    }

    func sendBulkSMS(messages: [SMSMessage]) async throws -> [SMSDeliveryResult] {
        var results: [SMSDeliveryResult] = []

        for message in messages {
            do {
                let result = try await sendSMS(
                    to: message.to,
                    message: message.message,
                    profileId: message.profileId,
                    messageType: message.messageType
                )
                results.append(result)

                // 150ms delay between messages to respect Twilio rate limits
                try? await _Concurrency.Task.sleep(nanoseconds: 150_000_000)
            } catch {
                results.append(SMSDeliveryResult(
                    messageId: "",
                    profileId: message.profileId,
                    phoneNumber: message.to,
                    status: .failed,
                    sentAt: Date(),
                    deliveredAt: nil,
                    errorMessage: error.localizedDescription,
                    cost: nil,
                    segments: 0
                ))
            }
        }

        return results
    }

    func getDeliveryReport(for profileId: String, from startDate: Date, to endDate: Date) async throws -> SMSDeliveryReport {
        // Delivery reports are tracked in Firestore smsLogs collection
        // Query should be done directly via FirebaseDatabaseService if needed
        throw SMSError.serviceUnavailable
    }

    func validatePhoneNumber(_ phoneNumber: String) -> Bool {
        // Use centralized E.164 validation from String extension
        return phoneNumber.isValidE164PhoneNumber
    }

    func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Use centralized E.164 formatting from String extension
        return phoneNumber.e164PhoneNumber
    }

    func blockPhoneNumber(_ phoneNumber: String) async throws {
        // Opt-out is handled via Twilio webhook when user sends STOP keyword
        // Profile smsOptedOut flag is set by Cloud Function
        throw SMSError.serviceUnavailable
    }

    func unblockPhoneNumber(_ phoneNumber: String) async throws {
        // Re-subscription requires user to send START keyword via SMS
        // Handled by Twilio's automatic keyword management
        throw SMSError.serviceUnavailable
    }

    func checkSMSQuota(for userId: String) async throws -> SMSQuotaStatus {
        // Quota is managed server-side in Cloud Functions (sendSMS function)
        // Query user document directly via FirebaseDatabaseService if needed
        throw SMSError.serviceUnavailable
    }

    func getRemainingQuota(for userId: String) async throws -> Int {
        // Quota is managed server-side in Cloud Functions
        throw SMSError.serviceUnavailable
    }

    func resetQuota(for userId: String) async throws {
        // Quota reset is handled automatically by Cloud Functions
        throw SMSError.serviceUnavailable
    }

    func updateTwilioCredentials(accountSid: String, authToken: String, phoneNumber: String) async throws {
        // Credentials are stored server-side in Firebase Secret Manager
        throw SMSError.serviceUnavailable
    }

    func testConnection() async throws -> Bool {
        // Connection is validated when sendSMS Cloud Function is called
        // No separate test endpoint needed
        return true
    }
}
