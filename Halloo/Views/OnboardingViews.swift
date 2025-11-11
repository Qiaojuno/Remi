import SwiftUI
import SuperwallKit

// MARK: - Custom Shapes
struct TopRoundedRectangle: Shape {
    let topRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: topRadius, height: topRadius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showMessages = false
    @State private var showButtons = false
    @State private var showingLogin = false

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Remi Logo - EXACT same Y-axis as LoginView (100px from top)
                Text("Remi")
                    .font(.custom("Poppins-Medium", size: 73.93))
                    .tracking(-3.0)
                    .foregroundColor(.black)
                    .padding(.top, 100)

                // Message bubbles conversation - positioned close to logo
                VStack(spacing: 16) {
                    if showMessages {
                        // Blue bubble (sender) - "Create Reminders"
                        HStack {
                            Spacer(minLength: UIScreen.main.bounds.width * 0.2)
                            SpeechBubbleView(
                                text: "Create Reminders",
                                isOutgoing: true,
                                backgroundColor: Color(hex: "007AFF"),
                                textColor: .white
                            )
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        // Grey bubble (receiver) - "for anyone you love"
                        HStack {
                            SpeechBubbleView(
                                text: "for anyone you love",
                                isOutgoing: false,
                                backgroundColor: Color(hex: "E5E5EA"),
                                textColor: .black
                            )
                            Spacer(minLength: UIScreen.main.bounds.width * 0.2)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 40)

                Spacer()

                // Buttons section
                if showButtons {
                    VStack(spacing: 16) {
                        // Primary button - Let's get started
                        Button(action: {
                            HapticFeedback.medium()
                            viewModel.startQuiz()
                        }) {
                            Text("Let's get started")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.black)
                                .cornerRadius(25)
                        }

                        // Secondary button - Already signed up? Log in
                        Button(action: {
                            HapticFeedback.light()
                            showingLogin = true
                        }) {
                            HStack(spacing: 4) {
                                Text("Already signed up?")
                                    .foregroundColor(.gray)
                                Text("Log in")
                                    .foregroundColor(.black)
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 15))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                    .opacity(showButtons ? 1 : 0)
                    .offset(y: showButtons ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: showButtons)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Color(hex: "f9f9f9")

                    VStack {
                        Spacer()
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color(hex: "B3B3B3").opacity(0.3)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                    }
                }
                .ignoresSafeArea(.all)
            )
        }
        .sheet(isPresented: $showingLogin) {
            LoginSheetView()
                .environmentObject(viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Show messages after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 1.2)) {
                    showMessages = true
                }
            }

            // Show buttons after messages animate in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                showButtons = true
            }
        }
    }
}

// MARK: - Login Sheet View
struct LoginSheetView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // Title
            Text("Welcome back")
                .font(.system(size: 28, weight: .bold))
                .tracking(-1.0)
                .padding(.top, 16)

            Spacer()
                .frame(height: 20)

            // Login buttons
            VStack(spacing: 12) {
                // Apple Sign In
                Button {
                    _Concurrency.Task {
                        await viewModel.signInWithApple()
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Continue with Apple")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.black)
                    .cornerRadius(12)
                }

                // Google Sign In
                Button {
                    _Concurrency.Task {
                        await viewModel.signInWithGoogle()
                        dismiss()
                    }
                } label: {
                    HStack {
                        Image("GoogleIcon")
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("Continue with Google")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color(hex: "f9f9f9"))
    }
}

// MARK: - iOS-Style Speech Bubble View
/**
 * PROFESSIONAL SPEECH BUBBLE - Following iOS Messages design
 * 
 * Features:
 * - Dynamic sizing with min/max width constraints
 * - Proper triangle tail positioning
 * - Elderly-friendly font sizes and accessibility
 * - iOS-authentic colors and styling
 */
struct SpeechBubbleView: View {
    let text: String
    let isOutgoing: Bool
    let backgroundColor: Color
    let textColor: Color
    var maxWidth: CGFloat? = nil  // Optional override for custom layouts (e.g., cards)
    var scale: CGFloat = 1.0  // Optional scale factor for proportional sizing

    // Dynamic sizing constraints (scaled proportionally)
    private var minWidth: CGFloat { 60 * scale }
    private let maxWidthPercent: CGFloat = 0.8
    private var cornerRadius: CGFloat { 12 * scale }  // Increased from 9 to 12
    private var padding: CGFloat { 16 * scale }
    private var tailSize: CGFloat { 15 * scale }
    private var fontSize: CGFloat { 18 * scale }
    private var verticalPadding: CGFloat { 9 * scale }  // Reduced from 12 to 9 (3pt reduction per side)

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .regular))
            .foregroundColor(textColor)
            .padding(.horizontal, padding)
            .padding(.vertical, verticalPadding)
            .background(
                BubbleWithTail(isOutgoing: isOutgoing, cornerRadius: cornerRadius, tailSize: tailSize)
                    .fill(backgroundColor)
            )
            .frame(minWidth: minWidth)
            .frame(maxWidth: maxWidth ?? (UIScreen.main.bounds.width * maxWidthPercent), alignment: isOutgoing ? .trailing : .leading)
    }
}

// MARK: - Corrected Bubble Shape with Attached Tail
struct BubbleWithTail: Shape {
    let isOutgoing: Bool
    let cornerRadius: CGFloat
    let tailSize: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let tailInset: CGFloat = 20 // Triangle positioned closer to edges but avoiding rounded corners
        
        if isOutgoing {
            // OUTGOING BUBBLE (Right tail attached to bottom)
            
            // Start from top-left, create full rounded rectangle first
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            
            // Top edge
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            
            // Right edge
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            
            // Bottom edge with right-angle triangle tail pointing LEFT
            // Go to where triangle starts (30pt from right edge)
            path.addLine(to: CGPoint(x: width - tailInset, y: height))
            
            // Left-pointing triangle (outgoing messages point toward center/left)
            path.addLine(to: CGPoint(x: width - tailInset - tailSize, y: height))          // Left point of triangle
            path.addLine(to: CGPoint(x: width - tailInset, y: height + tailSize))          // Bottom corner
            path.addLine(to: CGPoint(x: width - tailInset, y: height))                     // Back to start
            
            // Continue bottom edge to left
            path.addLine(to: CGPoint(x: cornerRadius, y: height))
            path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            
            // Left edge
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            
        } else {
            // INCOMING BUBBLE (Left tail attached to bottom)
            
            // Start from top-left, create full rounded rectangle first
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            
            // Top edge
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            
            // Right edge
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            
            // Bottom edge with right-angle triangle tail pointing RIGHT
            // Go to where triangle starts (30pt from left edge)
            path.addLine(to: CGPoint(x: tailInset, y: height))
            
            // Right-pointing triangle (incoming messages point toward center/right)
            path.addLine(to: CGPoint(x: tailInset + tailSize, y: height))                      // Right point of triangle
            path.addLine(to: CGPoint(x: tailInset, y: height + tailSize))                     // Bottom corner
            path.addLine(to: CGPoint(x: tailInset, y: height))                               // Back to start
            
            // Continue bottom edge to left
            path.addLine(to: CGPoint(x: cornerRadius, y: height))
            path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            
            // Left edge
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Account Setup View
struct AccountSetupView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    Text("Create Your Account")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.black)
                        .padding(.top, 50)
                    
                    VStack(spacing: 15) {
                        TextField("Full Name", text: $viewModel.fullName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                        
                        TextField("Email", text: $viewModel.email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $viewModel.password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                        
                        SecureField("Confirm Password", text: $viewModel.confirmPassword)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                        
                        TextField("Phone Number", text: $viewModel.phoneNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16, weight: .regular))
                            .keyboardType(.phonePad)
                    }
                    .padding(.horizontal, 12)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        Button(action: {
                            viewModel.previousStep()
                        }) {
                            Text("Back")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            viewModel.nextStep()
                        }) {
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(viewModel.isValidSignUpForm ? Color.black : Color.gray)
                                .cornerRadius(12)
                        }
                        .disabled(!viewModel.isValidSignUpForm)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
            .background(Color(hex: "f9f9f9"))
        }
    }
}

// MARK: - Profile Setup Confirmation View
struct ProfileSetupConfirmationView: View {
    @EnvironmentObject var onboardingViewModel: OnboardingViewModel
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top spacing
                Color.clear.frame(height: 80)
                
                // Thank you message
                Text("Thank you for trusting us")
                    .font(.system(size: 24, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                
                // Subtitle
                Text("Do you want to set up your first profile and habit?")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                
                Spacer()
                    .frame(maxHeight: 100)
                
                // Yes button - large and prominent
                Button(action: {
                    // Add haptic feedback
                    HapticFeedback.medium()

                    // Navigate to profile creation
                    onboardingViewModel.proceedToProfileSetup()
                }) {
                    Text("Yes")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.black)
                        .cornerRadius(25)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Skip button - smaller and less prominent
                Button(action: {
                    // Add haptic feedback
                    HapticFeedback.light()

                    // Skip to main app
                    onboardingViewModel.skipProfileSetup()
                }) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .underline()
                }
                .padding(.bottom, 50)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "f9f9f9"))
        }
    }
}

// MARK: - Create Profile View moved to ProfileViews.swift

// NOTE: Steps 1-5 have been refactored and moved to OnboardingQuizSteps.swift
// This dramatically reduces code duplication and improves maintainability

// MARK: - Step 6: Paywall View
struct Step6View: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false
    @State private var paywallDismissed = false

    var body: some View {
        OnboardingStepContainer(
            currentStep: 6,
            onBack: viewModel.previousStep
        ) {
            // Superwall Paywall - automatically shows campaign
            PaywallView()
                .onAppear {
                    configureSuperwallHandlers()
                }
        }
    }

    // MARK: - Superwall Integration

    /// Configure Superwall event handlers for paywall lifecycle
    private func configureSuperwallHandlers() {
        // Set user attributes for paywall personalization
        Superwall.shared.setUserAttributes([
            "loved_one_name": viewModel.userAnswers["loved_one_name"] ?? "your loved one",
            "relationship": viewModel.userAnswers["relationship"] ?? "",
            "selected_moments": Array(viewModel.selectedMoments).joined(separator: ", "),
            "emotional_value": viewModel.emotionalValue,
            "onboarding_step": "paywall"
        ])

        print("✅ Superwall user attributes configured for Step 6 paywall")
    }
}

/// Superwall Paywall View Wrapper
struct PaywallView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()

        // Trigger Superwall paywall placement when view controller is created
        DispatchQueue.main.async {
            // Register the paywall placement - Superwall will show the configured campaign
            Superwall.shared.register(placement: "onboarding_paywall")
            print("🎯 Superwall 'onboarding_paywall' placement triggered")
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Reusable Components

// Checkbox Card Component
struct CheckboxCard: View {
    let text: String
    let emoji: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.black : Color.white)
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.leading, 16)
                .animation(.easeInOut(duration: 0.2), value: isSelected)

                // Text and emoji
                HStack(spacing: 8) {
                    Text(text)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(.black)

                    Text(emoji)
                        .font(.system(size: 16))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 16)
            }
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Onboarding Complete View
struct OnboardingCompleteView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                VStack(spacing: 30) {
                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)

                    Text("You're All Set!")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                        .foregroundColor(.black)

                    Text("You can now start creating daily reminders for your elderly loved ones")
                        .font(.system(size: 16, weight: .regular))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .foregroundColor(.secondary)
                        .tracking(-0.5)

                    Spacer()

                    Button(action: {
                        // This will trigger the main app flow
                        viewModel.isComplete = true
                    }) {
                        Text("Start Using halloo")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 50)
                }
                .padding(.horizontal, 12)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color(hex: "6f6f6f").opacity(0.075), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, geometry.size.width * 0.04)
            .background(Color(hex: "f9f9f9"))
        }
    }
}

// LoadingView is defined in ContentView.swift