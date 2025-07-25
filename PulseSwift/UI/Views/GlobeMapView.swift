//
//  GlobeMapView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI
import SceneKit

struct GlobeMapView: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            PulseTheme.Colors.background
                .ignoresSafeArea()
            
            VStack {
                // Header
                Text("PULSE")
                    .font(.custom("MonumentExtended-Regular", size: 24))
                    .fontWeight(.bold)
                    .foregroundColor(PulseTheme.Colors.primary)
                    .padding(.top, 60)
                
                Spacer()
                
                // 3D Globe placeholder
                ZStack {
                    // Background circle
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    PulseTheme.Colors.glassBackground,
                                    PulseTheme.Colors.glassBackground
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .overlay(
                            Circle()
                                .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 1)
                        )
                    
                    // Globe grid lines
                    ForEach(0..<6) { i in
                        Circle()
                            .stroke(PulseTheme.Colors.primary.opacity(0.1), lineWidth: 1)
                            .frame(width: CGFloat(60 + i * 40), height: CGFloat(60 + i * 40))
                    }
                    
                    // Rotating elements
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(PulseTheme.Colors.primary.opacity(0.1))
                            .frame(width: 300, height: 2)
                            .rotationEffect(.degrees(rotation + Double(i * 60)))
                    }
                    
                    // Pulse stars (past matches)
                    ForEach(0..<5) { i in
                        PulseStarView()
                            .offset(
                                x: cos(Double(i) * 1.2 + rotation * 0.01) * 120,
                                y: sin(Double(i) * 1.2 + rotation * 0.01) * 120
                            )
                    }
                    
                    // Center text
                    VStack(spacing: PulseTheme.Spacing.sm) {
                        Text("Your Pulse Map")
                            .font(PulseTheme.Typography.body)
                            .foregroundColor(PulseTheme.Colors.primary)
                            .fontWeight(.semibold)
                        
                        Text("5 connections made")
                            .font(PulseTheme.Typography.bodySmall)
                            .foregroundColor(PulseTheme.Colors.secondary)
                    }
                }
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }
                
                Spacer()
                
                // Map controls
                HStack(spacing: PulseTheme.Spacing.lg) {
                    GlassButton("View All", style: .small) {
                        // Show all matches
                    }
                    
                    GlassButton("Settings", style: .small) {
                        // Open settings
                    }
                }
                .padding(.bottom, 100)
            }
        }
    }
}

struct PulseStarView: View {
    @State private var isGlowing = false
    
    var body: some View {
        Image(systemName: "star.fill")
            .foregroundColor(.yellow)
            .font(.system(size: 12))
            .scaleEffect(isGlowing ? 1.2 : 1.0)
            .opacity(isGlowing ? 1.0 : 0.7)
            .animation(
                .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                value: isGlowing
            )
            .onAppear {
                isGlowing = true
            }
    }
}

#Preview {
    GlobeMapView()
} 