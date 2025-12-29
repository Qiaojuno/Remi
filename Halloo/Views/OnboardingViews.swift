import SwiftUI
import SuperwallKit
import Lottie

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

// MARK: - Welcome Card Stack (Interactive Preview)
struct WelcomeCardStack: View {
    @State private var stackedCards: [Int] = [0, 1, 2]
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var showCards = false

    // Mock task examples (randomized from common habits)
    // Card 0 is a media card with photo, cards 1-2 are message cards
    private let mockTasks = [
        "Evening photo 🌅",
        "take your medication 🌷",
        "drink some water"
    ]

    // Which cards show as media (photo) cards vs message cards
    private let mediaCardIndices: Set<Int> = [0]

    // Randomized greetings (matching TwilioSMSService)
    private let mockGreetings = [
        "Hi Dad!",
        "Hello Dad 🌞",
        "Hi Dad! Hope you're doing well."
    ]

    // Randomized prompts (matching TwilioSMSService)
    private let mockPrompts = [
        "Time to",
        "A gentle reminder to",
        "Just a little nudge to"
    ]

    // Text-only instructions (matching TwilioSMSService textInstructions)
    private let mockInstructions = [
        "Text back a quick note when you're finished — I'd love to hear 💬",
        "When you're done, send a little message to let me know 🌷",
        "Once you finish, reply with a quick hello — it always makes my day ☀️"
    ]

    // Mock confirmations (matching actual SMS responses)
    private let mockConfirmations = [
        "Done ✅",
        "just took them.",
        "thanks kiddo 👍"
    ]

    // Mock appreciation messages (matching Cloud Functions thankYouMessages)
    private let mockAppreciations = [
        "Thank you! 💙",
        "Got it! That's wonderful 😊",
        "Perfect! Great work ✨"
    ]

    // Profile images for cards
    private let cardFaces = [
        "Card Face 1",
        "Card Face 2",
        "Card Face 1"  // Reuse first face for third card
    ]

    private let sidePadding: CGFloat = 18  // Scaled down 10%: 20 * 0.9
    private var cardWidth: CGFloat {
        // Scaled down 10%: 0.95 * 0.9 = 0.855
        (UIScreen.main.bounds.width - (sidePadding * 2)) * 0.855
    }
    private var cardHeight: CGFloat {
        // Scaled down 10%: 1.4 * 0.9 = 1.26
        cardWidth * 1.26
    }
    private let swipeThreshold: CGFloat = 90  // Scaled down 10%: 100 * 0.9

    var body: some View {
        ZStack {
            ForEach(stackedCards, id: \.self) { cardIndex in
                if showCards {
                    let currentPosition = stackedCards.firstIndex(of: cardIndex) ?? 0

                    mockCard(taskIndex: cardIndex)
                        .scaleEffect(getCardScale(for: currentPosition))
                        .offset(
                            x: currentPosition == 0 ? dragOffset.width : getCardXOffset(for: currentPosition),
                            y: currentPosition == 0 ? dragOffset.height : getCardYOffset(for: currentPosition)
                        )
                        .rotationEffect(.degrees(
                            currentPosition == 0 ? Double(dragOffset.width * 0.02) : getCardRotation(for: currentPosition)
                        ))
                        .zIndex(currentPosition == 0 ? 100 : Double(10 - currentPosition))
                        .animation(currentPosition == 0 && isDragging ? nil : .easeOut(duration: 0.35), value: dragOffset)
                        .animation(currentPosition == 0 && isDragging ? nil : .linear(duration: 0.2), value: stackedCards)
                        .opacity(showCards ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(Double(currentPosition) * 0.1), value: showCards)
                }
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .gesture(DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = CGSize(width: value.translation.width, height: 0)
            }
            .onEnded { value in
                isDragging = false

                if abs(value.translation.width) > swipeThreshold && stackedCards.count > 1 {
                    HapticFeedback.light()

                    let targetX = value.translation.width > 0 ? 405 : -405  // Scaled down 10%: 450 * 0.9
                    dragOffset = CGSize(width: targetX, height: 0)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        let topCard = stackedCards.removeFirst()
                        stackedCards.append(topCard)
                        dragOffset = .zero
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        dragOffset = .zero
                    }
                }
            })
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showCards = true
            }
        }
    }

    private func mockCard(taskIndex: Int) -> some View {
        // Media cards (photo) vs message cards (SMS bubbles)
        if mediaCardIndices.contains(taskIndex) {
            return AnyView(mockMediaCard(taskIndex: taskIndex))
        } else {
            return AnyView(mockMessageCard(taskIndex: taskIndex))
        }
    }

    private func mockMediaCard(taskIndex: Int) -> some View {
        ZStack {
            // Full-bleed photo background
            Image("IMG_3761")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardWidth, height: cardHeight)
                .clipped()

            // Overlay header and bottom banner
            VStack {
                // Header with semi-transparent background for readability
                HStack {
                    Text("\(taskIndex + 1)/\(mockTasks.count)")
                        .font(.system(size: 12.6, weight: .semibold))  // Scaled down 10%: 14 * 0.9
                        .foregroundColor(.white)
                        .padding(.horizontal, 10.8)  // Scaled down 10%: 12 * 0.9
                        .padding(.vertical, 5.4)  // Scaled down 10%: 6 * 0.9
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(.leading, 14.4)  // Scaled down 10%: 16 * 0.9
                        .padding(.top, 14.4)  // Scaled down 10%: 16 * 0.9
                    Spacer()
                }
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 72)  // Scaled down 10%: 80 * 0.9
                )

                Spacer()

                // Bottom banner with task info
                HStack(spacing: 10.8) {  // Scaled down 10%: 12 * 0.9
                    Image(cardFaces[taskIndex])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40.5, height: 40.5)  // Scaled down 10%: 45 * 0.9
                        .clipShape(Circle())

                    Text(mockTasks[taskIndex])
                        .font(.system(size: 14.4, weight: .semibold))  // Scaled down 10%: 16 * 0.9
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("6:45 PM")
                        .font(.system(size: 12.6, weight: .medium))  // Scaled down 10%: 14 * 0.9
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 14.4)  // Scaled down 10%: 16 * 0.9
                .padding(.vertical, 10.8)  // Scaled down 10%: 12 * 0.9
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 90)  // Scaled down 10%: 100 * 0.9
                )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(10)
    }

    private func mockMessageCard(taskIndex: Int) -> some View {
        // Calculate progressive lightening for cards in stack (matching CardStackView)
        // Current position in stack determines lightening amount
        let currentPosition = stackedCards.firstIndex(of: taskIndex) ?? 0
        let baseColorRed: Double = 0.08
        let baseColorGreen: Double = 0.08
        let baseColorBlue: Double = 0.12  // Bluish tint
        let lighteningAmount = Double(currentPosition) * 0.05  // 5% lighter per position
        let cardColor = Color(red: baseColorRed + lighteningAmount,
                             green: baseColorGreen + lighteningAmount,
                             blue: baseColorBlue + lighteningAmount)

        return ZStack {
            cardColor

            VStack {
                // Header with card counter
                HStack {
                    Text("\(taskIndex + 1)/\(mockTasks.count)")
                        .font(.system(size: 12.6, weight: .semibold))  // Scaled down 10%: 14 * 0.9
                        .foregroundColor(.white)
                        .padding(.horizontal, 10.8)  // Scaled down 10%: 12 * 0.9
                        .padding(.vertical, 5.4)  // Scaled down 10%: 6 * 0.9
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(.leading, 14.4)  // Scaled down 10%: 16 * 0.9
                        .padding(.top, 14.4)  // Scaled down 10%: 16 * 0.9
                    Spacer()
                }

                Spacer()

                // SMS bubbles using SpeechBubbleView (matching CardStackView)
                VStack(spacing: 16.2) {  // Scaled down 10%: 18 * 0.9
                    // Outgoing reminder (using randomized greeting + prompt + instructions system)
                    HStack {
                        Spacer(minLength: 0)
                        SpeechBubbleView(
                            text: "\(mockGreetings[taskIndex]) \(mockPrompts[taskIndex]) \(mockTasks[taskIndex]).\n\n\(mockInstructions[taskIndex])",
                            isOutgoing: true,
                            backgroundColor: Color.blue,
                            textColor: .white,
                            maxWidth: 258.3,  // Scaled down 10%: 287 * 0.9
                            scale: 0.765  // Scaled down 10%: 0.85 * 0.9
                        )
                    }

                    // Incoming confirmation (randomized responses)
                    HStack {
                        SpeechBubbleView(
                            text: mockConfirmations[taskIndex],
                            isOutgoing: false,
                            backgroundColor: Color(red: 0.9, green: 0.9, blue: 0.9),
                            textColor: .black,
                            maxWidth: 217.8,  // Scaled down 10%: 242 * 0.9
                            scale: 0.765  // Scaled down 10%: 0.85 * 0.9
                        )
                        Spacer(minLength: 0)
                    }

                    // Thank you reply (randomized appreciation messages)
                    HStack {
                        Spacer(minLength: 0)
                        SpeechBubbleView(
                            text: mockAppreciations[taskIndex],
                            isOutgoing: true,
                            backgroundColor: Color.blue,
                            textColor: .white,
                            maxWidth: 258.3,  // Scaled down 10%: 287 * 0.9
                            scale: 0.765  // Scaled down 10%: 0.85 * 0.9
                        )
                    }
                }
                .padding(.horizontal, 14.4)  // Scaled down 10%: 16 * 0.9

                Spacer()

                // Bottom banner with profile
                HStack(spacing: 10.8) {  // Scaled down 10%: 12 * 0.9
                    Image(cardFaces[taskIndex])
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40.5, height: 40.5)  // Scaled down 10%: 45 * 0.9
                        .clipShape(Circle())

                    Text(mockTasks[taskIndex])
                        .font(.system(size: 14.4, weight: .semibold))  // Scaled down 10%: 16 * 0.9
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    Text("9:30 AM")
                        .font(.system(size: 12.6, weight: .medium))  // Scaled down 10%: 14 * 0.9
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 14.4)  // Scaled down 10%: 16 * 0.9
                .padding(.vertical, 10.8)  // Scaled down 10%: 12 * 0.9
                .background(Color.black.opacity(0.3))
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(10)  // Changed from 9 to 10 to match CardStackView
    }

    // Card positioning helpers (same as CardStackView)
    private func getCardScale(for index: Int) -> CGFloat {
        switch index {
        case 0: return 1.0
        case 1, 2: return 0.98
        default: return 0.96
        }
    }

    private func getCardXOffset(for index: Int) -> CGFloat {
        switch index {
        case 1: return -10.8  // Scaled down 10%: -12 * 0.9
        case 2: return 9  // Scaled down 10%: 10 * 0.9
        default: return 0
        }
    }

    private func getCardYOffset(for index: Int) -> CGFloat {
        switch index {
        case 1: return -18  // Scaled down 10%: -20 * 0.9
        case 2: return 16.2  // Scaled down 10%: 18 * 0.9
        default: return 0
        }
    }

    private func getCardRotation(for index: Int) -> Double {
        switch index {
        case 1: return -2.5
        case 2: return 1.8
        default: return 0
        }
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @State private var showContent = false
    @State private var showingLogin = false
    @State private var currentWordIndex = 0
    @State private var wordOpacity: Double = 1.0

    private let rotatingWords = [
        (text: "Automatically", color: Color(hex: "4A9DFF")),      // Blue
        (text: "Stress Free", color: Color(hex: "A855F7")),        // Purple
        (text: "With Text", color: Color(hex: "10B981"))           // Green
    ]

    private let timer = Timer.publish(every: 3.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Remi Logo at top left
                HStack {
                    Image("Remi Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6), value: showContent)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // Card stack preview
                if showContent {
                    WelcomeCardStack()
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut(duration: 0.6).delay(0.1), value: showContent)

                    // Tagline with rotating gradient words
                    VStack(spacing: 0) {
                        Text("Keep them reminded")
                            .foregroundColor(.black)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1.0)

                        Text(rotatingWords[currentWordIndex].text)
                            .font(.system(size: 28, weight: .bold))
                            .tracking(-1.0)
                            .foregroundColor(rotatingWords[currentWordIndex].color)
                            .shadow(color: rotatingWords[currentWordIndex].color.opacity(0.3), radius: 8, x: 0, y: 2)
                            .opacity(wordOpacity)
                            .animation(.easeInOut(duration: 0.6), value: wordOpacity)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 48)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
                    .onReceive(timer) { _ in
                        // Fade out
                        withAnimation(.easeInOut(duration: 0.6)) {
                            wordOpacity = 0
                        }
                        // Change word and fade in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            currentWordIndex = (currentWordIndex + 1) % rotatingWords.count
                            withAnimation(.easeInOut(duration: 0.6)) {
                                wordOpacity = 1
                            }
                        }
                    }
                }

                Spacer()
                    .frame(height: 24)

                // Buttons section
                VStack(spacing: 16) {
                    // Primary button - Get Started
                    Button(action: {
                        HapticFeedback.medium()
                        viewModel.startQuiz()
                    }) {
                        Text("Get Started")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color.black)
                            .cornerRadius(28)  // Pill-shaped: height/2 = 56/2 = 28
                    }

                    // Secondary button - Already signed up? Log in
                    Button(action: {
                        HapticFeedback.light()
                        showingLogin = true
                    }) {
                        HStack(spacing: 4) {
                            Text("Already signed up?")
                                .foregroundColor(.black)
                            Text("Log in")
                                .foregroundColor(.black)
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 15))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
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
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .onAppear {
            // Show content (cards + tagline) with slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showContent = true
            }
        }
    }
}

// MARK: - Login Sheet View

/// Modal sheet for returning users to log in directly from welcome screen
///
/// Uses shared `AuthButtonsView` component for DRY auth UI.
/// Sets `isComplete = true` on successful auth to bypass onboarding for returning users.
struct LoginSheetView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Welcome back")
                .font(.system(size: 28, weight: .bold))
                .tracking(-1.0)
                .padding(.top, 24)

            // Shared auth buttons component
            // ✅ FIX: Set isComplete = true for returning users logging in from Welcome page
            // This bypasses onboarding since they've already completed it in a previous session
            AuthButtonsView(
                onAppleSignIn: { await viewModel.signInWithApple() },
                onGoogleSignIn: { await viewModel.signInWithGoogle() },
                onAuthComplete: {
                    // Returning users bypass onboarding → go straight to PaywallGateView/Dashboard
                    viewModel.isComplete = true
                    dismiss()
                },
                showPrivacyText: false
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
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

// MARK: - Paywall Step View
struct PaywallStepView: View {
    @EnvironmentObject var viewModel: OnboardingViewModel

    var body: some View {
        PaywallView(onDismiss: {
            handlePaywallDismiss()
        })
        .onAppear {
            configureSuperwallHandlers()
        }
    }

    private func handlePaywallDismiss() {
        // Check if user now has active subscription after paywall dismissal
        _Concurrency.Task { @MainActor in
            let hasSubscription = await SubscriptionManager.shared.hasActiveSubscription()

            if hasSubscription {
                // User successfully subscribed - complete onboarding and go to dashboard
                viewModel.isComplete = true
            } else {
                // User dismissed without subscribing - go back to free trial reminder
                viewModel.previousStep()
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
    }
}

/// Superwall Paywall View Wrapper
struct PaywallView: UIViewControllerRepresentable {
    var onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        viewController.view.backgroundColor = .clear

        // Trigger Superwall paywall placement when view controller is created
        DispatchQueue.main.async {
            // Register the paywall placement - Superwall will show the configured campaign
            Superwall.shared.register(placement: "onboarding_paywall") {
                // This closure is called when the paywall is dismissed
                DispatchQueue.main.async {
                    onDismiss?()
                }
            }
            print("🎯 Superwall 'onboarding_paywall' placement triggered")
        }

        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Paywall Gate View (Subscription Check)

/// ✅ ARCHITECTURE: Subscription gate between authentication and main app
///
/// This view acts as a decision point after successful authentication:
/// - If user has active subscription/trial (via RevenueCat) → Pass through to main app
/// - If user needs subscription → Show Superwall paywall
///
/// Placement triggers are differentiated based on user journey:
/// - New users (< 5 min old account) → "onboarding_paywall"
/// - Returning users (no sub) → "auth_gate_paywall"
///
/// Note: RevenueCat handles trial logic via product configuration, not app-side
struct PaywallGateView<AuthenticatedContent: View>: View {
    @EnvironmentObject var appState: AppState
    @State private var subscriptionStatus: SubscriptionCheckStatus = .checking
    @State private var isNewUser: Bool = false

    let authenticatedContent: AuthenticatedContent

    enum SubscriptionCheckStatus {
        case checking
        case hasSubscription
        case needsSubscription
    }

    init(@ViewBuilder authenticatedContent: () -> AuthenticatedContent) {
        self.authenticatedContent = authenticatedContent()
    }

    var body: some View {
        Group {
            switch subscriptionStatus {
            case .checking:
                LoadingView()
                    .onAppear {
                        checkSubscriptionStatus()
                    }

            case .hasSubscription:
                // ✅ User has subscription (RevenueCat confirms) - show main app
                authenticatedContent

            case .needsSubscription:
                // ❌ No subscription - show paywall
                PaywallGateContent(
                    placement: determinePlacement(),
                    isNewUser: isNewUser,
                    onSubscriptionGranted: {
                        // User subscribed - update state to show dashboard
                        subscriptionStatus = .hasSubscription
                    }
                )
            }
        }
    }

    private func checkSubscriptionStatus() {
        _Concurrency.Task { @MainActor in
            // Check if user has active subscription or trial
            let hasSubscription = await SubscriptionManager.shared.hasActiveSubscription()

            if hasSubscription {
                subscriptionStatus = .hasSubscription
                // ContentView will handle navigation to dashboard
            } else {
                // Determine user state for placement targeting
                await determineUserState()

                subscriptionStatus = .needsSubscription
            }
        }
    }

    private func determineUserState() async {
        // Check if this is a new user (account created recently)
        if let user = appState.currentUser, let createdAt = user.createdAt {
            let accountAge = Date().timeIntervalSince(createdAt)
            isNewUser = accountAge < 300 // Less than 5 minutes old = new user
        } else {
            // No creation date available - assume returning user
            isNewUser = false
        }
    }

    private func determinePlacement() -> String {
        // ✅ SIMPLIFIED: Only 2 placements (RevenueCat handles trial logic)
        // Choose Superwall placement based on user journey
        if isNewUser {
            return "onboarding_paywall" // New user (account < 5 min old)
        } else {
            return "auth_gate_paywall"  // Returning user without subscription
        }
    }
}

// MARK: - Paywall Gate Content

/// Triggers Superwall paywall and handles dismissal
/// - If user subscribes → PaywallGateView will detect and show dashboard
/// - If user dismisses without subscribing → Log out and return to Welcome page
private struct PaywallGateContent: View {
    let placement: String
    let isNewUser: Bool
    let onSubscriptionGranted: () -> Void

    @EnvironmentObject var appState: AppState
    @Environment(\.container) private var container

    var body: some View {
        // Minimal background while Superwall paywall loads
        Color(hex: "f9f9f9")
            .ignoresSafeArea()
            .onAppear {
                triggerSuperwallPaywall()
            }
    }

    private func triggerSuperwallPaywall() {
        // Set user attributes for targeting (RevenueCat handles trial state)
        Superwall.shared.setUserAttributes([
            "user_type": isNewUser ? "new" : "returning",
            "paywall_trigger": "auth_gate"
        ])

        // Register placement with dismissal handler
        Superwall.shared.register(placement: placement) {
            // This handler fires when paywall is dismissed
            // Check if user actually subscribed
            handlePaywallDismissal()
        }
    }

    private func handlePaywallDismissal() {
        _Concurrency.Task { @MainActor in
            let hasSubscription = await SubscriptionManager.shared.hasActiveSubscription()

            if hasSubscription {
                onSubscriptionGranted()
            } else {
                // Log out user and return to welcome page
                let authService = container.resolve(AuthenticationServiceProtocol.self)
                do {
                    try await authService.signOut()
                } catch {
                    #if DEBUG
                    print("⚠️ Sign out failed during paywall restore: \(error.localizedDescription)")
                    #endif
                }
            }
        }
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