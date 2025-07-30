import Foundation
import CoreLocation
import Combine

// MARK: - Globe Repository Protocol
protocol GlobeRepositoryProtocol {
    // MARK: - Pulse Matches
    func getPulseMatches(timeRange: TimeInterval, limit: Int) async throws -> [PulseMatchEntity]
    func createPulseMatch(
        partnerId: UUID,
        userLocation: CLLocationCoordinate2D,
        partnerLocation: CLLocationCoordinate2D
    ) async throws -> PulseMatchEntity
    func updatePulseDuration(matchId: UUID, duration: TimeInterval) async throws
    func endPulseMatch(matchId: UUID) async throws
    
    // MARK: - User Locations
    func updateUserLocation(
        latitude: Double,
        longitude: Double,
        accuracy: Double?
    ) async throws
    func getUserLocation(userId: UUID) async throws -> UserLocationEntity?
    func getNearbyUsers(
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async throws -> [UserLocationEntity]
    
    // MARK: - Active Pulses
    func getActivePulses() async throws -> [ActivePulseConnectionEntity]
    func startActivePulse(
        partnerId: UUID,
        userLocation: CLLocationCoordinate2D,
        partnerLocation: CLLocationCoordinate2D
    ) async throws -> ActivePulseConnectionEntity
    func endActivePulse(pulseId: UUID) async throws
    
    // MARK: - Pulse History
    func getPulseHistory(userId: UUID, limit: Int) async throws -> [PulseHistoryEntity]
    func addToPulseHistory(
        pulseMatchId: UUID,
        location: CLLocationCoordinate2D,
        duration: TimeInterval
    ) async throws
    
    // MARK: - Real-time Subscriptions
    func subscribeToGlobeUpdates() -> AnyPublisher<GlobeRealtimeUpdateEntity, Never>
    func unsubscribeFromGlobeUpdates()
    
    // MARK: - Analytics
    func getTotalPulseCount(userId: UUID) async throws -> Int
    func getActivePulseCount() async throws -> Int
    func getPulseStatsForTimeRange(
        userId: UUID,
        timeRange: TimeInterval
    ) async throws -> GlobePulseStats
}

// MARK: - Supporting Types
struct GlobePulseStats {
    let totalPulses: Int
    let averageDuration: TimeInterval
    let longestPulse: TimeInterval
    let uniquePartners: Int
    let favoriteLocation: CLLocationCoordinate2D?
    let pulsesThisWeek: Int
    let pulsesThisMonth: Int
}

// MARK: - Globe Repository Errors
enum GlobeRepositoryError: Error, LocalizedError {
    case locationPermissionDenied
    case invalidLocation
    case pulseMatchNotFound
    case userNotFound
    case networkError(Error)
    case databaseError(String)
    case encodingError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return "Location permission is required for globe features"
        case .invalidLocation:
            return "Invalid location coordinates provided"
        case .pulseMatchNotFound:
            return "Pulse match not found"
        case .userNotFound:
            return "User not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .encodingError:
            return "Failed to encode data"
        case .decodingError:
            return "Failed to decode data"
        }
    }
} 