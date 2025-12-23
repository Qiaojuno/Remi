import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

// MARK: - Firebase Database Service
class FirebaseDatabaseService: DatabaseServiceProtocol {
    
    // MARK: - Properties
    private lazy var db: Firestore = Firestore.firestore()
    private lazy var storage: Storage = Storage.storage()
    private var listeners: [ListenerRegistration] = []
    
    // MARK: - Collection Paths (Nested Subcollections)
    /// Dynamic collection path builder for nested Firestore structure
    /// Schema: /users/{uid}/profiles/{pid}/habits/{hid} and /users/{uid}/profiles/{pid}/messages/{mid}
    private enum CollectionPath {
        case users
        case userProfiles(userId: String)
        case userGalleryEvents(userId: String)
        case profileHabits(userId: String, profileId: String)
        case profileMessages(userId: String, profileId: String)

        var path: String {
            switch self {
            case .users:
                return "users"
            case .userProfiles(let userId):
                return "users/\(userId)/profiles"
            case .userGalleryEvents(let userId):
                return "users/\(userId)/gallery_events"
            case .profileHabits(let userId, let profileId):
                return "users/\(userId)/profiles/\(profileId)/habits"
            case .profileMessages(let userId, let profileId):
                return "users/\(userId)/profiles/\(profileId)/messages"
            }
        }

        /// Returns a document reference for the given path and document ID
        func document(_ documentId: String, in db: Firestore) -> DocumentReference {
            return db.collection(path).document(documentId)
        }

        /// Returns a collection reference for the given path
        func collection(in db: Firestore) -> CollectionReference {
            return db.collection(path)
        }
    }
    
    // MARK: - User Operations
    
    func createUser(_ user: User) async throws {
        let userData = try encodeToFirestore(user)
        try await CollectionPath.users.document(user.id, in: db).setData(userData)
    }

    func getUser(_ userId: String) async throws -> User? {
        let document = try await CollectionPath.users.document(userId, in: db).getDocument()

        guard let data = document.data() else {
            return nil
        }

        return try decodeFromFirestore(data, as: User.self)
    }

    func updateUser(_ user: User) async throws {
        let userData = try encodeToFirestore(user)
        try await CollectionPath.users.document(user.id, in: db).updateData(userData)
    }
    
    func deleteUser(_ userId: String) async throws {
        // ✅ Use recursive helper for safe cascade delete
        try await deleteUserRecursively(userId)
    }
    
    // MARK: - Profile Operations
    
    func createElderlyProfile(_ profile: ElderlyProfile) async throws {
        // Check for existing profile with same phone number (DUPLICATE PREVENTION)
        let existingProfiles = try await CollectionPath.userProfiles(userId: profile.userId)
            .collection(in: db)
            .whereField("phoneNumber", isEqualTo: profile.phoneNumber)
            .getDocuments()

        if !existingProfiles.isEmpty {
            // Log details of duplicate
            print("❌ [ProfileId] DUPLICATE PHONE NUMBER - BLOCKING CREATION - newProfileId: \(profile.id), phoneNumber: \(profile.phoneNumber), existingCount: \(existingProfiles.documents.count)")

            // Get existing profile details for error message
            let firstDoc = existingProfiles.documents.first!
            let existingData = firstDoc.data()
            let existingName = existingData["name"] as? String ?? "Unknown"
            let existingId = firstDoc.documentID

            // Throw error to prevent duplicate creation
            throw DatabaseError.duplicatePhoneNumber(
                phoneNumber: profile.phoneNumber,
                existingProfileName: existingName,
                existingProfileId: existingId
            )
        }

        let profileData = try encodeToFirestore(profile)
        try await CollectionPath.userProfiles(userId: profile.userId)
            .document(profile.id, in: db)
            .setData(profileData)

        // Update user's profile count
        try await updateUserProfileCount(profile.userId)
    }

    func getElderlyProfile(_ profileId: String) async throws -> ElderlyProfile? {
        // Use collection group query to find profile across all users
        let snapshot = try await db.collectionGroup("profiles")
            .whereField("id", isEqualTo: profileId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        let data = document.data()
        return try decodeFromFirestore(data, as: ElderlyProfile.self)
    }

    func getElderlyProfiles(for userId: String) async throws -> [ElderlyProfile] {
        let snapshot = try await CollectionPath.userProfiles(userId: userId)
            .collection(in: db)
            .order(by: "createdAt")
            .getDocuments()

        let profiles = try snapshot.documents.map { document in
            let profile = try decodeFromFirestore(document.data(), as: ElderlyProfile.self)
            return profile
        }

        return profiles
    }

    func updateElderlyProfile(_ profile: ElderlyProfile) async throws {
        let profileData = try encodeToFirestore(profile)
        try await CollectionPath.userProfiles(userId: profile.userId)
            .document(profile.id, in: db)
            .updateData(profileData)
    }

    func deleteElderlyProfile(_ profileId: String, userId: String) async throws {
        // ✅ Use direct path deletion (no collection group query needed)
        try await deleteProfileRecursively(profileId, userId: userId)
    }

    func getConfirmedProfiles(for userId: String) async throws -> [ElderlyProfile] {
        let query = CollectionPath.userProfiles(userId: userId).collection(in: db)
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: "confirmed")
            .order(by: "createdAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { doc in
            try doc.data(as: ElderlyProfile.self)
        }
    }
    
    // MARK: - Gallery History Event Operations
    
    func createGalleryHistoryEvent(_ event: GalleryHistoryEvent) async throws {
        let eventData = try encodeToFirestore(event)
        try await CollectionPath.userGalleryEvents(userId: event.userId)
            .document(event.id, in: db)
            .setData(eventData)
    }

    func getGalleryHistoryEvents(for userId: String) async throws -> [GalleryHistoryEvent] {
        let snapshot = try await CollectionPath.userGalleryEvents(userId: userId)
            .collection(in: db)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)  // Limit to 50 most recent events to prevent memory issues
            .getDocuments()

        // Use compactMap with do-catch to skip corrupted events instead of failing entire load
        return snapshot.documents.compactMap { doc in
            do {
                return try doc.data(as: GalleryHistoryEvent.self)
            } catch {
                print("⚠️ [FirebaseDatabaseService] Skipping corrupted gallery event \(doc.documentID): \(error.localizedDescription)")
                return nil
            }
        }
    }
    
    // MARK: - Task/Habit Operations

    func createTask(_ task: Task) async throws {
        let taskData = try encodeToFirestore(task)
        try await CollectionPath.profileHabits(userId: task.userId, profileId: task.profileId)
            .document(task.id, in: db)
            .setData(taskData)

        // Update user's task count
        try await updateUserTaskCount(task.userId)
    }

    func getTask(_ taskId: String) async throws -> Task? {
        // Use collection group query to find task across all users/profiles
        let snapshot = try await db.collectionGroup("habits")
            .whereField("id", isEqualTo: taskId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        let data = document.data()
        return try decodeFromFirestore(data, as: Task.self)
    }

    func getProfileTasks(_ profileId: String) async throws -> [Task] {
        // Use collection group query since we don't have userId
        let snapshot = try await db.collectionGroup("habits")
            .whereField("profileId", isEqualTo: profileId)
            .order(by: "createdAt")
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }

    func getTasks(for userId: String) async throws -> [Task] {
        do {
            // Use collection group query to get all tasks for user across all profiles
            let snapshot = try await db.collectionGroup("habits")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt")
                .getDocuments()

            return try snapshot.documents.map { document in
                try decodeFromFirestore(document.data(), as: Task.self)
            }
        } catch {
            #if DEBUG
            print("❌ [FirebaseDatabaseService] Query failed: \(error.localizedDescription)")
            print("❌ [FirebaseDatabaseService] Error type: \(type(of: error))")
            #endif
            throw error
        }
    }

    func getTasks(for profileId: String, userId: String) async throws -> [Task] {
        let snapshot = try await CollectionPath.profileHabits(userId: userId, profileId: profileId)
            .collection(in: db)
            .order(by: "createdAt")
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    func getTasksScheduledFor(date: Date, userId: String) async throws -> [Task] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            // Use collection group query across all user's profiles
            let snapshot = try await db.collectionGroup("habits")
                .whereField("userId", isEqualTo: userId)
                .whereField("nextScheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("nextScheduledDate", isLessThan: Timestamp(date: endOfDay))
                .order(by: "nextScheduledDate")
                .getDocuments()

            return try snapshot.documents.map { document in
                try decodeFromFirestore(document.data(), as: Task.self)
            }
        } catch {
            #if DEBUG
            print("❌ [FirebaseDatabaseService] Scheduled habits query failed: \(error.localizedDescription)")
            #endif
            throw error
        }
    }

    func archiveTask(_ taskId: String) async throws {
        // Find task using collection group query
        let snapshot = try await db.collectionGroup("habits")
            .whereField("id", isEqualTo: taskId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            throw DatabaseError.documentNotFound
        }

        try await document.reference.updateData([
            "status": TaskStatus.archived.rawValue,
            "archivedAt": FieldValue.serverTimestamp()
        ])
    }

    func getTodaysTasks(_ userId: String) async throws -> [Task] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // Use collection group query across all user's profiles
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("nextScheduledDate", isGreaterThanOrEqualTo: Timestamp(date: today))
            .whereField("nextScheduledDate", isLessThan: Timestamp(date: tomorrow))
            .order(by: "nextScheduledDate")
            .getDocuments()

        return snapshot.documents.compactMap { document in
            do {
                return try decodeFromFirestore(document.data(), as: Task.self)
            } catch {
                print("⚠️ [FirebaseDatabaseService] Skipping corrupted task \(document.documentID): \(error.localizedDescription)")
                return nil
            }
        }
    }

    func getActiveTasks(for userId: String) async throws -> [Task] {
        // Use collection group query across all user's profiles
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: TaskStatus.active.rawValue)
            .order(by: "nextScheduledDate")
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }

    func updateTask(_ task: Task) async throws {
        let taskData = try encodeToFirestore(task)
        try await CollectionPath.profileHabits(userId: task.userId, profileId: task.profileId)
            .document(task.id, in: db)
            .updateData(taskData)
    }
    
    func deleteTask(_ taskId: String, userId: String, profileId: String) async throws {
        do {
            // Delete the task itself using the proper nested path
            let taskPath = "users/\(userId)/profiles/\(profileId)/habits/\(taskId)"
            try await db.document(taskPath).delete()

            // Note: Messages are not deleted to preserve chat history
            // Note: User task count is not updated (would require collection group query)

        } catch {
            #if DEBUG
            print("❌ [FirebaseDatabaseService] Delete failed: \(error.localizedDescription)")
            #endif
            throw error
        }
    }
    
    // MARK: - Response/Message Operations

    func createSMSResponse(_ response: SMSResponse) async throws {
        guard let profileId = response.profileId else {
            throw DatabaseError.invalidData
        }

        let responseData = try encodeToFirestore(response)
        try await CollectionPath.profileMessages(userId: response.userId, profileId: profileId)
            .document(response.id, in: db)
            .setData(responseData)
    }

    func getSMSResponse(_ responseId: String) async throws -> SMSResponse? {
        // Use collection group query to find message across all users/profiles
        let snapshot = try await db.collectionGroup("messages")
            .whereField("id", isEqualTo: responseId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            return nil
        }

        var data = document.data()
        data["id"] = document.documentID
        return try decodeFromFirestore(data, as: SMSResponse.self)
    }

    func getSMSResponses(for taskId: String) async throws -> [SMSResponse] {
        // Use collection group query since we don't have userId/profileId
        let snapshot = try await db.collectionGroup("messages")
            .whereField("taskId", isEqualTo: taskId)
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            var data = document.data()
            data["id"] = document.documentID
            return try? decodeFromFirestore(data, as: SMSResponse.self)
        }
    }

    func getSMSResponses(for profileId: String, userId: String) async throws -> [SMSResponse] {
        let snapshot = try await CollectionPath.profileMessages(userId: userId, profileId: profileId)
            .collection(in: db)
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            var data = document.data()
            data["id"] = document.documentID
            return try? decodeFromFirestore(data, as: SMSResponse.self)
        }
    }

    func getSMSResponses(for userId: String, date: Date) async throws -> [SMSResponse] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Use collection group query across all user's profiles
        let snapshot = try await db.collectionGroup("messages")
            .whereField("userId", isEqualTo: userId)
            .whereField("receivedAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("receivedAt", isLessThan: Timestamp(date: endOfDay))
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            var data = document.data()
            data["id"] = document.documentID
            return try? decodeFromFirestore(data, as: SMSResponse.self)
        }
    }

    func getRecentSMSResponses(for userId: String, limit: Int) async throws -> [SMSResponse] {
        do {
            // Use collection group query across all user's profiles
            let snapshot = try await db.collectionGroup("messages")
                .whereField("userId", isEqualTo: userId)
                .order(by: "receivedAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            return snapshot.documents.compactMap { document in
                do {
                    var data = document.data()
                    data["id"] = document.documentID
                    return try decodeFromFirestore(data, as: SMSResponse.self)
                } catch {
                    // Only log in DEBUG to avoid console spam
                    #if DEBUG
                    print("⚠️ [FirebaseDatabaseService] Skipping message \(document.documentID): \(error.localizedDescription)")
                    #endif
                    return nil
                }
            }
        } catch {
            #if DEBUG
            print("❌ [FirebaseDatabaseService] Recent messages query failed: \(error.localizedDescription)")
            #endif
            throw error
        }
    }

    func getConfirmationResponses(for profileId: String) async throws -> [SMSResponse] {
        // Use collection group query since we don't have userId
        let snapshot = try await db.collectionGroup("messages")
            .whereField("profileId", isEqualTo: profileId)
            .whereField("responseType", isEqualTo: ResponseType.text.rawValue)
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            var data = document.data()
            data["id"] = document.documentID
            return try? decodeFromFirestore(data, as: SMSResponse.self)
        }
    }

    func getCompletedResponsesWithPhotos() async throws -> [SMSResponse] {
        // Use collection group query across all users/profiles
        let snapshot = try await db.collectionGroup("messages")
            .whereField("isCompleted", isEqualTo: true)
            .whereField("responseType", in: [ResponseType.photo.rawValue, ResponseType.both.rawValue])
            .order(by: "receivedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            var data = document.data()
            data["id"] = document.documentID
            return try? decodeFromFirestore(data, as: SMSResponse.self)
        }
    }

    func updateSMSResponse(_ response: SMSResponse) async throws {
        guard let profileId = response.profileId else {
            throw DatabaseError.invalidData
        }

        let responseData = try encodeToFirestore(response)
        try await CollectionPath.profileMessages(userId: response.userId, profileId: profileId)
            .document(response.id, in: db)
            .updateData(responseData)
    }

    func deleteSMSResponse(_ responseId: String) async throws {
        // Find message using collection group query
        let snapshot = try await db.collectionGroup("messages")
            .whereField("id", isEqualTo: responseId)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            throw DatabaseError.documentNotFound
        }

        try await document.reference.delete()
    }
    
    // MARK: - Photo Storage Operations
    
    func uploadPhoto(_ photoData: Data, for responseId: String) async throws -> String {
        let storageRef = storage.reference()
        let photoRef = storageRef.child("responses/\(responseId)/photo.jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await photoRef.putDataAsync(photoData, metadata: metadata)
        let downloadURL = try await photoRef.downloadURL()

        return downloadURL.absoluteString
    }

    func uploadProfilePhoto(_ photoData: Data, for profileId: String, userId: String) async throws -> String {
        let storageRef = storage.reference()
        let photoRef = storageRef.child("users/\(userId)/profiles/\(profileId)/photo.jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await photoRef.putDataAsync(photoData, metadata: metadata)
            let downloadURL = try await photoRef.downloadURL()
            return downloadURL.absoluteString
        } catch {
            print("❌ [Storage] Profile photo upload failed (\(profileId)): \(error.localizedDescription)")
            throw error
        }
    }

    func deletePhoto(at url: String) async throws {
        let photoRef = storage.reference(forURL: url)
        try await photoRef.delete()
    }

    /// Checks if a profile photo exists in Storage and returns the download URL
    /// Used to restore missing photoURL references in Firestore
    func getProfilePhotoURL(for profileId: String, userId: String) async throws -> String? {
        let storageRef = storage.reference()
        let photoRef = storageRef.child("users/\(userId)/profiles/\(profileId)/photo.jpg")

        do {
            let downloadURL = try await photoRef.downloadURL()
            return downloadURL.absoluteString
        } catch let error as NSError {
            // Only log unexpected errors (not "object not found" which is expected)
            #if DEBUG
            if error.domain != StorageErrorDomain || error.code != StorageErrorCode.objectNotFound.rawValue {
                print("⚠️ [FirebaseDatabaseService] Photo URL fetch failed for profile \(profileId): \(error.localizedDescription)")
            }
            #endif
            return nil
        }
    }

    // MARK: - Real-time Listeners
    
    func observeUserTasks(_ userId: String) -> AnyPublisher<[Task], Error> {
        let subject = PassthroughSubject<[Task], Error>()

        // Use collection group query to observe all tasks across user's profiles
        let listener = db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .order(by: "nextScheduledDate")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                do {
                    let tasks = try documents.map { document in
                        try self.decodeFromFirestore(document.data(), as: Task.self)
                    }
                    subject.send(tasks)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }

        listeners.append(listener)
        return subject.eraseToAnyPublisher()
    }

    func observeUserProfiles(_ userId: String) -> AnyPublisher<[ElderlyProfile], Error> {
        let subject = PassthroughSubject<[ElderlyProfile], Error>()

        // Observe nested profiles collection under user
        let listener = CollectionPath.userProfiles(userId: userId)
            .collection(in: db)
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    subject.send([])
                    return
                }

                do {
                    let profiles = try documents.map { document in
                        try self.decodeFromFirestore(document.data(), as: ElderlyProfile.self)
                    }
                    subject.send(profiles)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }

        listeners.append(listener)
        return subject.eraseToAnyPublisher()
    }

    func observeUserGalleryEvents(_ userId: String) -> AnyPublisher<[GalleryHistoryEvent], Error> {
        let subject = PassthroughSubject<[GalleryHistoryEvent], Error>()

        // Observe gallery_events collection under user
        // CRITICAL: Use limit() to prevent loading all events into memory
        let listener = CollectionPath.userGalleryEvents(userId: userId)
            .collection(in: db)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)  // Only load 50 most recent events to prevent memory leak
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ [FirebaseDatabaseService] Gallery events listener error: \(error.localizedDescription)")
                    subject.send(completion: .failure(error))
                    return
                }

                guard let snapshot = snapshot else {
                    subject.send([])
                    return
                }

                // CRITICAL: Only process NEW events (documentChanges with type .added)
                // This prevents sending the entire collection on every change
                let newEvents = snapshot.documentChanges
                    .filter { $0.type == .added }  // Only new events
                    .compactMap { change -> GalleryHistoryEvent? in
                        do {
                            let event = try self.decodeFromFirestore(change.document.data(), as: GalleryHistoryEvent.self)
                            return event
                        } catch {
                            print("❌ [FirebaseDatabaseService] Failed to decode gallery event \(change.document.documentID): \(error.localizedDescription)")
                            return nil
                        }
                    }

                // Only send if we have new events
                if !newEvents.isEmpty {
                    subject.send(newEvents)
                }
            }

        listeners.append(listener)
        return subject.eraseToAnyPublisher()
    }

    /// Observes incoming SMS messages for a user across all profiles
    ///
    /// Listens to the messages subcollection across all user profiles to detect
    /// incoming SMS replies (YES confirmations, STOP keywords, task responses).
    /// Broadcasts messages via DataSyncCoordinator for real-time UI updates.
    ///
    /// - Parameter userId: Family user ID to observe messages for
    /// - Returns: Publisher that emits incoming SMS messages
    func observeIncomingSMSMessages(_ userId: String) -> AnyPublisher<SMSResponse, Error> {
        let subject = PassthroughSubject<SMSResponse, Error>()

        // Use collection group query to observe all messages across user's profiles
        // Only listen for NEW messages (direction: inbound, not yet processed)
        let listener = db.collectionGroup("messages")
            .whereField("userId", isEqualTo: userId)
            .whereField("direction", isEqualTo: "inbound")
            .order(by: "receivedAt", descending: true)
            .limit(to: 50) // Only recent messages to avoid loading history
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    let nsError = error as NSError
                    print("❌ [FirebaseDatabaseService] SMS listener error: \(error.localizedDescription)")
                    if nsError.code == 9 {
                        print("   ⚠️ FAILED_PRECONDITION: Firestore index missing or building - check Firebase Console")
                    }
                    subject.send(completion: .failure(error))
                    return
                }

                guard let snapshot = snapshot else {
                    return
                }

                // Process only NEW messages (documentChanges with type .added)
                for change in snapshot.documentChanges {
                    guard change.type == .added else { continue }

                    let data = change.document.data()
                    do {
                        // Convert Firestore message to SMSResponse
                        let smsResponse = try self.convertMessageToSMSResponse(data, documentId: change.document.documentID)
                        subject.send(smsResponse)
                    } catch {
                        print("❌ [FirebaseDatabaseService] Failed to convert SMS message \(change.document.documentID): \(error.localizedDescription)")
                    }
                }
            }

        listeners.append(listener)
        return subject.eraseToAnyPublisher()
    }

    /// Converts Firestore message document to SMSResponse model
    private func convertMessageToSMSResponse(_ data: [String: Any], documentId: String) throws -> SMSResponse {
        // Extract fields from Firestore message
        guard let _ = data["fromPhone"] as? String,
              let messageBody = data["messageBody"] as? String,
              let receivedAtTimestamp = data["receivedAt"] as? Timestamp,
              let userId = data["userId"] as? String,
              let profileId = data["profileId"] as? String else {
            throw NSError(domain: "FirebaseDatabaseService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Missing required message fields"])
        }

        _ = receivedAtTimestamp.dateValue()
        _ = data["twilioSid"] as? String
        let numMedia = data["numMedia"] as? Int ?? 0
        _ = data["isOptOut"] as? Bool ?? false

        // Determine response type (unused variable warning resolved)
        _ = numMedia > 0 ? ResponseType.photo : ResponseType.text

        // Analyze message sentiment
        let upperMessage = messageBody.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let isPositive = upperMessage.contains("YES") ||
                        upperMessage.contains("DONE") ||
                        upperMessage.contains("OK") ||
                        upperMessage.contains("COMPLETED")

        let isConfirmation = upperMessage.contains("YES") || upperMessage.contains("CONFIRM")
        let isPositiveConfirmation = isConfirmation && isPositive

        // Use factory method for confirmation responses
        return SMSResponse.createConfirmationResponse(
            profileId: profileId,
            userId: userId,
            textResponse: messageBody,
            isPositive: isPositiveConfirmation
        )
    }

    // MARK: - Analytics and Reporting
    
    func getTaskCompletionStats(for userId: String, from startDate: Date, to endDate: Date) async throws -> TaskCompletionStats {
        // Use collection group queries for nested structure
        let tasksSnapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("nextScheduledDate", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("nextScheduledDate", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()

        let completedSnapshot = try await db.collectionGroup("messages")
            .whereField("userId", isEqualTo: userId)
            .whereField("isCompleted", isEqualTo: true)
            .whereField("receivedAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("receivedAt", isLessThanOrEqualTo: Timestamp(date: endDate))
            .getDocuments()
        
        let totalTasks = tasksSnapshot.documents.count
        let completedTasks = completedSnapshot.documents.count
        let completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        
        return TaskCompletionStats(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            completionRate: completionRate,
            averageResponseTime: 0, // Placeholder
            streakCount: 0, // Placeholder
            categoryBreakdown: [:], // Placeholder
            dailyCompletion: [:], // Placeholder
            responseTypeBreakdown: [:] // Placeholder
        )
    }
    
    func getProfileAnalytics(for profileId: String, userId: String) async throws -> ProfileAnalytics {
        // Placeholder implementation
        return ProfileAnalytics(
            profileId: profileId,
            totalTasks: 0,
            completedTasks: 0,
            averageResponseTime: 0,
            lastActiveDate: nil,
            responseRate: 0,
            preferredResponseType: nil,
            bestPerformingCategory: nil,
            worstPerformingCategory: nil,
            weeklyTrend: []
        )
    }
    
    func getUserAnalytics(for userId: String) async throws -> UserAnalytics {
        // Placeholder implementation
        return UserAnalytics(
            userId: userId,
            totalProfiles: 0,
            activeProfiles: 0,
            totalTasks: 0,
            overallCompletionRate: 0,
            profileAnalytics: [],
            subscriptionUsage: SubscriptionUsage(
                planType: "trial",
                profilesUsed: 0,
                profilesLimit: 4,
                tasksCreated: 0,
                smssSent: 0,
                storageUsed: 0,
                billingPeriodStart: Date(),
                billingPeriodEnd: Date()
            ),
            generatedAt: Date()
        )
    }
    
    // MARK: - Batch Operations
    
    func batchUpdateTasks(_ tasks: [Task]) async throws {
        // Update each task individually using nested paths
        for task in tasks {
            try await updateTask(task)
        }
    }

    func batchDeleteTasks(_ taskIds: [String]) async throws {
        // Note: This method cannot be implemented without userId and profileId
        // Consider updating protocol to accept [(taskId, userId, profileId)] or Task objects
        throw DatabaseError.invalidData
    }

    func batchCreateSMSResponses(_ responses: [SMSResponse]) async throws {
        // Create each response individually using nested paths
        for response in responses {
            try await createSMSResponse(response)
        }
    }
    
    // MARK: - Search and Filtering
    
    func searchTasks(query: String, userId: String) async throws -> [Task] {
        // Use collection group query for nested structure
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        return try snapshot.documents.compactMap { document in
            let task = try decodeFromFirestore(document.data(), as: Task.self)
            return task.title.lowercased().contains(query.lowercased()) ? task : nil
        }
    }
    
    func getTasksByCategory(_ category: TaskCategory, userId: String) async throws -> [Task] {
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("category", isEqualTo: category.rawValue)
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }

    func getTasksByStatus(_ status: TaskStatus, userId: String) async throws -> [Task] {
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: status.rawValue)
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }

    func getOverdueTasks(for userId: String) async throws -> [Task] {
        let now = Date()
        let snapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .whereField("status", isEqualTo: TaskStatus.active.rawValue)
            .whereField("nextScheduledDate", isLessThan: Timestamp(date: now))
            .getDocuments()

        return try snapshot.documents.map { document in
            try decodeFromFirestore(document.data(), as: Task.self)
        }
    }
    
    // MARK: - Data Synchronization

    func syncUserData(for userId: String) async throws {
        // Placeholder implementation
    }
    
    func getLastSyncTimestamp(for userId: String) async throws -> Date? {
        let document = try await CollectionPath.users.document(userId, in: db).getDocument()
        guard let data = document.data(),
              let timestamp = data["lastSyncTimestamp"] as? Timestamp else {
            return nil
        }
        return timestamp.dateValue()
    }

    func updateSyncTimestamp(for userId: String, timestamp: Date) async throws {
        try await CollectionPath.users.document(userId, in: db).updateData([
            "lastSyncTimestamp": Timestamp(date: timestamp)
        ])
    }
    
    // MARK: - Backup and Export
    
    func exportUserData(for userId: String) async throws -> UserDataExport {
        let user = try await getUser(userId)
        let profiles = try await getElderlyProfiles(for: userId)
        let tasks = try await getTasks(for: userId)
        let responses = try await getRecentSMSResponses(for: userId, limit: 1000)
        let analytics = try await getUserAnalytics(for: userId)
        
        return UserDataExport(
            userId: userId,
            user: user ?? User(id: userId, email: "", fullName: "", phoneNumber: "", createdAt: Date(), subscriptionStatus: .trial, trialEndDate: nil, quizAnswers: nil, profileCount: 0, taskCount: 0, updatedAt: Date(), lastSyncTimestamp: nil),
            profiles: profiles,
            tasks: tasks,
            responses: responses,
            analytics: analytics
        )
    }
    
    func importUserData(_ data: UserDataExport, for userId: String) async throws {
        // Placeholder implementation
    }
    
    // MARK: - Helper Methods
    
    private func updateUserProfileCount(_ userId: String) async throws {
        // Count profiles in user's nested collection
        let profilesSnapshot = try await CollectionPath.userProfiles(userId: userId)
            .collection(in: db)
            .getDocuments()

        let profileCount = profilesSnapshot.documents.count

        // Use setData(merge: true) instead of updateData to create document if it doesn't exist
        try await CollectionPath.users.document(userId, in: db).setData([
            "profileCount": profileCount,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private func updateUserTaskCount(_ userId: String) async throws {
        // Use collection group query to count all tasks across user's profiles
        let tasksSnapshot = try await db.collectionGroup("habits")
            .whereField("userId", isEqualTo: userId)
            .getDocuments()

        let taskCount = tasksSnapshot.documents.count

        // Use setData(merge: true) instead of updateData to create document if it doesn't exist
        try await CollectionPath.users.document(userId, in: db).setData([
            "taskCount": taskCount,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }
    
    // MARK: - Encoding/Decoding Helpers

    /**
     Custom encoder for Firestore that intelligently converts Date fields to Firestore Timestamps.

     ## Problem Solved
     Swift's standard JSONEncoder converts Date objects to numeric timestamps (TimeInterval),
     but Firestore expects Timestamp objects for proper indexing and querying. Simply converting
     ALL numbers to Timestamps corrupts non-date fields (e.g., `dailySMSCount: 10` becomes
     `{_seconds: 10}`).

     ## Solution
     This encoder uses field name heuristics to identify date-related fields and only converts
     those to Firestore Timestamps, preserving other numeric and boolean values.

     ## Supported Date Field Patterns
     Fields containing these keywords are converted to Timestamps:
     - `At` (createdAt, updatedAt, lastActiveAt)
     - `Date` (nextScheduledDate, startDate, endDate)
     - `Time` (scheduledTime, lastTime)
     - `timestamp`, `created`, `modified`, `updated`, `last`, `next`, `scheduled`

     ## Example
     ```swift
     let task = Task(
         createdAt: Date(),           // → Firestore Timestamp ✅
         nextScheduledDate: Date(),   // → Firestore Timestamp ✅
         dailySMSCount: 5,            // → Number (preserved) ✅
         isActive: true               // → Boolean (preserved) ✅
     )
     ```

     - Warning: If you add a new date field, ensure its name matches one of the patterns above
     - SeeAlso: `isDateField(_:)` for the complete pattern matching logic
     */
    private class FirestoreEncoder {
        func encode<T: Codable>(_ value: T) throws -> [String: Any] {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(value)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return [:]
            }
            return convertDatesToTimestamps(json)
        }

        private func convertDatesToTimestamps(_ dict: [String: Any]) -> [String: Any] {
            var result: [String: Any] = [:]
            for (key, val) in dict {
                // Only convert fields that are likely dates based on naming
                if isDateField(key), let timestamp = val as? TimeInterval {
                    result[key] = Timestamp(date: Date(timeIntervalSince1970: timestamp))
                } else if let nestedDict = val as? [String: Any] {
                    result[key] = convertDatesToTimestamps(nestedDict)
                } else if let array = val as? [Any] {
                    result[key] = array.map { item -> Any in
                        if let nestedDict = item as? [String: Any] {
                            return convertDatesToTimestamps(nestedDict) as Any
                        }
                        return item
                    }
                } else {
                    result[key] = val
                }
            }
            return result
        }

        private func isDateField(_ key: String) -> Bool {
            let dateFieldPatterns = ["At", "Date", "Time", "timestamp", "created", "modified", "updated", "last", "next", "scheduled"]
            return dateFieldPatterns.contains { key.contains($0) }
        }
    }

    private func encodeToFirestore<T: Codable>(_ object: T) throws -> [String: Any] {
        let encoder = FirestoreEncoder()
        return try encoder.encode(object)
    }
    
    private func decodeFromFirestore<T: Codable>(_ data: [String: Any], as type: T.Type) throws -> T {
        // Convert Firestore Timestamps to Dates for JSON serialization
        let cleanedData = convertTimestampsToDates(data)
        let jsonData = try JSONSerialization.data(withJSONObject: cleanedData)

        // Configure decoder to handle timestamps as Unix epoch seconds
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        return try decoder.decode(type, from: jsonData)
    }

    /// Recursively converts Firestore Timestamp and Data objects for JSON serialization
    private func convertTimestampsToDates(_ data: Any) -> Any {
        if let timestamp = data as? Timestamp {
            // Convert Firestore Timestamp to Date, then to TimeInterval for JSON compatibility
            return timestamp.dateValue().timeIntervalSince1970
        } else if let binaryData = data as? Data {
            // Convert binary Data to base64 string for JSON compatibility
            return binaryData.base64EncodedString()
        } else if let dictionary = data as? [String: Any] {
            // Recursively process dictionary values
            return dictionary.mapValues { convertTimestampsToDates($0) }
        } else if let array = data as? [Any] {
            // Recursively process array elements
            return array.map { convertTimestampsToDates($0) }
        } else {
            // Return primitive types as-is
            return data
        }
    }
    
    deinit {
        // Remove all listeners
        listeners.forEach { $0.remove() }
        listeners.removeAll()
    }
}

// Using DatabaseError from DatabaseServiceProtocol.swift

// MARK: - Recursive Delete Helper
extension FirebaseDatabaseService {
    /// Recursively deletes a document and all its subcollections
    /// - Parameters:
    ///   - docRef: The document reference to delete
    ///   - subcollections: Names of subcollections to delete (e.g., ["habits", "messages"])
    /// - Note: Handles batch size limits (500 operations per batch)
    private func deleteDocumentRecursively(
        _ docRef: DocumentReference,
        subcollections: [String]
    ) async throws {
        // Delete all subcollections first (depth-first traversal)
        for collectionName in subcollections {
            var hasMore = true

            // Handle batch size limit (500 documents per query)
            while hasMore {
                let snapshot = try await docRef.collection(collectionName)
                    .limit(to: 500)
                    .getDocuments()

                // If no documents, we're done with this subcollection
                if snapshot.documents.isEmpty {
                    hasMore = false
                    continue
                }

                // Delete each document (may have its own subcollections)
                for doc in snapshot.documents {
                    // Recursively delete nested subcollections
                    // Profiles have habits and messages, habits have no subcollections, messages have no subcollections
                    let nestedSubcollections = collectionName == "profiles" ? ["habits", "messages"] : []
                    try await deleteDocumentRecursively(
                        doc.reference,
                        subcollections: nestedSubcollections
                    )
                }

                // Check if there are more documents (500 is max per batch)
                hasMore = snapshot.documents.count == 500
            }
        }

        // After all subcollections deleted, delete the document itself
        try await docRef.delete()
    }

    /// Deletes a user and all associated data (profiles, habits, messages)
    /// - Parameter userId: The user's document ID
    /// - Note: Uses nested subcollections - Firestore automatically handles cascade
    func deleteUserRecursively(_ userId: String) async throws {
        let userRef = CollectionPath.users.document(userId, in: db)

        // Delete all nested subcollections under user
        // Order: profiles → (habits + messages nested under profiles) → gallery_events
        try await deleteDocumentRecursively(userRef, subcollections: ["profiles", "gallery_events"])
    }

    /// Deletes a profile and all associated habits/messages
    /// - Parameters:
    ///   - profileId: The profile's document ID
    ///   - userId: The user who owns this profile (for updating counts)
    /// - Note: Uses nested subcollections - deletes habits and messages automatically
    func deleteProfileRecursively(_ profileId: String, userId: String) async throws {
        let profileRef = CollectionPath.userProfiles(userId: userId)
            .document(profileId, in: db)

        // Count items before deletion for verification (prefetch for Firestore batch delete)
        _ = try await profileRef.collection("habits").getDocuments()
        _ = try await profileRef.collection("messages").getDocuments()

        // Also count gallery events linked to this profile
        let galleryEventsSnapshot = try await CollectionPath.userGalleryEvents(userId: userId)
            .collection(in: db)
            .whereField("profileId", isEqualTo: profileId)
            .getDocuments()

        // Delete all nested subcollections under profile (habits and messages)
        try await deleteDocumentRecursively(profileRef, subcollections: ["habits", "messages"])

        // Process gallery events linked to this profile
        // Strategy: Keep photos (memories), delete text-only events (sensitive data)
        var dereferencedPhotos = 0
        var deletedTextOnlyEvents = 0

        for eventDoc in galleryEventsSnapshot.documents {
            let eventData = eventDoc.data()

            // Check if event contains photo data (nested in eventData field)
            let hasPhoto: Bool
            if let eventDataDict = eventData["eventData"] as? [String: Any],
               let photoData = eventDataDict["photoData"] {
                hasPhoto = !(photoData is NSNull)
            } else {
                hasPhoto = false
            }

            if hasPhoto {
                // Photo event - dereference profile but keep photo (preserve memory)
                try await eventDoc.reference.updateData([
                    "profileId": FieldValue.delete()
                ])
                dereferencedPhotos += 1
            } else {
                // Text-only event - safe to delete entirely (no memories lost)
                try await eventDoc.reference.delete()
                deletedTextOnlyEvents += 1
            }
        }

        // Verify deletion of habits and messages (gallery events intentionally kept if they have photos)
        let verifyHabits = try await profileRef.collection("habits").limit(to: 1).getDocuments()
        let verifyMessages = try await profileRef.collection("messages").limit(to: 1).getDocuments()

        if !verifyHabits.isEmpty || !verifyMessages.isEmpty {
            print("❌ [Schema] ORPHANED DATA DETECTED - profileId: \(profileId), habits: \(verifyHabits.documents.count), messages: \(verifyMessages.documents.count)")
        }

        // Update user's profile count
        try await updateUserProfileCount(userId)
    }
}

// MARK: - Time Range Helper
enum FirebaseTimeRange {
    case today
    case thisWeek
    case thisMonth
    case thisYear
    case custom(Date, Date)
    
    var dateRange: (Date, Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
            
        case .thisWeek:
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
            
        case .thisMonth:
            let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
            
        case .thisYear:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear)!
            return (startOfYear, endOfYear)
            
        case .custom(let start, let end):
            return (start, end)
        }
    }
}