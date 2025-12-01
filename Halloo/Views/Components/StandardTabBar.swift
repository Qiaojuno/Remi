import SwiftUI
import UIKit

// MARK: - Visual Effect Blur (UIKit Integration)
/**
 * VISUAL EFFECT BLUR: UIKit blur wrapper for SwiftUI
 *
 * PURPOSE: Provides UIKit's UIBlurEffect in SwiftUI with forced light appearance
 * REASON: SwiftUI's Material adapts to system dark mode, we need light mode only
 */
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
    }
}

// MARK: - Standard Tab Bar Component
/**
 * STANDARD TAB BAR: iOS-style bottom navigation bar
 *
 * PURPOSE: Replaces custom pill navigation with professional standard tab bar
 * DESIGN: Matches iOS system tab bar appearance (white background, gray border)
 * TABS: Home, Gallery, Habits, Create
 *
 * USAGE:
 * ```swift
 * StandardTabBar(
 *     selectedTab: $selectedTab,
 *     isCreateExpanded: $isCreateExpanded,
 *     onCreateTapped: { showingCreateActionSheet = true }
 * )
 * ```
 */
struct StandardTabBar: View {
    @Binding var selectedTab: Int
    @Binding var isCreateExpanded: Bool
    let onCreateTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Super light grey line at top with opacity
            Rectangle()
                .fill(Color(hex: "f0f0f0").opacity(0.5))
                .frame(height: 1)

            HStack(spacing: 0) {
                // Home Tab
                TabBarItem(
                    iconAsset: "Home button",
                    title: "Home",
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                    isCreateExpanded = false // Close create if switching tabs
                }

                // Gallery Tab
                TabBarItem(
                    icon: "photo.fill",
                    title: "Gallery",
                    isSelected: selectedTab == 1
                ) {
                    // Post notification for gallery tab tap (even if already selected)
                    NotificationCenter.default.post(name: .galleryTabTapped, object: nil)
                    selectedTab = 1
                    isCreateExpanded = false // Close create if switching tabs
                }

                // Habits Tab
                TabBarItem(
                    icon: "bookmark.fill",
                    title: "Habits",
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                    isCreateExpanded = false // Close create if switching tabs
                }

                // Create Tab - Special toggle button
                CreateTabItem(isExpanded: $isCreateExpanded) {
                    isCreateExpanded.toggle()
                    if isCreateExpanded {
                        onCreateTapped()
                    }
                }
            }
            .frame(height: 70)
            .padding(.bottom, 15) // Push content down into safe area
        }
        .background(
            ZStack {
                // Blur layer behind
                VisualEffectBlur(blurStyle: .systemUltraThinMaterialLight)

                // White color on top with slight transparency to show blur
                Color.white.opacity(0.85)
            }
            .ignoresSafeArea(.all, edges: .bottom) // Extend background to screen bottom
        )
    }
}

// MARK: - Create Tab Item Component (Special Toggle)
/**
 * CREATE TAB ITEM: Special animated toggle button for create actions
 *
 * FEATURES:
 * - Animates from "+" to "×" when tapped
 * - Black circle background appears on expansion
 * - Text label disappears when expanded
 */
struct CreateTabItem: View {
    @Binding var isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            // Haptic feedback
            HapticFeedback.soft()
            action()
        }) {
            ZStack {
                // Black circle background (animated) - spans from top of icons to bottom of text
                if isExpanded {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 50, height: 50) // Larger circle to encompass icon + text area
                        .scaleEffect(isExpanded ? 1.0 : 0.0) // Scale from 0 to 1
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                }

                VStack(spacing: 4) {  // Reduced from 6 to 4 to match other tabs
                    // Icon: "+" rotates to become "x"
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .light)) // Bigger (30pt) and thinner (.light)
                        .foregroundColor(isExpanded ? .white : Color(hex: "9f9f9f"))
                        .rotationEffect(.degrees(isExpanded ? 45 : 0)) // Rotate 45° clockwise
                        .offset(y: isExpanded ? 8 : 0) // Move down to center of circle when expanded
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)

                    // Text: disappears when expanded
                    if !isExpanded {
                        Text("Create")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "9f9f9f"))
                            .transition(.opacity)
                    } else {
                        // Invisible spacer to maintain layout when text is gone
                        Text("Create")
                            .font(.system(size: 11))
                            .opacity(0)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
    }
}

// MARK: - Tab Bar Item Component
/**
 * TAB BAR ITEM: Standard tab button with icon and label
 *
 * DESIGN:
 * - Black when selected, light gray (#9f9f9f) when unselected
 * - 26pt icons, 11pt text
 * - 4pt spacing between icon and text
 * - Supports both SF Symbols (icon) and custom PNG assets (iconAsset)
 */
struct TabBarItem: View {
    let icon: String?
    let iconAsset: String?
    let title: String
    let isSelected: Bool
    let action: () -> Void

    // Convenience initializer for SF Symbols
    init(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.icon = icon
        self.iconAsset = nil
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    // Convenience initializer for PNG assets
    init(iconAsset: String, title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.icon = nil
        self.iconAsset = iconAsset
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: iconAsset != nil ? -8 : 4) {  // Negative spacing for PNG to pull text up, normal spacing for SF Symbols
                // Use PNG asset if provided, otherwise use SF Symbol
                if let iconAsset = iconAsset {
                    Image(iconAsset)
                        .renderingMode(.template)  // Enable template rendering for dynamic coloring
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)  // Custom size for home button
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 26))  // Increased from 24 to 26 for better visibility
                }

                Text(title)
                    .font(.system(size: 11))  // Increased from 10 to 11 for readability
            }
            .offset(y: iconAsset != nil ? -6 : 0)  // Shift entire stack up for PNG to compensate for text being pulled up
            .foregroundColor(isSelected ? .black : Color(hex: "9f9f9f")) // Black when selected, light gray when not (matches pill navigation)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Preview
#Preview {
    StandardTabBar(
        selectedTab: .constant(0),
        isCreateExpanded: .constant(false),
        onCreateTapped: { }
    )
}
