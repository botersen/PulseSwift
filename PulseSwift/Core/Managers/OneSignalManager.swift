//
//  OneSignalManager.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import OneSignalFramework
import SwiftUI

@MainActor
class OneSignalManager: ObservableObject {
    @Published var isInitialized = false
    @Published var playerId: String?
    @Published var pushToken: String?
    @Published var notificationPermissionStatus: String = "not_determined"
    
    private let appId = "YOUR_ONESIGNAL_APP_ID" // TODO: Replace with your actual OneSignal App ID
    
    init() {
        setupOneSignal()
    }
    
    // MARK: - Setup
    
    private func setupOneSignal() {
        // Initialize OneSignal with basic setup
        OneSignal.initialize(appId, withLaunchOptions: nil)
        
        // Request permission
        OneSignal.Notifications.requestPermission({ accepted in
            DispatchQueue.main.async {
                self.notificationPermissionStatus = accepted ? "authorized" : "denied"
                print("✅ OneSignal notification permission: \(accepted)")
            }
        }, fallbackToSettings: true)
        
        isInitialized = true
        print("✅ OneSignal initialized successfully")
    }
    
    // MARK: - User Identification
    
    func identifyUser(userId: String) {
        OneSignal.login(userId)
        print("✅ OneSignal user identified: \(userId)")
    }
    
    func logoutUser() {
        OneSignal.logout()
        playerId = nil
        print("✅ OneSignal user logged out")
    }
    
    // MARK: - User Properties & Tags
    
    func updateUserProperties(username: String, subscriptionTier: String) {
        // Set user properties
        OneSignal.User.addAlias(label: "username", id: username)
        OneSignal.User.addTag(key: "subscription_tier", value: subscriptionTier)
        OneSignal.User.addTag(key: "app_version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
        
        print("✅ OneSignal user properties updated")
    }
    
    func updateLocation(latitude: Double, longitude: Double, city: String?, country: String?) {
        // Update user location for geotargeted notifications
        OneSignal.User.addTag(key: "latitude", value: String(latitude))
        OneSignal.User.addTag(key: "longitude", value: String(longitude))
        
        if let city = city {
            OneSignal.User.addTag(key: "city", value: city)
        }
        
        if let country = country {
            OneSignal.User.addTag(key: "country", value: country)
        }
        
        print("✅ OneSignal location updated: \(city ?? "Unknown"), \(country ?? "Unknown")")
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            OneSignal.Notifications.requestPermission({ accepted in
                continuation.resume(returning: accepted)
            }, fallbackToSettings: true)
        }
    }
    
    func openNotificationSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Send Test Notification (Development Only)
    
    func sendTestNotification() {
        guard let playerId = playerId else {
            print("❌ No player ID available for test notification")
            return
        }
        
        print("🧪 Test notification would be sent to player: \(playerId)")
        // In production, you'd call your backend API to send notifications
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let navigateToPulse = Notification.Name("navigateToPulse")
    static let navigateToMatch = Notification.Name("navigateToMatch")
    static let navigateToCamera = Notification.Name("navigateToCamera")
} 