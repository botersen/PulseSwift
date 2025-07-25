//
//  PulseSwiftApp.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI
import OneSignalFramework

@main
struct PulseSwiftApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var oneSignalManager = OneSignalManager()
    @StateObject private var locationManager = LocationManager()
    
    init() {
        // Register custom font at app startup
        registerCustomFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appState)
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
                .environmentObject(oneSignalManager)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark) // Force dark mode for brand consistency
                .onReceive(NotificationCenter.default.publisher(for: .navigateToPulse)) { notification in
                    handleNotificationNavigation(.navigateToPulse, data: notification.object)
                }
                .onReceive(NotificationCenter.default.publisher(for: .navigateToMatch)) { notification in
                    handleNotificationNavigation(.navigateToMatch, data: notification.object)
                }
                .onReceive(NotificationCenter.default.publisher(for: .navigateToCamera)) { notification in
                    handleNotificationNavigation(.navigateToCamera, data: notification.object)
                }
        }
    }
    
    // MARK: - Notification Navigation Handling
    
    private func handleNotificationNavigation(_ type: Notification.Name, data: Any?) {
        // Handle deep linking from push notifications
        switch type {
        case .navigateToPulse:
            // Navigate to specific pulse
            appState.navigateTo(.main)
            print("🔔 Navigating to pulse from notification")
            
        case .navigateToMatch:
            // Navigate to match/conversation
            appState.navigateTo(.main)
            print("🔔 Navigating to match from notification")
            
        case .navigateToCamera:
            // Navigate to camera to send pulse
            appState.navigateTo(.main)
            print("🔔 Navigating to camera from notification")
            
        default:
            break
        }
    }
    
    private func registerCustomFonts() {
        // Register Special Gothic font
        registerFont(fileName: "SpecialGothicExpandedOne-Regular", fontName: "Special Gothic Expanded One")
        
        // Register DM Mono font
        registerFont(fileName: "DMMono-Regular", fontName: "DM Mono")
    }
    
    private func registerFont(fileName: String, fontName: String) {
        guard let fontURL = Bundle.main.url(forResource: fileName, withExtension: "ttf") else {
            print("❌ \(fontName) font file not found in bundle")
            return
        }
        
        guard let fontData = NSData(contentsOf: fontURL),
              let provider = CGDataProvider(data: fontData),
              let font = CGFont(provider) else {
            print("❌ Could not create CGFont for \(fontName)")
            return
        }
        
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterGraphicsFont(font, &error)
        
        if success {
            print("✅ \(fontName) font registered successfully")
        } else {
            if let error = error?.takeRetainedValue() {
                print("❌ \(fontName) font registration failed: \(error)")
            } else {
                print("❌ \(fontName) font registration failed: Unknown error")
            }
        }
    }
}
