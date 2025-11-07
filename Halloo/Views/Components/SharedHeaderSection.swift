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
                // Haptic feedback for navigation bar button
                HapticFeedback.medium()

                showingAccountSettings = true
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
        .fullScreenCover(isPresented: $showingAccountSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(profileViewModel)
        }
    }

}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.container) private var container
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var profileViewModel: ProfileViewModel

    @State private var showingSignOutConfirmation = false
    @State private var showingNotifications = false
    @State private var showingSubscription = false
    @State private var showingFAQs = false
    @State private var showingFeedback = false

    var body: some View {
        VStack(spacing: 0) {
            // Back button header
            HStack {
                Button(action: {
                    HapticFeedback.light()
                    dismiss()
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

            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header with photo and name
                    profileHeaderSection
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)

                    // Settings List - White card with dividers
                    VStack(spacing: 0) {
                        settingsListItem(
                            icon: "bell",
                            title: "Notifications",
                            showChevron: true
                        ) {
                            showingNotifications = true
                        }

                        Divider()
                            .padding(.leading, 62) // Indent to align with text

                        settingsListItem(
                            icon: "creditcard",
                            title: "Manage Subscription",
                            showChevron: true
                        ) {
                            showingSubscription = true
                        }

                        Divider()
                            .padding(.leading, 62)

                        settingsListItem(
                            icon: "questionmark.circle",
                            title: "FAQs",
                            showChevron: true
                        ) {
                            showingFAQs = true
                        }

                        Divider()
                            .padding(.leading, 62)

                        settingsListItem(
                            icon: "bubble.left",
                            title: "Give us feedback",
                            showChevron: true
                        ) {
                            showingFeedback = true
                        }

                        Divider()
                            .padding(.leading, 62)

                        // Log out (no chevron, no divider after)
                        settingsListItem(
                            icon: "rectangle.portrait.and.arrow.right",
                            title: "Log out",
                            showChevron: false
                        ) {
                            showingSignOutConfirmation = true
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(Color(hex: "f9f9f9"))
        .alert("Log Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                performSignOut()
            }
        } message: {
            Text("Are you sure you want to log out?")
        }
        .fullScreenCover(isPresented: $showingNotifications) {
            NotificationsSettingsView()
        }
        .fullScreenCover(isPresented: $showingSubscription) {
            ManageSubscriptionView()
        }
        .fullScreenCover(isPresented: $showingFAQs) {
            FAQsView()
        }
        .fullScreenCover(isPresented: $showingFeedback) {
            FeedbackView()
        }
    }

    // MARK: - Profile Header Section
    private var profileHeaderSection: some View {
        HStack(spacing: 16) {
            // Gradient circular avatar (empty)
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "5EC4FF"),
                            Color(hex: "B3E0FF")
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 90, height: 90)

            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentUser?.email ?? "user@example.com")
                    .font(.custom("Poppins-Medium", size: 20))
                    .foregroundColor(.black)

                Button(action: {
                    // TODO: Navigate to edit profile
                }) {
                    HStack(spacing: 4) {
                        Text("Edit profile")
                            .font(.custom("Poppins-Medium", size: 15))
                            .foregroundColor(Color(hex: "999999"))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(Color(hex: "999999"))
                    }
                }
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
        Button(action: {
            HapticFeedback.light()
            action()
        }) {
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
        _Concurrency.Task.detached {
            do {
                let authService = self.container.resolve(AuthenticationServiceProtocol.self)
                try await authService.signOut()
                await MainActor.run {
                    self.dismiss()
                }
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
        }
    }
}
