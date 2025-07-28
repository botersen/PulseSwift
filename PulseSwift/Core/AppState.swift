//
//  AppState.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .launch
    @Published var isFirstLaunch: Bool = true
    @Published var hasCompletedOnboarding: Bool = false
    
    // Managers
    let locationManager = LocationManager()
    let cameraManager = CameraManager()
    let authManager = AuthenticationManager()
    let oneSignalManager = OneSignalManager()
    let subscriptionManager = SubscriptionManager()
    
    // Core matching system
    @Published var matchingManager: MatchingManager
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        // Initialize matching manager with location manager
        self.matchingManager = MatchingManager(locationManager: locationManager)
        
        loadAppState()
        setupManagerConnections()
    }
    
    func navigateTo(_ screen: AppScreen) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = screen
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: "hasCompletedOnboarding")
    }
    
    private func loadAppState() {
        hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        isFirstLaunch = !userDefaults.bool(forKey: "hasLaunchedBefore")
        
        if isFirstLaunch {
            userDefaults.set(true, forKey: "hasLaunchedBefore")
        }
    }
    
    private func setupManagerConnections() {
        // Connect LocationManager with OneSignal for location updates
        locationManager.setOneSignalManager(oneSignalManager)
        
        // OneSignal is already initialized in its init() method
    }
    
    // MARK: - Pulse Sending Flow
    
    /// Start the complete pulse sending flow with matching
    func sendPulse(mediaURL: String, mediaType: PulseMediaType, caption: String?, targetRadius: Double) async {
        print("🚀 Starting pulse sending flow...")
        
        // Ensure we have current location
        guard let userLocation = locationManager.getCurrentUserLocation() else {
            print("❌ No location available for pulse sending")
            return
        }
        
        // Get current user
        guard let currentUser = authManager.currentUser else {
            print("❌ No authenticated user for pulse sending")
            return
        }
        
        // Create pulse
        let pulse = Pulse(
            senderId: currentUser.id,
            mediaURL: mediaURL,
            mediaType: mediaType,
            caption: caption,
            senderLocation: userLocation,
            targetRadius: targetRadius
        )
        
        do {
            // Save pulse to database
            let savedPulse = try await SupabaseService.shared.createPulse(pulse)
            
            // Start matching process
            await matchingManager.startMatching(for: savedPulse)
            
        } catch {
            print("❌ Failed to create and send pulse: \(error)")
        }
    }
}

enum AppScreen {
    case launch
    case welcome
    case authentication
    case main
} 