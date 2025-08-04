import Foundation
import Combine
import CoreLocation

// MARK: - Shared App State
@MainActor
class AppState: ObservableObject {
    static let shared = AppState()
    
    // MARK: - Published Properties
    @Published var activePulse: SentPulse?
    @Published var pulseRadius: PulseRadius?
    
    private init() {}
    
    // MARK: - Pulse Management
    func sendPulse(radius: PulseRadius, fromLocation: String) {
        let pulse = SentPulse(
            id: UUID(),
            radius: radius,
            originLocation: fromLocation,
            sentAt: Date()
        )
        
        activePulse = pulse
        pulseRadius = radius
        
        print("🚀 AppState: Pulse sent with radius \(radius.rawValue) from \(fromLocation)")
        
        // Simulate pulse duration (3 minutes for demo)
        Task {
            try? await Task.sleep(nanoseconds: 180_000_000_000) // 3 minutes
            await clearActivePulse()
        }
    }
    
    func clearActivePulse() {
        activePulse = nil
        pulseRadius = nil
        print("⚪ AppState: Pulse ended")
    }
}

// MARK: - Sent Pulse Model
struct SentPulse: Identifiable {
    let id: UUID
    let radius: PulseRadius
    let originLocation: String
    let sentAt: Date
    
    var currentLocation: String {
        // Demo: Show pulse traveling through different locations
        let elapsed = Date().timeIntervalSince(sentAt)
        
        switch radius {
        case .local:
            if elapsed < 30 {
                return "\(originLocation) - Local Area"
            } else if elapsed < 60 {
                return "Nearby \(originLocation)"
            } else {
                return "Local Network Complete"
            }
            
        case .regional:
            if elapsed < 45 {
                return "\(originLocation) - Regional"
            } else if elapsed < 90 {
                return "Regional Network - East Coast"
            } else {
                return "Regional Network - Expanding"
            }
            
        case .global:
            if elapsed < 60 {
                return "\(originLocation) - Going Global"
            } else if elapsed < 120 {
                return "Global Network - Americas"
            } else {
                return "Global Network - Worldwide"
            }
        }
    }
}