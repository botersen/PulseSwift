//
//  RadiusSliderView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct RadiusSliderView: View {
    @Binding var selectedRadius: Double
    let maxRadius: Double
    let isPremium: Bool
    
    @State private var sliderPosition: CGFloat = 0.5
    
    private let sliderHeight: CGFloat = 200
    private let minRadius: Double = 1609 // 1 mile in meters
    
    var body: some View {
        HStack {
            Spacer()
            
            VStack(spacing: PulseTheme.Spacing.md) {
                // Radius labels
                VStack(spacing: PulseTheme.Spacing.xs) {
                    Text(radiusDisplayText)
                        .font(PulseTheme.Typography.bodySmall)
                        .foregroundColor(PulseTheme.Colors.primary)
                        .fontWeight(.semibold)
                    
                    Text(isPremium ? "GLOBAL" : "LOCAL")
                        .font(PulseTheme.Typography.caption)
                        .foregroundColor(PulseTheme.Colors.secondary)
                }
                
                // Slider track
                ZStack(alignment: .bottom) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(PulseTheme.Colors.glassBackground)
                        .frame(width: 8, height: sliderHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 1)
                        )
                    
                    // Active track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    PulseTheme.Colors.primary.opacity(0.8),
                                    PulseTheme.Colors.primary.opacity(0.4)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 8, height: sliderHeight * (1 - sliderPosition))
                    
                    // Slider thumb
                    Circle()
                        .fill(PulseTheme.Colors.primary)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .offset(y: -(sliderHeight * sliderPosition) + sliderHeight/2 - 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updateSliderPosition(value.location.y)
                                }
                        )
                    
                    // Premium lock indicator
                    if !isPremium && selectedRadius > SubscriptionTier.free.maxRadiusMeters {
                        VStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(PulseTheme.Colors.accent)
                                .font(.system(size: 12))
                            
                            Text("PREMIUM")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(PulseTheme.Colors.accent)
                        }
                        .padding(.top, PulseTheme.Spacing.xs)
                    }
                }
                
                // Distance labels
                VStack(spacing: PulseTheme.Spacing.xs) {
                    Text("GLOBAL")
                        .font(PulseTheme.Typography.caption)
                        .foregroundColor(isPremium ? PulseTheme.Colors.primary : PulseTheme.Colors.secondary)
                    
                    Text("LOCAL")
                        .font(PulseTheme.Typography.caption)
                        .foregroundColor(PulseTheme.Colors.secondary)
                }
            }
            .padding(.trailing, PulseTheme.Spacing.lg)
        }
        .onAppear {
            updateSliderFromRadius()
        }
        .onChange(of: selectedRadius) { _, _ in
            updateSliderFromRadius()
        }
    }
    
    private var radiusDisplayText: String {
        if selectedRadius >= 1_000_000 { // > 1000km (roughly global)
            return "GLOBAL"
        } else if selectedRadius >= 1609 { // >= 1 mile
            let miles = selectedRadius / 1609.34
            if miles >= 10 {
                return "\(Int(miles)) mi"
            } else {
                return String(format: "%.1f mi", miles)
            }
        } else {
            let feet = selectedRadius * 3.28084
            return "\(Int(feet)) ft"
        }
    }
    
    private func updateSliderPosition(_ location: CGFloat) {
        let newPosition = max(0, min(1, location / sliderHeight))
        sliderPosition = newPosition
        
        // Convert slider position to radius (logarithmic scale)
        let logMin = log(minRadius)
        let logMax = log(maxRadius)
        let logRadius = logMin + (logMax - logMin) * Double(1 - newPosition)
        selectedRadius = exp(logRadius)
        
        // Haptic feedback
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }
    
    private func updateSliderFromRadius() {
        let logMin = log(minRadius)
        let logMax = log(maxRadius)
        let logRadius = log(selectedRadius)
        let position = (logRadius - logMin) / (logMax - logMin)
        sliderPosition = 1 - CGFloat(position)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        RadiusSliderView(
            selectedRadius: .constant(160934),
            maxRadius: Double.greatestFiniteMagnitude,
            isPremium: true
        )
    }
} 