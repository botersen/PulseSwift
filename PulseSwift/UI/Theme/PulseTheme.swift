//
//  PulseTheme.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct PulseTheme {
    
    // MARK: - Colors
    struct Colors {
        static let background = Color.black
        static let primary = Color.white
        static let secondary = Color.white.opacity(0.7)
        static let accent = Color.white
        static let error = Color.red
        
        // Glass effect colors
        static let glassBackground = Color.white.opacity(0.1)
        static let glassBorder = Color.white.opacity(0.3)
    }
    
    // MARK: - Typography  
    struct Typography {
        // Try the exact font family name we know exists
        private static func getMonumentFont(size: CGFloat) -> Font {
            // Since we know the family is "PP Monument Extended", try different approaches
            let fontAttempts = [
                "PP Monument Extended Bold",           // Full name
                "PP Monument Extended",                // Family name  
                "PPMonumentExtended-Bold",            // PostScript name
                "PP Monument Extended-Bold",           // Variation
                "Monument Extended Bold",              // Without PP
                "Monument Extended"                    // Simple family
            ]
            
            print("🔍 Testing font names for size \(size):")
            for fontName in fontAttempts {
                let isAvailable = UIFont(name: fontName, size: size) != nil
                print("  \(fontName): \(isAvailable ? "✅ FOUND" : "❌ not found")")
                
                if isAvailable {
                    print("🎉 SUCCESS! Using font: \(fontName)")
                    return Font.custom(fontName, size: size)
                }
            }
            
            print("💥 FALLBACK: Monument Extended not found, using bold system font")
            return Font.system(size: size, weight: .heavy, design: .default)
        }
        
        // All text using Monument Extended Bold (with fallbacks)
        static let largeTitle = getMonumentFont(size: 48)
        static let title1 = getMonumentFont(size: 32)
        static let title2 = getMonumentFont(size: 24)
        static let title3 = getMonumentFont(size: 20)
        
        // Body text - using Monument Extended Bold
        static let headline = getMonumentFont(size: 18)
        static let body = getMonumentFont(size: 16)
        static let bodySmall = getMonumentFont(size: 14)
        static let caption = getMonumentFont(size: 12)
        static let caption2 = getMonumentFont(size: 10)
        
        // Button text
        static let button = getMonumentFont(size: 16)
        static let buttonSmall = getMonumentFont(size: 14)
        
        // Debug helper to check available fonts
        static func debugAvailableFonts() {
            print("Available font families:")
            UIFont.familyNames.sorted().forEach { family in
                print("Family: \(family)")
                UIFont.fontNames(forFamilyName: family).forEach { font in
                    print("  - \(font)")
                }
            }
        }
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
    
    // MARK: - Animations
    struct Animation {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let medium = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.6, dampingFraction: 0.8)
        static let springFast = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let soft = Color.black.opacity(0.1)
        static let medium = Color.black.opacity(0.2)
        static let strong = Color.black.opacity(0.3)
    }
}

// MARK: - Font Extensions for easier usage

extension Font {
    static func monumentExtended(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .bold, .heavy, .black:
            return .custom("PP Monument Extended Bold", size: size)
        default:
            return .custom("PP Monument Extended", size: size)
        }
    }
}

// MARK: - Debug Font Helper

#if DEBUG
extension Font {
    static func debugAvailableFonts() {
        for family in UIFont.familyNames.sorted() {
            print("Family: \(family)")
            for name in UIFont.fontNames(forFamilyName: family).sorted() {
                print("  - \(name)")
            }
        }
    }
}
#endif 