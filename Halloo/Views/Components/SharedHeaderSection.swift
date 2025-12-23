import SwiftUI

/**
 * SHARED HEADER SECTION: Universal app header used across all main views
 * 
 * PURPOSE: Provides consistent navigation and branding across Dashboard, Habits, and Gallery views
 * Contains Remi logo, profile circles for elderly family member selection, and settings access
 * 
 * KEY FEATURES:
 * - Responsive Remi logo with Poppins Medium font
 * - Profile circles (45x45) positioned between logo and settings icon
 * - Profile selection updates both local state and ProfileViewModel
 * - Settings button placeholder for future account management
 * 
 * USAGE: Shared across Dashboard, Habits, and Gallery views
 */
struct SharedHeaderSection: View {
    // MARK: - Environment & State
    @Environment(\.container) private var container

    // PHASE 3: Single source of truth for shared state
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Binding var selectedProfileIndex: Int

    // MARK: - UI State
    @State private var showingAccountSettings = false

    // MARK: - Initialization
    init(selectedProfileIndex: Binding<Int>) {
        self._selectedProfileIndex = selectedProfileIndex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 0) {
                /*
                 * MAIN LOGO: "Remi" brand text
                 * Font: Poppins Medium to match ProfileViews, scaled up for header
                 * Letter spacing adjusted for proper appearance at larger size
                 */
                Text("Remi")
                    .font(AppFonts.poppinsMedium(size: 37.5))
                    .tracking(-3.1) // Scaled tracking from ProfileViews (-1.9 to -3.1 for larger size)
                    .foregroundColor(.black)
                    .fixedSize() // Prevent text truncation/clipping
                    .layoutPriority(1) // Ensure logo gets full space before profile circles

                /*
                 * PROFILE CIRCLES: Elderly family member selection
                 * Positioned immediately after logo like original design
                 * Max 2 profiles only, Size: 45x45 (standardized across app)
                 * PHASE 3: Read from AppState (single source of truth)
                 */
                HStack(spacing: 8) {
                    ForEach(Array(appState.profiles.prefix(2).enumerated()), id: \.element.id) { index, profile in
                        ProfileImageView(
                            profile: profile,
                            profileSlot: index,
                            isSelected: selectedProfileIndex == index,
                            size: .custom(45)
                        )
                        .onTapGesture {
                            selectedProfileIndex = index
                            // Update DashboardViewModel's selected profile to trigger task filtering
                            viewModel.selectProfile(profileId: profile.id)
                        }
                    }
                }
                .padding(.leading, 16) // Increased spacing from logo (was 8)
            
            Spacer()
            
            /*
             * PROFILE SETTINGS BUTTON: Account/settings access
             * Shows account settings sheet with logout option
             * Icon: SF Symbol person (outlined torso) for clean appearance
             */
            Button(action: {
                HapticFeedback.medium()
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showingAccountSettings = true
                }
            }) {
                Image(systemName: "person")
                    .font(.title2)
                    .foregroundColor(.black)
            }
            }
            /*
             * HEADER PADDING: Match Dashboard content padding
             * Horizontal: 26px to match typical Dashboard spacing
             * Vertical: 20px top, 10px bottom for visual separation
             */
            .padding(.horizontal, 26)
            .padding(.top, 20)
            .padding(.bottom, 10)
        }
        .background(Color(hex: "f9f9f9")) // Match app background color
        .fullScreenCoverNoAnimation(isPresented: $showingAccountSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(profileViewModel)
        }
    }

}

// MARK: - View Extension for Animation-Free Presentations
extension View {
    func fullScreenCoverNoAnimation<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self
            .onChange(of: isPresented.wrappedValue) { _, newValue in
                if newValue {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { }
                }
            }
            .fullScreenCover(isPresented: isPresented) {
                content()
                    .environment(\.dismissWithoutAnimation, DismissActionWithoutAnimation {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            isPresented.wrappedValue = false
                        }
                    })
            }
    }
}

// MARK: - Custom Dismiss Environment Key
struct DismissActionWithoutAnimation {
    let action: () -> Void

    func callAsFunction() {
        action()
    }
}

struct DismissWithoutAnimationKey: EnvironmentKey {
    static let defaultValue: DismissActionWithoutAnimation? = nil
}

extension EnvironmentValues {
    var dismissWithoutAnimation: DismissActionWithoutAnimation? {
        get { self[DismissWithoutAnimationKey.self] }
        set { self[DismissWithoutAnimationKey.self] = newValue }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismissWithoutAnimation) private var dismissWithoutAnimation
    @Environment(\.container) private var container
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    @State private var showingSignOutConfirmation = false
    @State private var showingNotifications = false
    @State private var showingSubscription = false
    @State private var showingFAQs = false
    @State private var showingFeedback = false
    @State private var showingPrivacyPolicy = false
    @State private var showingTerms = false

    var body: some View {
        mainContent
            .alert("Log Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    performSignOut()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .fullScreenCoverNoAnimation(isPresented: $showingNotifications) {
                NotificationsSettingsView()
            }
            .sheet(isPresented: $showingSubscription) {
                CustomerCenterView()
            }
            .fullScreenCoverNoAnimation(isPresented: $showingFAQs) {
                FAQsView()
            }
            .fullScreenCoverNoAnimation(isPresented: $showingFeedback) {
                FeedbackView()
            }
            .fullScreenCoverNoAnimation(isPresented: $showingPrivacyPolicy) {
                LegalDocumentView(documentType: .privacy)
            }
            .fullScreenCoverNoAnimation(isPresented: $showingTerms) {
                LegalDocumentView(documentType: .terms)
            }
    }

    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerSection

            ScrollView {
                VStack(spacing: 0) {
                    profileHeaderSection
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)

                    settingsListCard
                }
            }
        }
        .background(Color(hex: "f9f9f9"))
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Button(action: {
                HapticFeedback.light()
                dismissWithoutAnimation?()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
            }
            .padding(.leading, 20)

            Spacer()
        }
        .frame(height: 60)
        .background(Color(hex: "f9f9f9"))
    }

    // MARK: - Settings List Card
    private var settingsListCard: some View {
        VStack(spacing: 0) {
            settingsListItem(icon: "bell", title: "Notifications", showChevron: true) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showingNotifications = true
                }
            }

            Divider().background(Color(hex: "E0E0E0"))

            settingsListItem(icon: "creditcard", title: "Manage Subscription", showChevron: true) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showingSubscription = true
                }
            }

            Divider().background(Color(hex: "E0E0E0"))

            settingsListItem(icon: "questionmark.circle", title: "FAQs", showChevron: true) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showingFAQs = true
                }
            }

            Divider().background(Color(hex: "E0E0E0"))

            settingsListItem(icon: "bubble.left", title: "Give us feedback", showChevron: true) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showingFeedback = true
                }
            }

            Divider().background(Color(hex: "E0E0E0"))

            settingsListItem(icon: "hand.raised", title: "Privacy Policy", showChevron: true) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showingPrivacyPolicy = true
                }
            }

            Divider().background(Color(hex: "E0E0E0"))

            settingsListItem(icon: "doc.text", title: "Terms & Conditions", showChevron: true) {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showingTerms = true
                }
            }

            Divider().background(Color(hex: "E0E0E0"))

            settingsListItem(icon: "rectangle.portrait.and.arrow.right", title: "Log out", showChevron: false) {
                showingSignOutConfirmation = true
            }
        }
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Settings")
                    .font(.custom("Poppins-Medium", size: 20))
                    .foregroundColor(.black)
            }

            Spacer()
        }
    }

    // MARK: - Helper Views
    private func settingsListItem(
        icon: String,
        title: String,
        showChevron: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                    .frame(width: 30)

                Text(title)
                    .font(.custom("Poppins-Regular", size: 15))
                    .foregroundColor(.black)

                Spacer()

                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "C7C7C7"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Actions
    private func performSignOut() {
        let authService = container.resolve(AuthenticationServiceProtocol.self)
        _Concurrency.Task {
            do {
                try await authService.signOut()
                await MainActor.run {
                    self.dismissWithoutAnimation?()
                }
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
        }
    }
}
