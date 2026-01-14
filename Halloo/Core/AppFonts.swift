import SwiftUI
import UIKit

// MARK: - Simple Font Registration
/// Registers custom fonts and provides basic access
struct AppFonts {
    
    // MARK: - Font Registration
    /// Registers custom fonts with the system
    static func registerFonts() {
        registerFont(named: "Inter-VariableFont_opsz,wght", extension: "ttf")
        registerFont(named: "Poppins-Regular", extension: "ttf")
        registerFont(named: "Poppins-Medium", extension: "ttf")
        registerFont(named: "Poppins-SemiBold", extension: "ttf")
    }
    
    private static func registerFont(named fontName: String, extension: String) {
        guard let fontURL = Bundle.main.url(forResource: fontName, withExtension: `extension`) else {
            print("❌ Failed to load \(fontName).\(`extension`)")
            return
        }

        var error: Unmanaged<CFError>?
        // Use CTFontManagerRegisterFontsForURL (iOS 13+) instead of deprecated CTFontManagerRegisterGraphicsFont (iOS 18+)
        if !CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, &error) {
            print("❌ Failed to register \(fontName): \(error.debugDescription)")
        } else {
            print("✅ Successfully registered \(fontName)")
        }
    }
    
    // MARK: - Basic Font Access
    /// Use Poppins font when needed
    static func poppins(size: CGFloat) -> Font {
        return .custom("Poppins-Regular", size: size)
    }
    
    /// Use Poppins Medium font when needed
    static func poppinsMedium(size: CGFloat) -> Font {
        return .custom("Poppins-Medium", size: size)
    }

    /// Use Poppins SemiBold font when needed (600 weight - more visible than Medium)
    static func poppinsSemiBold(size: CGFloat) -> Font {
        return .custom("Poppins-SemiBold", size: size)
    }

    /// Use Inter Variable font when needed  
    static func inter(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .custom("Inter-Variable", size: size).weight(weight)
    }
    
    // MARK: - Debug Utilities
    #if DEBUG
    /// Prints available custom fonts for debugging
    static func printAvailableFonts() {
        print("📝 Available custom fonts:")
        for family in UIFont.familyNames.sorted() {
            if family.contains("Inter") || family.contains("Poppins") {
                print("  🎯 \(family)")
                for font in UIFont.fontNames(forFamilyName: family) {
                    print("    - \(font)")
                }
            }
        }
    }
    #endif
}

// MARK: - Usage Examples
/*
 Simple usage when you want custom fonts:
 
 // Use Poppins for special titles
 Text("Create a New Habit")
     .font(AppFonts.poppins(size: 34))
 
 // Use Inter Variable for body text
 Text("Description text")
     .font(AppFonts.inter(size: 16, weight: .light))
 
 // Or use the normal system font most of the time
 Text("Regular text")
     .font(.system(size: 16, weight: .medium))
*/