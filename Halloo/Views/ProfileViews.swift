import SwiftUI
import AVFoundation
import Combine

// MARK: - Simplified Profile Creation View (Single Card Design)
/// Inspired by TaskCreationView - everything on one screen
/// Just Name + Phone + Optional Photo, that's it!
struct SimplifiedProfileCreationView: View {
    let onDismiss: () -> Void

    // PHASE 3: Need appState for debug logging
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var profileName = ""
    @State private var phoneNumber = "+1 "
    @State private var hasStartedTypingPhone = false
    @State private var selectedPhoto: UIImage? = nil
    @State private var showImagePicker = false
    @State private var showPhotoOptions = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topNavBar
            mainScrollContent
            if !isTextFieldFocused {
                bottomActionButton
            }
        }
        .background(backgroundGradient)
        .confirmationDialog("Add Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            photoDialogButtons
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedPhoto, sourceType: imageSourceType)
        }
        .onChange(of: selectedPhoto) { oldValue, newValue in
            if let photo = newValue {
                print("📷 selectedPhoto CHANGED - new photo size: \(photo.size)")
            } else {
                print("📷 selectedPhoto CHANGED - photo is now NIL")
            }
        }
        .onChange(of: showImagePicker) { oldValue, newValue in
            print("📷 showImagePicker changed: \(oldValue) -> \(newValue)")
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

    // MARK: - Top Navigation Bar
    private var topNavBar: some View {
        HStack {
            Spacer()
            HStack {
                backButton
                Spacer()
                Text("Remi")
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(-1.9)
                    .foregroundColor(.black)
                Spacer()
                invisibleSpacer
            }
            .frame(width: 347)
            Spacer()
        }
        .padding(.top, 8)
    }

    private var backButton: some View {
        Button(action: {
            HapticFeedback.light()
            onDismiss()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .medium))
                Text("Back")
                    .font(.system(size: 16, weight: .light))
            }
        }
        .foregroundColor(.gray)
    }

    private var invisibleSpacer: some View {
        HStack(spacing: 8) {
            Text("Back")
                .font(.system(size: 16, weight: .light))
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.clear)
        .disabled(true)
    }

    // MARK: - Main Scroll Content
    private var mainScrollContent: some View {
        ScrollView {
            VStack(spacing: 67) {
                headerSection
                formCard
            }
        }
        .onTapGesture {
            // Dismiss keyboard when tapping anywhere
            isTextFieldFocused = false
        }
    }

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text("Create Family Member")
                .font(.system(size: 34, weight: .medium))
                .kerning(-1.0)
                .foregroundColor(.black)
                .multilineTextAlignment(.center)

            Text("Add someone you care for")
                .font(.system(size: 14, weight: .light))
                .kerning(-0.3)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 67)
    }

    // MARK: - Form Card
    private var formCard: some View {
        VStack(spacing: 0) {
            photoSection
            Divider().overlay(Color.gray.opacity(0.3)).padding(.horizontal, 18)
            nameSection
            Divider().overlay(Color.gray.opacity(0.3)).padding(.horizontal, 18)
            phoneSection
        }
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 23)
    }

    // MARK: - Photo Section
    private var photoSection: some View {
        VStack(spacing: 12) {
            photoCircle
            Text("Tap to add photo (optional)")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    private var photoCircle: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.gray.opacity(0.1))
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
                    .foregroundColor(.gray)
            }
        }
    }

    private var pencilIndicator: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 32, height: 32)
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .overlay(
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            )
            .offset(x: 4, y: 4)
    }

    // MARK: - Name Section
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PROFILE NAME")
                        .font(.system(size: 16, weight: .medium))
                        .kerning(-0.3)
                        .foregroundColor(.gray)

                    nameTextField
                }
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 24)
        .background(Color.white)
    }

    private var nameTextField: some View {
        ZStack(alignment: .leading) {
            TextField("", text: $profileName)
                .font(.system(size: 16, weight: .light))
                .focused($isTextFieldFocused)
                .foregroundColor(.black)
                .accentColor(.blue)

            if profileName.isEmpty {
                Text("eg. Grandma Smith")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.gray.opacity(0.8))
                    .allowsHitTesting(false)
            }
        }
        .onTapGesture {
            isTextFieldFocused = true
        }
    }

    // MARK: - Phone Section
    private var phoneSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PHONE NUMBER")
                        .font(.system(size: 16, weight: .medium))
                        .kerning(-0.3)
                        .foregroundColor(.gray)

                    phoneTextField

                    if hasStartedTypingPhone && !isValidPhoneNumber(phoneNumber) {
                        Text("Please enter a valid phone number")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 24)
        .background(Color.white)
    }

    private var phoneTextField: some View {
        TextField("", text: $phoneNumber)
            .font(.system(size: 16, weight: .light))
            .focused($isTextFieldFocused)
            .foregroundColor(.black)
            .keyboardType(.phonePad)
            .onChange(of: phoneNumber) { oldValue, newValue in
                phoneNumber = formatPhoneNumber(newValue)
                if newValue.count > 3 {
                    hasStartedTypingPhone = true
                }
            }
    }

    // MARK: - Bottom Action Button
    private var bottomActionButton: some View {
        GeometryReader { geometry in
            VStack {
                Button(action: handleCreateProfile) {
                    Text("Create Profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: max(200, geometry.size.width - 46), height: 47)
                        .background(canProceed ? Color.black : Color.gray.opacity(0.3))
                        .cornerRadius(15)
                }
                .disabled(!canProceed)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)
            }
        }
        .frame(height: 57)
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "f9f9f9")

            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color(hex: "B3B3B3")
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 451)
            .offset(y: 225)
        }
        .ignoresSafeArea()
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

    // MARK: - Validation & Actions
    private var canProceed: Bool {
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
        print("🔨 ========== handleCreateProfile() CALLED ==========")
        print("🔨 canProceed: \(canProceed)")

        guard canProceed else {
            print("❌ canProceed is FALSE - exiting early")
            return
        }

        print("✅ canProceed is TRUE - proceeding")
        HapticFeedback.medium()

        print("🔨 Local form values:")
        print("🔨   profileName: '\(profileName)'")
        print("🔨   phoneNumber: '\(phoneNumber)'")
        print("🔨   selectedPhoto: \(selectedPhoto != nil)")

        // Set form data on ViewModel
        profileViewModel.profileName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        profileViewModel.phoneNumber = phoneNumber
        profileViewModel.hasSelectedPhoto = selectedPhoto != nil

        // Set default relationship if not already set
        if profileViewModel.relationship.isEmpty {
            print("🔨 Setting default relationship: 'Family Member'")
            profileViewModel.relationship = "Family Member"
        }

        if let photo = selectedPhoto, let photoData = photo.jpegDataWithoutEXIF(compressionQuality: 0.8) {
            print("🔨 Converting photo to JPEG data (EXIF stripped): \(photoData.count) bytes")
            profileViewModel.selectedPhotoData = photoData
            print("🔨 Photo data SET on ViewModel: \(profileViewModel.selectedPhotoData?.count ?? 0) bytes")
        } else {
            print("🔨 No photo selected or conversion failed")
            print("🔨   selectedPhoto exists: \(selectedPhoto != nil)")
            if let photo = selectedPhoto {
                print("🔨   Photo size: \(photo.size)")
                let jpegData = photo.jpegDataWithoutEXIF(compressionQuality: 0.8)
                print("🔨   JPEG conversion result: \(jpegData?.count ?? 0) bytes")
            }
        }

        print("🔨 ViewModel values after setting:")
        print("🔨   profileViewModel.profileName: '\(profileViewModel.profileName)'")
        print("🔨   profileViewModel.phoneNumber: '\(profileViewModel.phoneNumber)'")
        print("🔨   profileViewModel.relationship: '\(profileViewModel.relationship)'")
        print("🔨   profileViewModel.hasSelectedPhoto: \(profileViewModel.hasSelectedPhoto)")
        print("🔨   profileViewModel.selectedPhotoData: \(profileViewModel.selectedPhotoData?.count ?? 0) bytes")

        // Create profile asynchronously and WAIT for completion
        _Concurrency.Task {
            print("🔨 SimplifiedProfileCreationView: Starting async task...")

            // Actually wait for profile creation to complete
            await profileViewModel.createProfileAsync()

            print("✅ SimplifiedProfileCreationView: createProfileAsync() returned")
            // PHASE 3: Read from AppState for debug logging
            print("✅ AppState.profiles.count = \(appState.profiles.count)")

            await MainActor.run {
                print("✅ SimplifiedProfileCreationView: Dismissing view...")
                onDismiss()
            }
        }
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("🖼️ ImagePicker: didFinishPickingMedia called")
            if let image = info[.originalImage] as? UIImage {
                print("🖼️ ImagePicker: Image found - size: \(image.size)")
                parent.image = image
                print("🖼️ ImagePicker: Image SET on parent.image")
            } else {
                print("🖼️ ImagePicker: ❌ No image found in info dictionary")
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("🖼️ ImagePicker: User cancelled")
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Preview Support
#if DEBUG
struct ProfileViews_Previews: PreviewProvider {
    static var previews: some View {
        let container = Container.shared
        SimplifiedProfileCreationView(onDismiss: {})
            .environmentObject(ProfileViewModel(
                databaseService: container.resolve(DatabaseServiceProtocol.self),
                smsService: container.resolve(SMSServiceProtocol.self),
                authService: container.resolve(AuthenticationServiceProtocol.self),
                dataSyncCoordinator: container.resolve(DataSyncCoordinator.self)
            ))
            .previewDisplayName("Simplified Profile Creation")
    }
}
#endif
