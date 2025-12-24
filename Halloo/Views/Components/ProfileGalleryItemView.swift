import SwiftUI

// MARK: - Profile Gallery Item View
struct ProfileGalleryItemView: View {
    @EnvironmentObject private var appState: AppState

    let event: GalleryHistoryEvent

    // Use the same profile colors from DashboardView
    private let profileColors: [Color] = [
        Color(hex: "B9E3FF"),         // Profile slot 0 - default light blue
        Color.red,                    // Profile slot 1
        Color.green,                  // Profile slot 2
        Color.purple                  // Profile slot 3
    ]
    
    
    var body: some View {
        ZStack {
            // Grey background box (same as existing gallery layout)
            Rectangle()
                .fill(Color(hex: "f0f0f0"))
                .frame(width: 112, height: 112) // Match existing photo dimensions
                .cornerRadius(3) // Match existing corner radius

            // Profile creation content
            VStack(spacing: 8) {
                // Profile picture with thick stroke
                profileImageWithStroke

                // Profile name text
                Text(profileName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "6f6f6f"))
                    .lineLimit(1)
                    .truncationMode(.tail)

                // "Profile Created" label
                Text("Profile Created")
                    .font(.system(size: 8, weight: .regular))
                    .foregroundColor(Color(hex: "9f9f9f"))
                    .lineLimit(1)
            }
        }
        .frame(width: 112, height: 112) // Enforce fixed size
        .clipped() // Clip any content extending beyond bounds
        .contentShape(Rectangle()) // Restrict tap area to visible bounds
    }
    
    // MARK: - Profile Image with Thick Stroke
    private var profileImageWithStroke: some View {
        ZStack {
            // Thick stroke background (Discord-style)
            Circle()
                .stroke(profileStrokeColor, lineWidth: 3)
                .frame(width: 46, height: 46)
            
            // Profile image or emoji
            if let photoURL = event.photoURL {
                // Try cache first to avoid AsyncImage flicker
                if let cachedImage = appState.imageCache.getCachedImage(for: photoURL) {
                    // Use cached image directly - synchronous, no placeholder
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    // Fallback to AsyncImage for first load or cache miss
                    AsyncImage(url: URL(string: photoURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Circle()
                            .fill(profileBackgroundColor)
                            .overlay(
                                Text(profileInitial)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                }
            } else {
                // Initial letter placeholder
                Circle()
                    .fill(profileBackgroundColor)
                    .overlay(
                        Text(profileInitial)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .frame(width: 40, height: 40)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var profileName: String {
        switch event.eventData {
        case .profileCreated(let data):
            return data.profileName
        default:
            return "Profile"
        }
    }
    
    private var profileStrokeColor: Color {
        let slot = event.profileSlot
        return profileColors[slot % profileColors.count]
    }
    
    private var profileBackgroundColor: Color {
        return profileStrokeColor // Full opacity background
    }
    
    private var profileInitial: String {
        String(profileName.prefix(1)).uppercased()
    }
}

// MARK: - Preview Support
#if DEBUG
struct ProfileGalleryItemView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 4) {
            // Preview with different profile slots to show colors
            ForEach(0..<4, id: \.self) { slot in
                ProfileGalleryItemView(
                    event: GalleryHistoryEvent.fromProfileCreation(
                        userId: "user123",
                        profile: ElderlyProfile(
                            id: "profile\(slot)",
                            userId: "user123",
                            name: slot == 0 ? "Grandpa Joe" : 
                                  slot == 1 ? "Grandma Maria" :
                                  slot == 2 ? "Uncle Robert" : "Aunt Sarah",
                            phoneNumber: "+1234567890",
                            relationship: slot == 0 ? "Grandfather" :
                                        slot == 1 ? "Grandmother" :
                                        slot == 2 ? "Uncle" : "Aunt",
                            photoURL: nil,
                            status: .confirmed
                        ),
                        profileSlot: slot
                    )
                )
            }
        }
        .padding()
        .background(Color(hex: "f9f9f9"))
        .previewDisplayName("Profile Gallery Items")
    }
}
#endif