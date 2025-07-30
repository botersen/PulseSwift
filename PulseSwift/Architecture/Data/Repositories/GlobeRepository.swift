import Foundation
import CoreLocation
import Combine

// MARK: - Globe Repository Implementation (MVP Mock)
class GlobeRepository: GlobeRepositoryProtocol {
    
    // MARK: - Private Properties
    private let globeUpdatesSubject = PassthroughSubject<GlobeRealtimeUpdateEntity, Never>()
    
    init() {
        // MVP: Mock implementation
    }
    
    // MARK: - Pulse Matches
    func getPulseMatches(timeRange: TimeInterval, limit: Int) async throws -> [PulseMatchEntity] {
        // MVP: Return mock data
        return createMockPulseMatches()
    }
    
    func createPulseMatch(
        partnerId: UUID,
        userLocation: CLLocationCoordinate2D,
        partnerLocation: CLLocationCoordinate2D
    ) async throws -> PulseMatchEntity {
        // MVP: Create mock pulse match
        return PulseMatchEntity(
            id: UUID(),
            userId: UUID(),
            partnerId: partnerId,
            userLocation: userLocation,
            partnerLocation: partnerLocation,
            pulseDuration: 120.0,
            photoCount: 3,
            sessionStartedAt: Date(),
            sessionEndedAt: nil,
            createdAt: Date()
        )
    }
    
    func updatePulseDuration(matchId: UUID, duration: TimeInterval) async throws {
        // MVP: Mock implementation
        print("Mock: Updated pulse duration to \(duration) for match \(matchId)")
    }
    
    func endPulseMatch(matchId: UUID) async throws {
        // MVP: Mock implementation
        print("Mock: Ended pulse match \(matchId)")
    }
    
    // MARK: - User Locations
    func updateUserLocation(
        latitude: Double,
        longitude: Double,
        accuracy: Double? = nil
    ) async throws {
        // MVP: Mock implementation
        print("Mock: Updated user location to \(latitude), \(longitude)")
    }
    
    func getUserLocation(userId: UUID) async throws -> UserLocationEntity? {
        // MVP: Return mock location
        return UserLocationEntity(
            userId: userId,
            currentLocation: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            locationAccuracy: 10.0,
            isActivelyPulsing: false,
            currentPulsePartnerId: nil,
            lastUpdated: Date()
        )
    }
    
    func getNearbyUsers(
        center: CLLocationCoordinate2D,
        radiusMeters: Double
    ) async throws -> [UserLocationEntity] {
        // MVP: Return mock nearby users
        return []
    }
    
    // MARK: - Active Pulses
    func getActivePulses() async throws -> [ActivePulseConnectionEntity] {
        // MVP: Return mock active pulses
        return [
            ActivePulseConnectionEntity(
                id: UUID(),
                userLocation: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                partnerLocation: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                startTime: Date().addingTimeInterval(-60),
                isActive: true
            )
        ]
    }
    
    func startActivePulse(
        partnerId: UUID,
        userLocation: CLLocationCoordinate2D,
        partnerLocation: CLLocationCoordinate2D
    ) async throws -> ActivePulseConnectionEntity {
        // MVP: Create mock active pulse
        return ActivePulseConnectionEntity(
            id: UUID(),
            userLocation: userLocation,
            partnerLocation: partnerLocation,
            startTime: Date(),
            isActive: true
        )
    }
    
    func endActivePulse(pulseId: UUID) async throws {
        // MVP: Mock implementation
        print("Mock: Ended active pulse \(pulseId)")
    }
    
    // MARK: - Pulse History
    func getPulseHistory(userId: UUID, limit: Int) async throws -> [PulseHistoryEntity] {
        // MVP: Return mock pulse history
        return []
    }
    
    func addToPulseHistory(
        pulseMatchId: UUID,
        location: CLLocationCoordinate2D,
        duration: TimeInterval
    ) async throws {
        // MVP: Mock implementation
        print("Mock: Added pulse history for match \(pulseMatchId)")
    }
    
    // MARK: - Real-time Subscriptions
    func subscribeToGlobeUpdates() -> AnyPublisher<GlobeRealtimeUpdateEntity, Never> {
        return globeUpdatesSubject.eraseToAnyPublisher()
    }
    
    func unsubscribeFromGlobeUpdates() {
        // MVP: Mock implementation
        print("Mock: Unsubscribed from globe updates")
    }
    
    // MARK: - Analytics
    func getTotalPulseCount(userId: UUID) async throws -> Int {
        // MVP: Return mock count
        return 42
    }
    
    func getActivePulseCount() async throws -> Int {
        // MVP: Return mock count
        return 3
    }
    
    func getPulseStatsForTimeRange(
        userId: UUID,
        timeRange: TimeInterval
    ) async throws -> GlobePulseStats {
        // MVP: Return mock stats
        return GlobePulseStats(
            totalPulses: 42,
            averageDuration: 180.0,
            longestPulse: 420.0,
            uniquePartners: 12,
            favoriteLocation: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            pulsesThisWeek: 7,
            pulsesThisMonth: 23
        )
    }
    
    // MARK: - Mock Data Generation
    private func createMockPulseMatches() -> [PulseMatchEntity] {
        let locations = [
            (40.7128, -74.0060, "New York"),
            (51.5074, -0.1278, "London"),
            (35.6762, 139.6503, "Tokyo"),
            (-33.8688, 151.2093, "Sydney"),
            (37.7749, -122.4194, "San Francisco"),
            (48.8566, 2.3522, "Paris"),
            (55.7558, 37.6176, "Moscow"),
            (39.9042, 116.4074, "Beijing"),
            (-22.9068, -43.1729, "Rio de Janeiro"),
            (28.6139, 77.2090, "New Delhi")
        ]
        
        var matches: [PulseMatchEntity] = []
        
        for (_, location) in locations.enumerated() {
            let match = PulseMatchEntity(
                id: UUID(),
                userId: UUID(),
                partnerId: UUID(),
                userLocation: CLLocationCoordinate2D(latitude: location.0, longitude: location.1),
                partnerLocation: CLLocationCoordinate2D(latitude: location.0 + 0.1, longitude: location.1 + 0.1),
                pulseDuration: Double.random(in: 60...600), // 1-10 minutes
                photoCount: Int.random(in: 2...15),
                sessionStartedAt: Date().addingTimeInterval(-Double.random(in: 3600...604800)), // Last week
                sessionEndedAt: Date().addingTimeInterval(-Double.random(in: 0...3600)), // Within last hour
                createdAt: Date().addingTimeInterval(-Double.random(in: 0...604800)) // Last week
            )
            matches.append(match)
        }
        
        return matches
    }
} 