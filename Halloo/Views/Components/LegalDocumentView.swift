import SwiftUI
import SafariServices

// MARK: - Legal Document Type
enum LegalDocumentType {
    case privacy
    case terms

    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms: return "Terms & Conditions"
        }
    }

    var urlString: String {
        let baseURL = "https://remi-ios-9ad1c.web.app"
        switch self {
        case .privacy: return "\(baseURL)/privacy.html"
        case .terms: return "\(baseURL)/terms.html"
        }
    }
}

// MARK: - Legal Document View (Safari View Controller)
struct LegalDocumentView: View {
    let documentType: LegalDocumentType
    @Environment(\.dismissWithoutAnimation) private var dismissWithoutAnimation

    var body: some View {
        ZStack {
            // Background color
            Color(hex: "f9f9f9")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom header with back button
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

                    Text(documentType.title)
                        .font(.custom("Poppins-Medium", size: 20))
                        .foregroundColor(.black)

                    Spacer()

                    // Invisible spacer for centering
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .medium))
                        .opacity(0)
                        .padding(.trailing, 20)
                }
                .frame(height: 60)
                .background(Color(hex: "f9f9f9"))

                // Safari web view
                SafariView(url: URL(string: documentType.urlString)!)
            }
        }
    }
}

// MARK: - Safari View Controller Wrapper
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false

        let controller = SFSafariViewController(url: url, configuration: config)
        controller.preferredControlTintColor = .black
        controller.preferredBarTintColor = UIColor(hex: "f9f9f9")
        controller.dismissButtonStyle = .close

        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - UIColor Extension for Hex
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
