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
        // All text using Special Gothic Expanded One
        static let largeTitle = Font.custom("Special Gothic Expanded One", size: 48)
        static let title1 = Font.custom("Special Gothic Expanded One", size: 32)
        static let title2 = Font.custom("Special Gothic Expanded One", size: 24)
        static let title3 = Font.custom("Special Gothic Expanded One", size: 20)
        
        // Body text - using Special Gothic Expanded One
        static let headline = Font.custom("Special Gothic Expanded One", size: 18)
        static let body = Font.custom("Special Gothic Expanded One", size: 16)
        static let bodySmall = Font.custom("Special Gothic Expanded One", size: 14)
        static let caption = Font.custom("Special Gothic Expanded One", size: 12)
        static let caption2 = Font.custom("Special Gothic Expanded One", size: 10)
        
        // Button text
        static let button = Font.custom("Special Gothic Expanded One", size: 16)
        static let buttonSmall = Font.custom("Special Gothic Expanded One", size: 14)
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
    static func specialGothic(size: CGFloat) -> Font {
        return .custom("Special Gothic Expanded One", size: size)
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