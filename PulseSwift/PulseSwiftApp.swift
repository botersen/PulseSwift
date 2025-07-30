//
//  PulseSwiftApp.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI
import OneSignalFramework
import GoogleSignIn

@main
struct PulseSwiftApp: App {
    
    init() {
        // Setup dependencies
        DIContainer.shared.setupServices()
        setupAppConfigurations()
    }
    
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .preferredColorScheme(.dark) // Force dark mode for brand consistency
                .onOpenURL { url in
                    // Handle Google Sign In URL callbacks
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
    
    // MARK: - Setup Methods
    private func setupAppConfigurations() {
        // Register custom fonts
        registerCustomFonts()
        
        // Setup OneSignal
        setupNotifications()
        
        print("✅ PulseSwiftApp: App configurations complete")
    }
    
    private func registerCustomFonts() {
        // Font registration happens automatically via Info.plist
        // But we can verify they're available
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if UIFont(name: "Special Gothic Expanded One", size: 16) != nil {
                print("✅ PulseSwiftApp: Special Gothic font available")
            } else {
                print("⚠️ PulseSwiftApp: Special Gothic font not found")
            }
            
            if UIFont(name: "DM Mono", size: 16) != nil {
                print("✅ PulseSwiftApp: DM Mono font available")
            } else {
                print("⚠️ PulseSwiftApp: DM Mono font not found")
            }
        }
        #endif
    }
    
    private func setupNotifications() {
        // Read OneSignal App ID from Info.plist
        guard let infoDictionary = Bundle.main.infoDictionary,
              let oneSignalAppId = infoDictionary["OneSignalAppID"] as? String,
              oneSignalAppId != "YOUR_ONESIGNAL_APP_ID" else {
            print("⚠️ PulseSwiftApp: OneSignal App ID not configured in Info.plist")
            print("⚠️ Please add your real OneSignal App ID to Info.plist")
            return
        }
        
        // OneSignal initialization
        OneSignal.initialize(oneSignalAppId, withLaunchOptions: nil)
        
        // Request notification permission
        OneSignal.Notifications.requestPermission({ accepted in
            print("User accepted notifications: \(accepted)")
        }, fallbackToSettings: true)
        
        print("✅ PulseSwiftApp: OneSignal configured with App ID: \(oneSignalAppId)")
    }
}

// Use AppCoordinator from Architecture/UI/PulseApp.swift
