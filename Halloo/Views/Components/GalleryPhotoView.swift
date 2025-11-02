import SwiftUI

/// Unified Gallery Photo Component - ZERO DUPLICATES
/// 
/// This component consolidates SquarePhotoView, ProfilePhotoView, and PreviewSquarePhotoView
/// into a single, reusable 112x112 square photo display component.
/// 
/// Usage:
/// - Task Response: GalleryPhotoView(event: event, type: .taskResponse)
/// - Profile Photo: GalleryPhotoView(event: event, type: .profilePhoto)
/// - Preview/Mock: GalleryPhotoView(mockPhoto: photo, type: .preview)
struct GalleryPhotoView: View {
    // MARK: - Data Sources
    let event: GalleryHistoryEvent?
    let mockPhoto: MockPhoto?
    let type: PhotoDisplayType
    let profileInitial: String? // Optional profile initial to display (e.g., "G" for "Grandma")
    let profileSlot: Int? // Optional profile slot for color coding (0-4)

    // MARK: - Photo Display Types
    enum PhotoDisplayType {
        case taskResponse    // Task response photos with overlay
        case preview         // Mock/preview photos for development
    }

    // MARK: - Convenience Initializers

    /// Task response photo display with optional profile initial and color
    static func taskResponse(event: GalleryHistoryEvent, profileInitial: String? = nil, profileSlot: Int? = nil) -> GalleryPhotoView {
        GalleryPhotoView(event: event, mockPhoto: nil, type: .taskResponse, profileInitial: profileInitial, profileSlot: profileSlot)
    }

    /// Preview/mock photo display
    static func preview(mockPhoto: MockPhoto) -> GalleryPhotoView {
        GalleryPhotoView(event: nil, mockPhoto: mockPhoto, type: .preview, profileInitial: nil, profileSlot: nil)
    }
    
    // MARK: - Environment
    @EnvironmentObject private var appState: AppState

    // MARK: - Configuration
    private let photoSize: CGFloat = 112 // Standard gallery photo size
    private let cornerRadius: CGFloat = 3 // Figma spec

    // Profile colors (same as ProfileImageView)
    private let profileColors: [Color] = [
        Color(hex: "B9E3FF"),         // Profile slot 0 - light blue
        Color.red,                    // Profile slot 1 - red
        Color.green,                  // Profile slot 2 - green
        Color.purple,                 // Profile slot 3 - purple
        Color.orange                  // Profile slot 4 - orange
    ]

    // Get profile color based on slot
    private var profileColor: Color {
        guard let slot = profileSlot else {
            return Color(hex: "B9E3FF") // Default to light blue
        }
        return profileColors[slot % profileColors.count]
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Main photo content
            photoContent

            // Overlay content (only for task responses)
            if type == .taskResponse {
                overlayContent
            }
        }
        .frame(width: photoSize, height: photoSize)
        .clipped() // Clip any content extending beyond bounds
        .contentShape(Rectangle()) // Restrict tap area to visible bounds
        .cornerRadius(cornerRadius)
    }
    
    // MARK: - Photo Content
    @ViewBuilder
    private var photoContent: some View {
        switch type {
        case .taskResponse:
            taskResponsePhotoContent
        case .preview:
            previewPhotoContent
        }
    }
    
    @ViewBuilder
    private var taskResponsePhotoContent: some View {
        if let event = event {
            if event.photoData == nil && event.hasTextResponse {
            // Text-only response
            textResponsePreview(for: event)
        } else if let photoData = event.photoData,
                  let uiImage = UIImage(data: photoData) {
            // Photo response
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: photoSize, height: photoSize)
                .clipped()
            } else {
                placeholderPhoto
            }
        } else {
            placeholderPhoto
        }
    }
    
    @ViewBuilder
    private var previewPhotoContent: some View {
        // Mock photo placeholder for previews
        placeholderPhoto
    }
    
    // MARK: - Overlay Content
    @ViewBuilder
    private var overlayContent: some View {
        if let event = event, event.photoData != nil {
            // Profile avatar overlay (bottom-right corner) - only for photos with data
            // AND only if profile still exists (not orphaned)
            if profileInitial != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        profileAvatarOverlay(for: event)
                            .padding(.trailing, 8)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private var placeholderPhoto: some View {
        Rectangle()
            .fill(Color(hex: "e8e8e8"))
            .overlay(
                Image(systemName: "photo.fill")
                    .font(.title)
                    .foregroundColor(Color(hex: "b8b8b8"))
            )
    }
    
    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color(hex: "f0f0f0"))
            .overlay(
                ProgressView()
                    .tint(Color(hex: "9f9f9f"))
            )
    }
    
    private func initialPlaceholder(for event: GalleryHistoryEvent) -> some View {
        // Use provided profileInitial if available, otherwise use first letter of profileId
        let initial: String
        if let profileInitial = profileInitial {
            initial = profileInitial
        } else {
            // Fallback: Skip non-letter characters in profileId (e.g., "+" in phone numbers)
            let letters = event.profileId.filter { $0.isLetter }
            initial = String(letters.prefix(1)).uppercased()
        }

        return Rectangle()
            .fill(Color(hex: "f0f0f0"))
            .overlay(
                Text(initial.isEmpty ? "?" : initial)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.black)
            )
    }
    
    private func textResponsePreview(for event: GalleryHistoryEvent) -> some View {
        ZStack {
            // Dark background (match card stack empty card)
            Color(red: 0.08, green: 0.08, blue: 0.08)

            // Middle aligned vertically
            VStack(spacing: 6) {
                // Outgoing message bubble (blue, top right) with 3 lines of broken up bars
                HStack {
                    Spacer()
                    MiniSpeechBubble(
                        textLines: [
                            [(11, 1.5), (13, 1.5), (15, 1.5)],   // Line 1: 3 segments = 2 gaps
                            [(18, 1.5), (17, 1.5)],              // Line 2: 2 segments = 1 gap
                            [(10, 1.5), (14, 1.5), (12, 1.5)]    // Line 3: 3 segments = 2 gaps
                        ],
                        isOutgoing: true,
                        backgroundColor: Color(hex: "007AFF"),
                        tailInset: 8
                    )
                }
                .padding(.trailing, 6)

                // Incoming message bubble (gray, bottom left) with 1 line of broken up bars
                HStack {
                    MiniSpeechBubble(
                        textLines: [
                            [(13, 1.5), (15, 1.5), (10, 1.5)]  // Line 1: 3 segments = 2 gaps
                        ],
                        isOutgoing: false,
                        backgroundColor: Color(hex: "E5E5EA"),
                        tailInset: 8
                    )
                    Spacer()
                }
                .padding(.leading, 6)
            }

            // Profile avatar overlay in bottom right (only if profile still exists)
            if profileInitial != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        profileAvatarOverlay(for: event)
                            .padding(.trailing, 8)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func profileAvatarOverlay(for event: GalleryHistoryEvent) -> some View {
        // Small profile avatar overlay (20x20) in bottom-right corner
        // Shows actual profile photo if available, otherwise initial letter

        // Look up the profile from appState
        if let profile = appState.profiles.first(where: { $0.id == event.profileId }) {
            // Try to display actual profile photo
            if let photoURL = profile.photoURL, !photoURL.isEmpty {
                // Check cache first
                if let cachedImage = appState.imageCache.getCachedImage(for: photoURL) {
                    // Use cached profile photo
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                } else {
                    // Fallback to AsyncImage if not cached
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        // Show initial while loading
                        Circle()
                            .fill(profileColor)
                            .overlay(
                                Text(String(profile.name.prefix(1)).uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.black)
                            )
                    }
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                }
            } else {
                // No photo URL - show initial letter
                Circle()
                    .fill(profileColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(String(profile.name.prefix(1)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                    )
            }
        } else {
            // Profile not found - show fallback initial from profileInitial or event
            let initial = profileInitial ?? String(event.profileId.filter { $0.isLetter }.prefix(1)).uppercased()
            Circle()
                .fill(profileColor)
                .frame(width: 20, height: 20)
                .overlay(
                    Text(initial.isEmpty ? "?" : initial)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.black)
                )
        }
    }
}

// MARK: - Mini Speech Bubble for Gallery (scaled down version with BubbleWithTail)
struct MiniSpeechBubble: View {
    let textLines: [[(width: CGFloat, height: CGFloat)]]  // Array of lines, each line has multiple "words"
    let isOutgoing: Bool
    let backgroundColor: Color
    let tailInset: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 1.5) {
            ForEach(0..<textLines.count, id: \.self) { lineIndex in
                HStack(spacing: 1) {  // 1px spacing between word segments
                    ForEach(0..<textLines[lineIndex].count, id: \.self) { wordIndex in
                        // Text segment - white for blue bubble (outgoing), black for grey bubble (incoming)
                        Rectangle()
                            .fill(isOutgoing ? Color.white : Color.black)
                            .frame(width: textLines[lineIndex][wordIndex].width,
                                   height: textLines[lineIndex][wordIndex].height)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, isOutgoing && textLines.count > 1 ? 9 : 7)
        .background(
            MiniBubbleWithTail(isOutgoing: isOutgoing, cornerRadius: 4, tailSize: 6, tailInset: tailInset)
                .fill(backgroundColor)
        )
    }
}

// MARK: - Mini Bubble With Tail (customizable tail position)
struct MiniBubbleWithTail: Shape {
    let isOutgoing: Bool
    let cornerRadius: CGFloat
    let tailSize: CGFloat
    let tailInset: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        if isOutgoing {
            // Outgoing bubble - tail on bottom right
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

            // Tail closer to right edge
            path.addLine(to: CGPoint(x: width - tailInset, y: height))
            path.addLine(to: CGPoint(x: width - tailInset - tailSize, y: height))
            path.addLine(to: CGPoint(x: width - tailInset, y: height + tailSize))
            path.addLine(to: CGPoint(x: width - tailInset, y: height))

            path.addLine(to: CGPoint(x: cornerRadius, y: height))
            path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        } else {
            // Incoming bubble - tail on bottom left
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            path.addLine(to: CGPoint(x: width - cornerRadius, y: 0))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: width, y: height - cornerRadius))
            path.addArc(center: CGPoint(x: width - cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: cornerRadius, y: height))
            path.addArc(center: CGPoint(x: cornerRadius, y: height - cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

            // Tail closer to left edge
            path.addLine(to: CGPoint(x: 0, y: height - cornerRadius))
            path.addLine(to: CGPoint(x: tailInset, y: height))
            path.addLine(to: CGPoint(x: tailInset + tailSize, y: height))
            path.addLine(to: CGPoint(x: tailInset, y: height + tailSize))
            path.addLine(to: CGPoint(x: tailInset, y: height))
            path.addLine(to: CGPoint(x: 0, y: height - cornerRadius))

            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                       radius: cornerRadius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        return path
    }
}

// MARK: - Mock Photo Support
struct MockPhoto {
    let id: String
    let profileName: String
    // Add other mock properties as needed
}

// MARK: - Preview
#Preview("Gallery Photo Types") {
    let mockEvent = GalleryHistoryEvent(
        id: "preview-event",
        userId: "preview-user",
        profileId: "preview-profile",
        eventType: .taskResponse,
        createdAt: Date(),
        eventData: .taskResponse(GalleryEventData.SMSResponseData(
            taskId: "preview-task",
            textResponse: "Sample response",
            photoData: nil,
            responseType: "text",
            taskTitle: "Take Medication"
        ))
    )
    
    let mockPhoto = MockPhoto(
        id: "preview-photo",
        profileName: "Preview Profile"
    )
    
    VStack(spacing: 20) {
        HStack(spacing: 15) {
            // Task Response and Preview Examples
            GalleryPhotoView.taskResponse(event: mockEvent)
            GalleryPhotoView.preview(mockPhoto: mockPhoto)
        }

        Text("Gallery Photo View - Task Response & Preview")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    .padding()
    .background(Color(hex: "f9f9f9"))
}