//
//  LaunchView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct LaunchView: View {
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.9
    @State private var showMainApp = false
    
    var body: some View {
        if showMainApp {
            // Navigate to the main app (using existing WelcomeView)
            WelcomeView()
        } else {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    Text("PULSE")
                        .font(.custom("Special Gothic Expanded One", size: calculateFontSize(for: geometry.size.width)))
                        .foregroundColor(.white)
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                        .padding(.horizontal, 18) // ~quarter inch padding on each side
                }
            }
            .onAppear {
                // Start the logo animation
                withAnimation(.easeOut(duration: 0.8)) {
                    logoOpacity = 1.0
                    logoScale = 1.0
                }
                
                // After animation completes, wait 2 more seconds then transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { // 0.8s animation + 2s hang time
                    showMainApp = true
                }
            }
        }
    }
    
    private func calculateFontSize(for screenWidth: CGFloat) -> CGFloat {
        // Calculate font size to fill width minus padding (36 points = ~half inch total)
        // Using a rough estimation that works well with Monument Extended's character width
        let availableWidth = screenWidth - 36
        return availableWidth * 0.25 // Reduced to prevent text wrapping
    }
}

#Preview {
    LaunchView()
} 