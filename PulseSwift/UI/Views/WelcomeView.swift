//
//  WelcomeView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var contentOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 50
    
    var body: some View {
        ZStack {
            // Pure black background like your design
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Clean welcome content - exactly like your design
                VStack(spacing: PulseTheme.Spacing.lg) {
                    Text("Welcome.")
                        .font(PulseTheme.Typography.title1)
                        .foregroundColor(.white)
                        .opacity(contentOpacity)
                    
                    Text("Let's get you\nstarted.")
                        .font(PulseTheme.Typography.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(contentOpacity)
                }
                
                Spacer()
                
                // Get Started button
                GlassButton("GET STARTED") {
                    appState.completeOnboarding()
                    appState.navigateTo(.authentication)
                }
                .padding(.horizontal, PulseTheme.Spacing.lg)
                .opacity(contentOpacity)
                .padding(.bottom, PulseTheme.Spacing.xxl)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                contentOpacity = 1.0
            }
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppState())
} 