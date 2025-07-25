//
//  GlassButton.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct GlassButton: View {
    let title: String
    let action: () -> Void
    let style: GlassButtonStyle
    let isLoading: Bool
    
    @State private var isPressed = false
    
    init(
        _ title: String,
        style: GlassButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }
    
    // Alternative initializer to match AuthenticationView usage
    init(
        title: String,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        style: GlassButtonStyle = .primary
    ) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
        self.style = style
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: PulseTheme.Spacing.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: style.textColor))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(style.font)
                        .fontWeight(.semibold)
                        .foregroundColor(style.textColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: style.height)
            .background(
                ZStack {
                    // Base glass background
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .fill(style.backgroundColor)
                    
                    // Glass border
                    RoundedRectangle(cornerRadius: style.cornerRadius)
                        .strokeBorder(style.borderColor, lineWidth: 1)
                    
                    // Highlight effect
                    if isPressed {
                        RoundedRectangle(cornerRadius: style.cornerRadius)
                            .fill(PulseTheme.Colors.glassBorder)
                    }
                }
            )
            .overlay(
                // Inner glow effect
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(PulseTheme.Animation.fast, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .disabled(isLoading)
    }
}

enum GlassButtonStyle {
    case primary
    case secondary
    case outline
    case small
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return PulseTheme.Colors.glassBackground
        case .secondary:
            return PulseTheme.Colors.glassBackground
        case .outline:
            return Color.clear
        case .small:
            return PulseTheme.Colors.glassBackground
        }
    }
    
    var borderColor: Color {
        switch self {
        case .primary, .small:
            return PulseTheme.Colors.glassBorder
        case .secondary:
            return PulseTheme.Colors.secondary.opacity(0.3)
        case .outline:
            return PulseTheme.Colors.primary.opacity(0.5)
        }
    }
    
    var textColor: Color {
        switch self {
        case .primary, .secondary, .outline, .small:
            return PulseTheme.Colors.primary
        }
    }
    
    var font: Font {
        switch self {
        case .primary, .secondary, .outline:
            return PulseTheme.Typography.body
        case .small:
            return PulseTheme.Typography.bodySmall
        }
    }
    
    var height: CGFloat {
        switch self {
        case .primary, .secondary, .outline:
            return 56
        case .small:
            return 44
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .primary, .secondary, .outline:
            return PulseTheme.CornerRadius.md
        case .small:
            return PulseTheme.CornerRadius.sm
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        GlassButton("GET STARTED", style: .primary) { }
        GlassButton("Secondary", style: .secondary) { }
        GlassButton("Outline", style: .outline) { }
        GlassButton("Small", style: .small) { }
        GlassButton("Loading", style: .primary, isLoading: true) { }
    }
    .padding()
    .background(Color.black)
} 