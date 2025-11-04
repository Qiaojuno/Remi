import Foundation

// MARK: - Gallery History Event Model
struct GalleryHistoryEvent: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let profileId: String
    let eventType: GalleryEventType
    let createdAt: Date
    let eventData: GalleryEventData
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        profileId: String,
        eventType: GalleryEventType,
        createdAt: Date = Date(),
        eventData: GalleryEventData
    ) {
        self.id = id
        self.userId = userId
        self.profileId = profileId
        self.eventType = eventType
        self.createdAt = createdAt
        self.eventData = eventData
    }
}

// MARK: - Gallery Event Type
enum GalleryEventType: String, CaseIterable, Codable {
    case taskResponse = "taskResponse"
    case profileCreated = "profileCreated"
    
    var displayName: String {
        switch self {
        case .taskResponse:
            return "Task Completed"
        case .profileCreated:
            return "Profile Created"
        }
    }
    
    var icon: String {
        switch self {
        case .taskResponse:
            return "checkmark.circle.fill"
        case .profileCreated:
            return "person.badge.plus"
        }
    }
}

// MARK: - Gallery Event Data
enum GalleryEventData: Codable, Hashable {
    case taskResponse(SMSResponseData)
    case profileCreated(ProfileCreatedData)
    
    struct SMSResponseData: Codable, Hashable, Equatable {
        let taskId: String?
        let textResponse: String?
        let photoData: Data?
        let responseType: String // Store as String to avoid enum issues
        let taskTitle: String?
        let sentMessage: String? // The original sent message from family to elderly

        init(from smsResponse: SMSResponse) {
            self.taskId = smsResponse.taskId
            self.textResponse = smsResponse.textResponse
            self.photoData = smsResponse.photoData
            self.responseType = smsResponse.responseType.rawValue
            self.taskTitle = smsResponse.taskTitle
            self.sentMessage = nil // SMS responses don't have sent message
        }

        init(taskId: String?, textResponse: String?, photoData: Data?, responseType: String, taskTitle: String?, sentMessage: String? = nil) {
            self.taskId = taskId
            self.textResponse = textResponse
            self.photoData = photoData
            self.responseType = responseType
            self.taskTitle = taskTitle
            self.sentMessage = sentMessage
        }

        // Implement Equatable
        static func == (lhs: SMSResponseData, rhs: SMSResponseData) -> Bool {
            return lhs.taskId == rhs.taskId &&
                   lhs.textResponse == rhs.textResponse &&
                   lhs.photoData == rhs.photoData &&
                   lhs.responseType == rhs.responseType &&
                   lhs.taskTitle == rhs.taskTitle &&
                   lhs.sentMessage == rhs.sentMessage
        }

        // Implement Hashable
        func hash(into hasher: inout Hasher) {
            hasher.combine(taskId)
            hasher.combine(textResponse)
            hasher.combine(photoData)
            hasher.combine(responseType)
            hasher.combine(taskTitle)
            hasher.combine(sentMessage)
        }
    }
    
    struct ProfileCreatedData: Codable, Hashable {
        let profileName: String
        let relationship: String
        let photoURL: String?
        let profileSlot: Int
        
        init(profile: ElderlyProfile, profileSlot: Int) {
            self.profileName = profile.name
            self.relationship = profile.relationship
            self.photoURL = profile.photoURL
            self.profileSlot = profileSlot
        }
        
        init(profileName: String, relationship: String, photoURL: String?, profileSlot: Int) {
            self.profileName = profileName
            self.relationship = relationship
            self.photoURL = photoURL
            self.profileSlot = profileSlot
        }
    }
}

// MARK: - Gallery History Event Extensions
extension GalleryHistoryEvent {
    var profileName: String {
        switch eventData {
        case .taskResponse(_):
            // This would need to be populated from profile lookup
            return "Profile"
        case .profileCreated(let data):
            return data.profileName
        }
    }
    
    var profileSlot: Int {
        switch eventData {
        case .taskResponse(_):
            // This would need to be calculated based on profile lookup
            return 0
        case .profileCreated(let data):
            return data.profileSlot
        }
    }
    
    var hasPhoto: Bool {
        switch eventData {
        case .taskResponse(let data):
            return data.photoData != nil
        case .profileCreated(let data):
            return data.photoURL != nil
        }
    }
    
    var hasTextResponse: Bool {
        switch eventData {
        case .taskResponse(let data):
            return data.textResponse?.isEmpty == false
        case .profileCreated(_):
            return false
        }
    }
    
    var textResponse: String? {
        switch eventData {
        case .taskResponse(let data):
            return data.textResponse
        case .profileCreated(_):
            return nil
        }
    }

    var sentMessage: String? {
        switch eventData {
        case .taskResponse(let data):
            return data.sentMessage
        case .profileCreated(_):
            return nil
        }
    }

    var originalTaskTitle: String {
        switch eventData {
        case .taskResponse(let data):
            return data.taskTitle ?? "Task reminder"
        case .profileCreated(_):
            return ""
        }
    }
    
    var photoURL: String? {
        switch eventData {
        case .taskResponse(_):
            return nil // SMS responses store photoData, not URLs
        case .profileCreated(let data):
            return data.photoURL
        }
    }
    
    var photoData: Data? {
        switch eventData {
        case .taskResponse(let data):
            return data.photoData
        case .profileCreated(_):
            return nil // Profile photos use URLs
        }
    }
    
    var title: String {
        switch eventData {
        case .taskResponse(let data):
            return data.taskTitle ?? "Task Completed"
        case .profileCreated(let data):
            return "\(data.profileName) joined"
        }
    }
    
    var subtitle: String {
        switch eventData {
        case .taskResponse(let data):
            if let text = data.textResponse, !text.isEmpty {
                return text
            } else if data.photoData != nil {
                return "Photo response"
            } else {
                return "Task completed"
            }
        case .profileCreated(let data):
            return data.relationship
        }
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var responseMethod: String {
        switch eventData {
        case .taskResponse:
            // Default to SMS if no specific type
            return "With SMS"
        case .profileCreated:
            return "With SMS"
        }
    }

    // Create gallery event from SMS response
    static func fromSMSResponse(
        _ response: SMSResponse,
        profileSlot: Int? = nil
    ) -> GalleryHistoryEvent {
        return GalleryHistoryEvent(
            id: response.id,
            userId: response.userId,
            profileId: response.profileId ?? "",
            eventType: .taskResponse,
            createdAt: response.receivedAt,
            eventData: .taskResponse(GalleryEventData.SMSResponseData(from: response))
        )
    }
    
    // Create gallery event from profile creation
    static func fromProfileCreation(
        userId: String,
        profile: ElderlyProfile,
        profileSlot: Int
    ) -> GalleryHistoryEvent {
        return GalleryHistoryEvent(
            userId: userId,
            profileId: profile.id,
            eventType: .profileCreated,
            createdAt: profile.confirmedAt ?? profile.createdAt,
            eventData: .profileCreated(GalleryEventData.ProfileCreatedData(
                profile: profile,
                profileSlot: profileSlot
            ))
        )
    }
}

// Note: ResponseType is already defined in SMSResponse.swift - removed duplicate declaration