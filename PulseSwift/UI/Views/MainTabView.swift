//
//  MainTabView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var currentTab: MainTab = .camera
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PulseTheme.Colors.background
                    .ignoresSafeArea()
                
                // Tab content
                HStack(spacing: 0) {
                    // Map View (left)
                    GlobeMapView()
                        .frame(width: geometry.size.width)
                        .offset(x: tabOffset(for: .map, screenWidth: geometry.size.width))
                    
                    // Camera View (center - default)
                    CameraView()
                        .frame(width: geometry.size.width)
                        .offset(x: tabOffset(for: .camera, screenWidth: geometry.size.width))
                    
                    // Profile/Settings View (right)
                    ProfileView()
                        .frame(width: geometry.size.width)
                        .offset(x: tabOffset(for: .profile, screenWidth: geometry.size.width))
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            isDragging = false
                            handleSwipeGesture(
                                translation: value.translation.width,
                                screenWidth: geometry.size.width
                            )
                        }
                )
                .animation(
                    isDragging ? .none : PulseTheme.Animation.spring,
                    value: dragOffset
                )
                
                // Tab indicator (optional)
                VStack {
                    Spacer()
                    TabIndicatorView(currentTab: currentTab)
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            // Set initial position to camera
            currentTab = .camera
        }
    }
    
    private func tabOffset(for tab: MainTab, screenWidth: CGFloat) -> CGFloat {
        let baseOffset: CGFloat
        
        switch tab {
        case .map:
            baseOffset = -screenWidth
        case .camera:
            baseOffset = 0
        case .profile:
            baseOffset = screenWidth
        }
        
        return baseOffset + offsetForCurrentTab(screenWidth: screenWidth)
    }
    
    private func offsetForCurrentTab(screenWidth: CGFloat) -> CGFloat {
        switch currentTab {
        case .map:
            return screenWidth
        case .camera:
            return 0
        case .profile:
            return -screenWidth
        }
    }
    
    private func handleSwipeGesture(translation: CGFloat, screenWidth: CGFloat) {
        let threshold: CGFloat = screenWidth * 0.25
        
        if abs(translation) > threshold {
            if translation > 0 {
                // Swipe right
                switch currentTab {
                case .camera:
                    currentTab = .map
                case .profile:
                    currentTab = .camera
                case .map:
                    break // Already at leftmost
                }
            } else {
                // Swipe left
                switch currentTab {
                case .map:
                    currentTab = .camera
                case .camera:
                    currentTab = .profile
                case .profile:
                    break // Already at rightmost
                }
            }
        }
        
        // Reset drag offset
        dragOffset = 0
    }
}

enum MainTab {
    case map
    case camera
    case profile
}

struct TabIndicatorView: View {
    let currentTab: MainTab
    
    var body: some View {
        HStack(spacing: PulseTheme.Spacing.sm) {
            ForEach([MainTab.map, .camera, .profile], id: \.self) { tab in
                Circle()
                    .fill(tab == currentTab ? PulseTheme.Colors.primary : PulseTheme.Colors.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(PulseTheme.Animation.fast, value: currentTab)
            }
        }
        .padding(.horizontal, PulseTheme.Spacing.md)
        .padding(.vertical, PulseTheme.Spacing.sm)
        .background(
            Capsule()
                .fill(PulseTheme.Colors.glassBackground)
                .overlay(
                    Capsule()
                        .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 1)
                )
        )
    }
}

#Preview {
    MainTabView()
} 