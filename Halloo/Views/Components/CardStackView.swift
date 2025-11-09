import SwiftUI

/// Original card stack design showing completed task evidence
/// Empty state: Paper airplane with message
/// Active state: Dark cards with SMS bubbles and stacking effect
struct CardStackView: View {

    // MARK: - Properties
    let events: [GalleryHistoryEvent]
    @Binding var currentTopEvent: GalleryHistoryEvent?
    let imageCache: ImageCacheService
    @State private var stackedEvents: [GalleryHistoryEvent] = []
    @State private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero
    @State private var triggerBounce: Bool = false

    // MARK: - Environment
    @EnvironmentObject private var appState: AppState
    
    // MARK: - Constants
    private let sidePadding: CGFloat = 20 // Padding on each side
    private var cardWidth: CGFloat {
        // Card width: screen width minus side padding, optimized for engagement (~95% of available width)
        (UIScreen.main.bounds.width - (sidePadding * 2)) * 0.95
    }
    private var cardHeight: CGFloat {
        // Card height: taller than wide for vertical card shape (aspect ratio ~1.4:1)
        cardWidth * 1.4
    }
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        VStack(spacing: 0) {
            if stackedEvents.isEmpty {
                emptyCard
            } else {
                cardStack
            }
        }
        .frame(width: cardWidth, height: cardHeight) // Enforce vertical card ratio
        .onAppear {
            stackedEvents = events
            currentTopEvent = stackedEvents.first
        }
        .onChange(of: events) { oldEvents, newEvents in
            stackedEvents = newEvents
            currentTopEvent = newEvents.first
        }
        .onChange(of: stackedEvents) { oldEvents, newEvents in
            currentTopEvent = stackedEvents.first
        }
    }
    
    private var emptyCard: some View {
        // Dark card with subtle bluish tint (night mode aesthetic)
        // Original pure black: Color(red: 0.08, green: 0.08, blue: 0.08)
        let cardColor = Color(red: 0.08, green: 0.08, blue: 0.12)

        return ZStack {
            cardColor

            VStack {
                // Header with card counter
                HStack {
                    Text("1/1")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(.leading, 16)
                        .padding(.top, 16)
                    Spacer()
                }

                Spacer()

                // Bottom banner with waiting message
                HStack(spacing: 12) {
                    // Placeholder profile circle
                    Circle()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 45, height: 45)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.4))
                        )

                    // Waiting message
                    Text("Waiting for messages!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color.black.opacity(0.3)
                )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(10)
    }
    
    private var cardStack: some View {
        ZStack {
            // All cards in one ForEach so they can animate between positions
            ForEach(Array(stackedEvents.enumerated()), id: \.element.id) { originalIndex, event in
                if originalIndex < 5 {
                    // Calculate current visual position after any reordering
                    let currentIndex = stackedEvents.firstIndex(where: { $0.id == event.id }) ?? originalIndex
                    
                    cardView(for: event, cardIndex: currentIndex)
                        .scaleEffect(getCardScale(for: currentIndex))
                        .offset(
                            x: currentIndex == 0 ? dragOffset.width : getCardXOffset(for: currentIndex),
                            y: currentIndex == 0 ? dragOffset.height : getCardYOffset(for: currentIndex)
                        )
                        .rotationEffect(.degrees(
                            currentIndex == 0 ? Double(dragOffset.width * 0.02) : getCardRotation(for: currentIndex)
                        ))
                        .opacity(1.0)
                        .zIndex(currentIndex == 0 ? 100 : Double(10 - currentIndex))
                        .animation(currentIndex == 0 && isDragging ? nil : .easeOut(duration: 0.35), value: dragOffset)
                        .animation(currentIndex == 0 && isDragging ? nil : .linear(duration: 0.2), value: stackedEvents.map(\.id))
                }
            }
        }
        .gesture(DragGesture()
            .onChanged { value in
                isDragging = true
                // Track horizontal movement only
                dragOffset = CGSize(width: value.translation.width, height: 0)
            }
            .onEnded { value in
                isDragging = false

                if abs(value.translation.width) > swipeThreshold && stackedEvents.count > 1 {
                    // Super light haptic feedback on successful swipe
                    HapticFeedback.light()

                    // Smooth exit animation - continue from current position
                    let targetX = value.translation.width > 0 ? 450 : -450
                    dragOffset = CGSize(
                        width: targetX,
                        height: 0
                    )

                    // Reorder after animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        // Move top card to back
                        let topCard = stackedEvents.removeFirst()
                        stackedEvents.append(topCard)

                        // Reset drag offset immediately
                        dragOffset = .zero
                    }
                } else {
                    // Snap back to center
                    withAnimation(.easeOut(duration: 0.3)) {
                        dragOffset = .zero
                    }
                }
            })
    }
    
    // MARK: - Card Positioning Helpers

    private func getCardScale(for index: Int) -> CGFloat {
        switch index {
        case 0: return 1.0      // Front card: full size
        case 1, 2: return 0.98  // Cards 1&2: 98% size (bigger)
        case 3, 4: return 0.96  // Cards 3&4: 96% size (bigger)
        default: return 0.50    // Cards 5+: 50% size
        }
    }

    private func getCardXOffset(for index: Int) -> CGFloat {
        // Corner peeks - coordinated X/Y for diagonal scatter
        switch index {
        case 1: return -12      // Card 1: left (top-left corner)
        case 2: return 10       // Card 2: right (bottom-right corner)
        case 3: return 8        // Card 3: right (top-right corner)
        case 4: return -10      // Card 4: left (bottom-left corner)
        default: return CGFloat(index % 2 == 0 ? -2 : 2)
        }
    }

    private func getCardYOffset(for index: Int) -> CGFloat {
        // Corner peeks - coordinated with X for diagonal scatter
        switch index {
        case 1: return -20      // Card 1: top (top-left corner with X=-12)
        case 2: return 18       // Card 2: bottom (bottom-right corner with X=+10)
        case 3: return -16      // Card 3: top (top-right corner with X=+8)
        case 4: return 22       // Card 4: bottom (bottom-left corner with X=-10)
        default: return CGFloat(-index * 2)
        }
    }

    private func getCardRotation(for index: Int) -> Double {
        // Professional standard: ±2-3° max (Tinder/Bumble style)
        // Subtle rotation that respects padding bounds
        switch index {
        case 1: return -2.5     // Card 1: subtle left tilt
        case 2: return 1.8      // Card 2: slight right tilt (not mirrored)
        case 3: return -1.5     // Card 3: minimal left tilt
        case 4: return 2.2      // Card 4: slight right tilt
        default: return Double(index % 2 == 0 ? -1 : 1)
        }
    }
    
    // MARK: - Helper: Get Original Card Number
    /// Returns the card's original position (1-based) in the events array
    /// This stays consistent even after swipe reordering
    private func getOriginalCardNumber(for event: GalleryHistoryEvent) -> Int {
        if let originalIndex = events.firstIndex(where: { $0.id == event.id }) {
            return originalIndex + 1  // 1-based for display
        }
        return 1  // Fallback
    }

    private func cardView(for event: GalleryHistoryEvent, cardIndex: Int) -> some View {
        // Photo cards: Full-bleed photo as card background
        // Text cards: Dark background with speech bubbles
        let originalCardNumber = getOriginalCardNumber(for: event)

        if event.hasPhoto {
            return AnyView(photoCardView(for: event, cardNumber: originalCardNumber))
        } else {
            return AnyView(textCardView(for: event, cardNumber: originalCardNumber))
        }
    }

    private func photoCardView(for event: GalleryHistoryEvent, cardNumber: Int) -> some View {
        ZStack {
            // Photo fills entire card (background layer)
            Group {
                // Try cached image first (fast path - no decoding needed)
                if let cachedImage = imageCache.getCachedGalleryImage(for: event.id) {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if let photoData = event.photoData, let uiImage = UIImage(data: photoData) {
                    // Fallback: Decode on-the-fly if cache miss (slow path)
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Photo exists but couldn't be loaded - dark fallback with bluish tint
                    Color(red: 0.08, green: 0.08, blue: 0.12)
                    Image(systemName: "photo")
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipped()

            // Overlay header and circle on top of photo
            VStack {
                // Header with semi-transparent background for readability
                HStack {
                    // Clean card counter: "1/5" format in rounded pill
                    // Uses original card number (not current array index)
                    Text("\(cardNumber)/\(events.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(.leading, 16)
                        .padding(.top, 16)
                    Spacer()
                }
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.4), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                )

                Spacer()

                // Bottom banner with task info
                HStack(spacing: 12) {
                    // Profile image using ProfileImageView (single source of truth)
                    if let profile = appState.profiles.first(where: { $0.id == event.profileId }),
                       let profileSlot = appState.profiles.firstIndex(where: { $0.id == event.profileId }) {
                        ProfileImageView(
                            profile: profile,
                            profileSlot: profileSlot,
                            isSelected: false,
                            size: .custom(45)
                        )
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 45, height: 45)
                    }

                    // Task name
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Completion time
                    Text(formatEventTime(event.createdAt))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(10)
    }

    // MARK: - Helper: Format Event Time
    private func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func textCardView(for event: GalleryHistoryEvent, cardNumber: Int) -> some View {
        // Calculate progressive lightening for text cards with subtle bluish tint (night mode aesthetic)
        // Note: Use cardNumber-1 for 0-based calculation
        // Original pure black base: 0.08, 0.08, 0.08
        let baseColorRed: Double = 0.08
        let baseColorGreen: Double = 0.08
        let baseColorBlue: Double = 0.12  // Bluish tint for softer appearance
        let lighteningAmount = Double(cardNumber - 1) * 0.05
        let cardColor = Color(red: baseColorRed + lighteningAmount,
                             green: baseColorGreen + lighteningAmount,
                             blue: baseColorBlue + lighteningAmount)

        return ZStack {
            cardColor

            VStack {
                // Header
                HStack {
                    // Clean card counter: "1/5" format in rounded pill
                    // Uses original card number (not current array index)
                    Text("\(cardNumber)/\(events.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                        )
                        .padding(.leading, 16)
                        .padding(.top, 16)
                    Spacer()
                }

                Spacer()

                // SMS bubbles
                VStack(spacing: 18) {
                    HStack {
                        Spacer(minLength: 0)
                        SpeechBubbleView(
                            text: event.sentMessage ?? "Reminder: \(event.title). Please confirm when completed.",
                            isOutgoing: true,
                            backgroundColor: Color.blue,
                            textColor: .white,
                            maxWidth: 287,
                            scale: 0.85
                        )
                    }

                    HStack {
                        SpeechBubbleView(
                            text: event.textResponse ?? "Completed!",
                            isOutgoing: false,
                            backgroundColor: Color(red: 0.9, green: 0.9, blue: 0.9),
                            textColor: .black,
                            maxWidth: 242,
                            scale: 0.85
                        )
                        Spacer(minLength: 0)
                    }

                    // Reply message (thank you)
                    if let replyMessage = event.replyMessage {
                        HStack {
                            Spacer(minLength: 0)
                            SpeechBubbleView(
                                text: replyMessage,
                                isOutgoing: true,
                                backgroundColor: Color.blue,
                                textColor: .white,
                                maxWidth: 287,
                                scale: 0.85
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)

                Spacer()

                // Bottom banner with task info
                HStack(spacing: 12) {
                    // Profile image using ProfileImageView (single source of truth)
                    if let profile = appState.profiles.first(where: { $0.id == event.profileId }),
                       let profileSlot = appState.profiles.firstIndex(where: { $0.id == event.profileId }) {
                        ProfileImageView(
                            profile: profile,
                            profileSlot: profileSlot,
                            isSelected: false,
                            size: .custom(45)
                        )
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 45, height: 45)
                    }

                    // Task name
                    Text(event.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    // Completion time
                    Text(formatEventTime(event.createdAt))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Color.black.opacity(0.3)  // Solid overlay for text cards (no gradient needed)
                )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .cornerRadius(10)
    }
}

#Preview {
    let imageCache = ImageCacheService()
    return CardStackView(
        events: [],
        currentTopEvent: .constant(nil),
        imageCache: imageCache
    )
    .padding()
}