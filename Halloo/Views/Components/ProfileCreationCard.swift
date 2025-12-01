import SwiftUI

// MARK: - Profile Creation Card Component
/**
 * PROFILE CREATION CARD: Custom card popup for creating new profiles
 *
 * PURPOSE: Matches HabitCreationCard design - single-screen form in card format
 * DESIGN: Off-white title tab + white card body, slides up from bottom
 * SECTIONS: Profile photo, name, phone number
 *
 * USAGE:
 * ```swift
 * .overlay(
 *     ProfileCreationCard(
 *         isPresented: $showingProfileCreation,
 *         onDismiss: { showingProfileCreation = false }
 *     )
 * )
 * ```
 */
struct ProfileCreationCard: View {
    @Binding var isPresented: Bool
    let onDismiss: () -> Void

    // Environment
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileViewModel: ProfileViewModel

    // Form state
    @State private var profileName = ""
    @State private var phoneNumber = "+1 "
    @State private var hasStartedTypingPhone = false
    @State private var selectedPhoto: UIImage? = nil
    @State private var showImagePicker = false
    @State private var showPhotoOptions = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var isCreating = false // Loading state
    @State private var selectedTimezone: TimezoneOption = .eastern // Default to Eastern

    // MARK: - North American Timezone Options
    enum TimezoneOption: String, CaseIterable {
        case eastern = "America/New_York"
        case central = "America/Chicago"
        case mountain = "America/Denver"
        case pacific = "America/Los_Angeles"
        case alaska = "America/Anchorage"
        case hawaii = "Pacific/Honolulu"

        var displayName: String {
            switch self {
            case .eastern: return "Eastern"
            case .central: return "Central"
            case .mountain: return "Mountain"
            case .pacific: return "Pacific"
            case .alaska: return "Alaska"
            case .hawaii: return "Hawaii"
            }
        }

        var abbreviation: String {
            TimeZone(identifier: rawValue)?.abbreviation() ?? rawValue
        }

        var timeZone: TimeZone {
            TimeZone(identifier: rawValue) ?? TimeZone.current
        }

        /// Initialize from a TimeZone identifier, defaulting to Eastern if not found
        static func from(identifier: String) -> TimezoneOption {
            TimezoneOption(rawValue: identifier) ?? .eastern
        }
    }

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ZStack {
            // Dimmed background overlay (tap to dismiss)
            if isPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }

                        // Reset form after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            resetForm()
                            onDismiss()
                        }
                    }
                    .transition(.opacity)
            }

            // White card popup
            VStack {
                Spacer()

                if isPresented {
                    cardContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented)
        .confirmationDialog("Add Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            photoDialogButtons
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedPhoto, sourceType: imageSourceType)
        }
        .alert("Profile Creation Error", isPresented: .constant(profileViewModel.errorMessage != nil)) {
            Button("OK") {
                profileViewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = profileViewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Card with scrollable content + button inside
            VStack(spacing: 0) {
                // Off-white title tab at top (rounded only on top corners)
                ZStack {
                    // Top corners only rounded
                    UnevenRoundedRectangle(
                        topLeadingRadius: 20,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 20
                    )
                    .fill(Color(hex: "f9f9f9"))
                    .frame(height: 50)

                    Text("New Profile")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(height: 50)
                .zIndex(1)

                VStack(spacing: 24) { // Spacing around the form card
                    // Single grey card containing all form fields
                    VStack(spacing: 20) {
                        // Photo Section
                        photoSectionInCard

                        // Name Section
                        nameSectionInCard

                        // Phone Section
                        phoneSectionInCard

                        // Timezone Section
                        timezoneSectionInCard
                    }
                    .padding(16)
                    .background(Color(hex: "F8F8F8"))
                    .cornerRadius(12)

                    // Button below card
                    if !isTextFieldFocused {
                        createButtonInside
                    }
                }
                .padding(.horizontal, 24) // Match HabitCreationCard's internal padding
                .padding(.top, 20)
                .padding(.bottom, 16)
                .background(Color.white)
                .onTapGesture {
                    // Dismiss keyboard when tapping anywhere
                    isTextFieldFocused = false
                }
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -5)
            .padding(.horizontal, 16) // Match HabitCreationCard exactly
            .padding(.bottom, 90) // Position right above tab bar (same as HabitCreationCard)
        }
    }

    // MARK: - Photo Section (Inside Card)
    private var photoSectionInCard: some View {
        VStack(spacing: 12) {
            Text("Profile Photo")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                photoCircle
                Spacer()
            }
        }
    }

    private var photoCircle: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color(hex: "B9E3FF"))
                .frame(width: 100, height: 100)
                .overlay(photoOverlay)

            pencilIndicator
        }
        .onTapGesture {
            showPhotoOptions = true
            isTextFieldFocused = false
        }
    }

    private var photoOverlay: some View {
        Group {
            if let photo = selectedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "A0D4F7"))
            }
        }
    }

    private var pencilIndicator: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 32, height: 32)
            .overlay(
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            )
            .offset(x: 4, y: 4)
    }

    // MARK: - Name Section (Inside Card)
    private var nameSectionInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's Their Name?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            ZStack(alignment: .leading) {
                TextField("", text: $profileName)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black)
                    .focused($isTextFieldFocused)

                if profileName.isEmpty {
                    Text("e.g., Grandma Smith")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(.gray.opacity(0.8))
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(10)
        }
    }

    // MARK: - Phone Section (Inside Card)
    private var phoneSectionInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's Their Phone Number?")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            VStack(spacing: 0) {
                TextField("", text: $phoneNumber)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.black)
                    .keyboardType(.phonePad)
                    .focused($isTextFieldFocused)
                    .onChange(of: phoneNumber) { oldValue, newValue in
                        phoneNumber = formatPhoneNumber(newValue)
                        if newValue.count > 3 {
                            hasStartedTypingPhone = true
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(10)

                if hasStartedTypingPhone && !isValidPhoneNumber(phoneNumber) {
                    HStack {
                        Text("Please enter a valid phone number")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Timezone Section (Inside Card)
    private var timezoneSectionInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Their Timezone")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)

            // Horizontal scrolling timezone pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimezoneOption.allCases, id: \.self) { option in
                        timezoneButton(for: option)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4) // Prevent pills from being clipped
            }

            // Show current time in selected timezone
            Text("Current time: \(currentTimeInSelectedTimezone)")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }

    private func timezoneButton(for option: TimezoneOption) -> some View {
        Button {
            HapticFeedback.light()
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTimezone = option
            }
            isTextFieldFocused = false
        } label: {
            Text(option.displayName)
                .font(.system(size: 14, weight: selectedTimezone == option ? .semibold : .regular))
                .foregroundColor(selectedTimezone == option ? .white : .black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(selectedTimezone == option ? Color.black : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedTimezone == option ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    /// Shows the current time in the selected timezone for user reference
    private var currentTimeInSelectedTimezone: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = selectedTimezone.timeZone
        return formatter.string(from: Date()) + " " + (selectedTimezone.timeZone.abbreviation() ?? "")
    }

    // MARK: - Create Button (Below Card)
    private var createButtonInside: some View {
        Button(action: handleCreateProfile) {
            ZStack {
                // Button text (hidden when loading)
                Text("Create Profile")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(isCreating ? 0 : 1)

                // Loading indicator
                if isCreating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.0)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(canCreate && !isCreating ? Color.black : Color.gray.opacity(0.3))
            .cornerRadius(14)
        }
        .disabled(!canCreate || isCreating)
    }

    // MARK: - Photo Dialog Buttons
    @ViewBuilder
    private var photoDialogButtons: some View {
        Button("Take Photo") {
            imageSourceType = .camera
            showImagePicker = true
        }
        Button("Choose from Library") {
            imageSourceType = .photoLibrary
            showImagePicker = true
        }
        if selectedPhoto != nil {
            Button("Remove Photo", role: .destructive) {
                selectedPhoto = nil
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Validation
    private var canCreate: Bool {
        let nameValid = !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let phoneValid = isValidPhoneNumber(phoneNumber)
        return nameValid && phoneValid
    }

    private func isValidPhoneNumber(_ phone: String) -> Bool {
        // Simple validation: 10 digits (excluding country code)
        let cleanValue = phone.replacingOccurrences(of: "+1 ", with: "")
                              .replacingOccurrences(of: " ", with: "")
                              .replacingOccurrences(of: "-", with: "")
        let digits = cleanValue.filter { $0.isNumber }
        return digits.count == 10
    }

    // MARK: - Helper Functions
    private func resetForm() {
        profileName = ""
        phoneNumber = "+1 "
        hasStartedTypingPhone = false
        selectedPhoto = nil
        isCreating = false
        selectedTimezone = .eastern // Reset to default
    }

    private func formatPhoneNumber(_ value: String) -> String {
        // Remove the prefix and any non-digits to get clean phone number
        let cleanValue = value.replacingOccurrences(of: "+1 ", with: "")
                              .replacingOccurrences(of: " ", with: "")
                              .replacingOccurrences(of: "-", with: "")

        let digits = cleanValue.filter { $0.isNumber }

        if digits.isEmpty { return "+1 " }

        // Limit to 10 digits max
        let phoneDigits = String(digits.prefix(10))

        var formatted = "+1 "

        if phoneDigits.count > 0 {
            formatted += String(phoneDigits.prefix(3))
        }
        if phoneDigits.count > 3 {
            formatted += " " + String(phoneDigits.dropFirst(3).prefix(3))
        }
        if phoneDigits.count > 6 {
            formatted += "-" + String(phoneDigits.dropFirst(6))
        }

        return formatted
    }

    private func handleCreateProfile() {
        guard canCreate && !isCreating else { return }

        // Set loading state immediately
        isCreating = true

        // Haptic feedback
        HapticFeedback.medium()

        // Set form data on ViewModel
        profileViewModel.profileName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        profileViewModel.phoneNumber = phoneNumber
        profileViewModel.hasSelectedPhoto = selectedPhoto != nil
        profileViewModel.timeZone = selectedTimezone.timeZone // Pass selected timezone

        // Set default relationship if not already set
        if profileViewModel.relationship.isEmpty {
            profileViewModel.relationship = "Family Member"
        }

        if let photo = selectedPhoto, let photoData = photo.jpegData(compressionQuality: 0.8) {
            profileViewModel.selectedPhotoData = photoData
        }

        // Create profile asynchronously
        _Concurrency.Task {
            await profileViewModel.createProfileAsync()

            await MainActor.run {
                // Reset loading state
                isCreating = false

                // Dismiss card
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isPresented = false
                }

                // Reset form and call dismiss callback after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    resetForm()
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(hex: "f9f9f9")
            .ignoresSafeArea()

        ProfileCreationCard(
            isPresented: .constant(true),
            onDismiss: { }
        )
        .environmentObject(AppState(
            authService: Container.shared.resolve(AuthenticationServiceProtocol.self),
            databaseService: Container.shared.resolve(DatabaseServiceProtocol.self),
            dataSyncCoordinator: Container.shared.resolve(DataSyncCoordinator.self),
            imageCache: Container.shared.resolve(ImageCacheService.self)
        ))
        .environmentObject(ProfileViewModel(
            databaseService: Container.shared.resolve(DatabaseServiceProtocol.self),
            smsService: Container.shared.resolve(SMSServiceProtocol.self),
            authService: Container.shared.resolve(AuthenticationServiceProtocol.self),
            dataSyncCoordinator: Container.shared.resolve(DataSyncCoordinator.self)
        ))
    }
}
