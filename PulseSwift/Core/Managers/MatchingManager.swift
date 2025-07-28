//
//  MatchingManager.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/26/25.
//

import Foundation
import CoreLocation
import SwiftUI

@MainActor
class MatchingManager: ObservableObject {
    @Published var isSearchingForMatch = false
    @Published var currentAttempt = 0
    @Published var maxAttempts = 5
    @Published var matchingStatus: MatchingStatus = .idle
    @Published var currentPulse: Pulse?
    @Published var foundMatch: PulseMatch?
    @Published var searchRadius: Double = 1609.34 // 1 mile default
    @Published var errorMessage: String?
    
    private var locationManager: LocationManager
    private var matchingTimer: Timer?
    private let attemptDuration: TimeInterval = 30 // 30 seconds per attempt
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    // MARK: - Core Matching Logic
    
    /// Starts the pulse matching process with geographic discovery
    func startMatching(for pulse: Pulse) async {
        guard !isSearchingForMatch else {
            print("⚠️ Already searching for a match")
            return
        }
        
        print("🎯 Starting matching process for pulse: \(pulse.id)")
        
        currentPulse = pulse
        isSearchingForMatch = true
        matchingStatus = .searching
        currentAttempt = 1
        errorMessage = nil
        
        await attemptToFindMatch()
    }
    
    /// Core matching attempt logic
    private func attemptToFindMatch() async {
        guard let pulse = currentPulse else { return }
        
        print("🔍 Attempt \(currentAttempt)/\(maxAttempts) - Searching within \(searchRadius) meters")
        matchingStatus = .searching
        
        do {
            // Find nearby users within radius
            let nearbyUsers = try await findNearbyUsersInRadius()
            
            if nearbyUsers.isEmpty {
                print("📍 No users found in radius, expanding search...")
                await handleNoUsersFound()
            } else {
                // Try to match with available users
                let availableUsers = filterAvailableUsers(nearbyUsers)
                
                if let selectedUser = selectBestMatch(from: availableUsers) {
                    await attemptMatchWithUser(selectedUser, pulse: pulse)
                } else {
                    print("❌ No available users for matching")
                    await handleNoAvailableUsers()
                }
            }
        } catch {
            print("❌ Error during matching attempt: \(error)")
            errorMessage = "Failed to find nearby users: \(error.localizedDescription)"
            await handleMatchingError()
        }
    }
    
    /// Find users within the current search radius
    private func findNearbyUsersInRadius() async throws -> [UserProfile] {
        // Use LocationManager to find nearby users
        return try await locationManager.findNearbyUsers(radiusMeters: searchRadius)
    }
    
    /// Filter users who are available for matching
    private func filterAvailableUsers(_ users: [UserProfile]) -> [UserProfile] {
        return users.filter { user in
            // Filter criteria:
            // 1. User is active (last seen within reasonable time)
            // 2. User hasn't been matched with recently
            // 3. User's preferences allow matching
            
            // For now, return all users (we'll implement these filters later)
            return true
        }
    }
    
    /// Select the best match from available users
    private func selectBestMatch(from users: [UserProfile]) -> UserProfile? {
        guard !users.isEmpty else { return nil }
        
        // For now, randomly select a user
        // Later we can implement smart matching based on:
        // - Proximity
        // - User preferences
        // - Previous interaction history
        // - Language compatibility
        
        return users.randomElement()
    }
    
    /// Attempt to match with a specific user
    private func attemptMatchWithUser(_ user: UserProfile, pulse: Pulse) async {
        print("💫 Attempting to match with user: \(user.username)")
        
        do {
            // Send pulse to the selected user
            let match = try await sendPulseToUser(user, pulse: pulse)
            
            // Wait for user response (with timeout)
            let didAccept = await waitForUserResponse(match: match)
            
            if didAccept {
                await handleSuccessfulMatch(match)
            } else {
                await handleRejectedMatch()
            }
        } catch {
            print("❌ Failed to send pulse to user: \(error)")
            await handleMatchingError()
        }
    }
    
    /// Send pulse to a user and create match record
    private func sendPulseToUser(_ user: UserProfile, pulse: Pulse) async throws -> PulseMatch {
        // Create match record
        let match = PulseMatch(
            id: UUID(),
            pulseId: pulse.id,
            senderId: pulse.senderId,
            recipientId: user.id,
            matchedAt: Date(),
            lastActivityAt: Date(),
            status: .active,
            location: pulse.senderLocation,
            messages: []
        )
        
        // Send via SupabaseService (to be implemented)
        try await SupabaseService.shared.sendPulseToUser(pulse: pulse, recipient: user)
        
        // Send push notification
        await sendMatchNotification(to: user, pulse: pulse)
        
        return match
    }
    
    /// Send push notification to matched user
    private func sendMatchNotification(to user: UserProfile, pulse: Pulse) async {
        // Use OneSignal to send notification
        print("🔔 Sending match notification to \(user.username)")
        // Implementation will be added when we integrate notifications
    }
    
    /// Wait for user response with timeout
    private func waitForUserResponse(match: PulseMatch) async -> Bool {
        print("⏱️ Waiting for user response...")
        
        // Wait for 30 seconds for user response
        return await withCheckedContinuation { continuation in
            matchingTimer = Timer.scheduledTimer(withTimeInterval: attemptDuration, repeats: false) { _ in
                print("⏰ User response timeout")
                continuation.resume(returning: false)
            }
            
            // In a real implementation, we'd listen for real-time response
            // For now, simulate a response
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.matchingTimer?.invalidate()
                // 70% chance of acceptance for testing
                let accepted = Double.random(in: 0...1) > 0.3
                print("📱 Simulated user response: \(accepted ? "Accepted" : "Rejected")")
                continuation.resume(returning: accepted)
            }
        }
    }
    
    // MARK: - Match Outcomes
    
    /// Handle successful match
    private func handleSuccessfulMatch(_ match: PulseMatch) async {
        print("✅ Match successful! Starting conversation...")
        
        foundMatch = match
        matchingStatus = .matched
        isSearchingForMatch = false
        
        // Update pulse status
        if let pulse = currentPulse {
            await updatePulseStatus(pulse, status: .delivered)
        }
        
        // Notify UI about successful match
        NotificationCenter.default.post(
            name: .didFindPulseMatch,
            object: match
        )
    }
    
    /// Handle rejected match - try next attempt
    private func handleRejectedMatch() async {
        print("❌ Match rejected, trying next attempt...")
        
        if currentAttempt < maxAttempts {
            currentAttempt += 1
            await attemptToFindMatch()
        } else {
            await handleAllAttemptsExhausted()
        }
    }
    
    /// Handle no users found in radius
    private func handleNoUsersFound() async {
        if currentAttempt < maxAttempts {
            // Expand search radius for next attempt
            expandSearchRadius()
            currentAttempt += 1
            
            print("📏 Expanded search radius to \(searchRadius) meters for attempt \(currentAttempt)")
            
            // Wait a bit before next attempt
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await attemptToFindMatch()
        } else {
            await handleAllAttemptsExhausted()
        }
    }
    
    /// Handle no available users for matching
    private func handleNoAvailableUsers() async {
        if currentAttempt < maxAttempts {
            currentAttempt += 1
            
            // Wait before next attempt
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await attemptToFindMatch()
        } else {
            await handleAllAttemptsExhausted()
        }
    }
    
    /// Handle all 5 attempts exhausted - "heads to ether"
    private func handleAllAttemptsExhausted() async {
        print("🌌 All attempts exhausted - pulse heads to the ether...")
        
        matchingStatus = .headedToEther
        isSearchingForMatch = false
        
        // Update pulse status to failed
        if let pulse = currentPulse {
            await updatePulseStatus(pulse, status: .failed)
        }
        
        // Show ethereal animation/feedback to user
        NotificationCenter.default.post(
            name: .pulseHeadedToEther,
            object: currentPulse
        )
        
        // Clean up
        currentPulse = nil
        foundMatch = nil
    }
    
    /// Handle matching errors
    private func handleMatchingError() async {
        if currentAttempt < maxAttempts {
            currentAttempt += 1
            
            // Wait before retry
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await attemptToFindMatch()
        } else {
            await handleAllAttemptsExhausted()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Expand search radius for wider discovery
    private func expandSearchRadius() {
        // Progressive radius expansion:
        // Attempt 1: 1 mile
        // Attempt 2: 5 miles  
        // Attempt 3: 10 miles
        // Attempt 4: 25 miles
        // Attempt 5: 50 miles (or global if premium)
        
        switch currentAttempt {
        case 1:
            searchRadius = 1609.34 // 1 mile
        case 2:
            searchRadius = 8046.72 // 5 miles
        case 3:
            searchRadius = 16093.4 // 10 miles
        case 4:
            searchRadius = 40233.6 // 25 miles
        case 5:
            searchRadius = 80467.2 // 50 miles
        default:
            searchRadius = 160934.4 // 100 miles
        }
    }
    
    /// Update pulse status in database
    private func updatePulseStatus(_ pulse: Pulse, status: PulseStatus) async {
        do {
            try await SupabaseService.shared.updatePulseStatus(pulseId: pulse.id, status: status)
            print("✅ Updated pulse status to: \(status)")
        } catch {
            print("❌ Failed to update pulse status: \(error)")
        }
    }
    
    /// Cancel current matching process
    func cancelMatching() {
        print("🛑 Cancelling matching process...")
        
        matchingTimer?.invalidate()
        matchingTimer = nil
        
        isSearchingForMatch = false
        matchingStatus = .cancelled
        currentAttempt = 0
        
        if let pulse = currentPulse {
            Task {
                await updatePulseStatus(pulse, status: .expired)
            }
        }
        
        currentPulse = nil
        foundMatch = nil
        errorMessage = nil
    }
    
    /// Reset matching state
    func reset() {
        cancelMatching()
        matchingStatus = .idle
        searchRadius = 1609.34 // Reset to 1 mile
    }
}

// MARK: - Matching Status

enum MatchingStatus: String, CaseIterable {
    case idle = "idle"
    case searching = "searching"
    case matched = "matched"
    case headedToEther = "headed_to_ether"
    case cancelled = "cancelled"
    case error = "error"
    
    var description: String {
        switch self {
        case .idle:
            return "Ready to send"
        case .searching:
            return "Finding connection..."
        case .matched:
            return "Match found!"
        case .headedToEther:
            return "Heads to the ether..."
        case .cancelled:
            return "Cancelled"
        case .error:
            return "Something went wrong"
        }
    }
    
    var emoji: String {
        switch self {
        case .idle:
            return "🎯"
        case .searching:
            return "🔍"
        case .matched:
            return "✨"
        case .headedToEther:
            return "🌌"
        case .cancelled:
            return "🛑"
        case .error:
            return "❌"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didFindPulseMatch = Notification.Name("didFindPulseMatch")
    static let pulseHeadedToEther = Notification.Name("pulseHeadedToEther")
} 