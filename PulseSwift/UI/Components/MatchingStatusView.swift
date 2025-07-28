//
//  MatchingStatusView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/26/25.
//

import SwiftUI

struct MatchingStatusView: View {
    @ObservedObject var matchingManager: MatchingManager
    @State private var pulseOpacity: Double = 0.3
    @State private var ringScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 24) {
            // Main status display
            ZStack {
                // Animated background rings for searching state
                if matchingManager.matchingStatus == .searching {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                PulseTheme.Colors.primary.opacity(0.2),
                                lineWidth: 2
                            )
                            .frame(width: 120 + CGFloat(index * 40))
                            .scaleEffect(ringScale)
                            .opacity(pulseOpacity)
                            .animation(
                                Animation.easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.3),
                                value: ringScale
                            )
                    }
                }
                
                // Central status circle
                ZStack {
                    Circle()
                        .fill(statusBackgroundColor)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(PulseTheme.Colors.primary, lineWidth: 2)
                        )
                    
                    VStack(spacing: 8) {
                        // Status emoji/icon
                        Text(matchingManager.matchingStatus.emoji)
                            .font(.system(size: 32))
                        
                        // Attempt counter for searching
                        if matchingManager.matchingStatus == .searching {
                            Text("\(matchingManager.currentAttempt)/\(matchingManager.maxAttempts)")
                                .font(PulseTheme.Typography.caption)
                                .foregroundColor(PulseTheme.Colors.primary)
                        }
                    }
                }
            }
            
            // Status description
            VStack(spacing: 8) {
                Text(matchingManager.matchingStatus.description)
                    .font(PulseTheme.Typography.headline)
                    .foregroundColor(PulseTheme.Colors.primary)
                    .multilineTextAlignment(.center)
                
                // Additional info based on status
                Group {
                    switch matchingManager.matchingStatus {
                    case .searching:
                        VStack(spacing: 4) {
                            Text("Searching within \(formattedRadius)")
                                .font(PulseTheme.Typography.caption)
                                .foregroundColor(PulseTheme.Colors.secondary)
                            
                            if matchingManager.currentAttempt > 1 {
                                Text("Expanding search...")
                                    .font(PulseTheme.Typography.caption2)
                                    .foregroundColor(PulseTheme.Colors.accent)
                            }
                        }
                        
                    case .matched:
                        Text("Starting conversation...")
                            .font(PulseTheme.Typography.caption)
                            .foregroundColor(PulseTheme.Colors.accent)
                        
                    case .headedToEther:
                        Text("Your pulse joins the cosmic flow")
                            .font(PulseTheme.Typography.caption)
                            .foregroundColor(PulseTheme.Colors.secondary)
                            .italic()
                        
                    case .error:
                        if let errorMessage = matchingManager.errorMessage {
                            Text(errorMessage)
                                .font(PulseTheme.Typography.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                    default:
                        EmptyView()
                    }
                }
            }
            
            // Action buttons
            actionButtons
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(PulseTheme.Colors.background.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(PulseTheme.Colors.primary.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            startAnimations()
        }
        .onChange(of: matchingManager.matchingStatus) { _, newStatus in
            handleStatusChange(newStatus)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        switch matchingManager.matchingStatus {
        case .searching:
            GlassButton(
                "Cancel",
                style: .secondary
            ) {
                matchingManager.cancelMatching()
            }
            
        case .matched:
            GlassButton(
                "Open Chat",
                style: .primary
            ) {
                // Navigate to chat view
                handleChatNavigation()
            }
            
        case .headedToEther, .error:
            GlassButton(
                "Try Again",
                style: .primary
            ) {
                handleTryAgain()
            }
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusBackgroundColor: Color {
        switch matchingManager.matchingStatus {
        case .searching:
            return PulseTheme.Colors.background.opacity(0.8)
        case .matched:
            return PulseTheme.Colors.accent.opacity(0.2)
        case .headedToEther:
            return PulseTheme.Colors.secondary.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        default:
            return PulseTheme.Colors.background.opacity(0.8)
        }
    }
    
    private var formattedRadius: String {
        let radiusInMiles = matchingManager.searchRadius / 1609.34
        
        if radiusInMiles < 1 {
            return "\(Int(matchingManager.searchRadius)) meters"
        } else if radiusInMiles < 10 {
            return String(format: "%.1f miles", radiusInMiles)
        } else {
            return "\(Int(radiusInMiles)) miles"
        }
    }
    
    // MARK: - Animation Control
    
    private func startAnimations() {
        if matchingManager.matchingStatus == .searching {
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.8
                ringScale = 1.2
            }
        }
    }
    
    private func handleStatusChange(_ newStatus: MatchingStatus) {
        switch newStatus {
        case .searching:
            startAnimations()
        case .matched:
            // Celebratory animation
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                ringScale = 1.0
                pulseOpacity = 1.0
            }
        case .headedToEther:
            // Ethereal fade out animation
            withAnimation(.easeOut(duration: 2.0)) {
                pulseOpacity = 0.1
                ringScale = 2.0
            }
        default:
            // Reset animations
            withAnimation(.easeOut(duration: 0.3)) {
                pulseOpacity = 0.3
                ringScale = 1.0
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleChatNavigation() {
        // This will be implemented when we create the chat view
        print("🗨️ Navigating to chat...")
        
        // Post notification for navigation
        if let match = matchingManager.foundMatch {
            NotificationCenter.default.post(
                name: .navigateToMatch,
                object: match
            )
        }
    }
    
    private func handleTryAgain() {
        // Reset the matching manager and allow user to try again
        matchingManager.reset()
        
        // Post notification to return to camera
        NotificationCenter.default.post(
            name: .navigateToCamera,
            object: nil
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Searching state
        MatchingStatusView(matchingManager: {
            let manager = MatchingManager(locationManager: LocationManager())
            manager.matchingStatus = .searching
            manager.currentAttempt = 2
            manager.searchRadius = 8046.72 // 5 miles
            return manager
        }())
        
        // Matched state
        MatchingStatusView(matchingManager: {
            let manager = MatchingManager(locationManager: LocationManager())
            manager.matchingStatus = .matched
            return manager
        }())
        
        // Ether state
        MatchingStatusView(matchingManager: {
            let manager = MatchingManager(locationManager: LocationManager())
            manager.matchingStatus = .headedToEther
            return manager
        }())
    }
    .padding()
    .background(Color.black)
} 