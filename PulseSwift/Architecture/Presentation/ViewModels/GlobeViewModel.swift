import Foundation
import SwiftUI
import Combine
import CoreLocation
import SceneKit

@MainActor
class GlobeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var stars: [GlobeStarEntity] = []
    @Published var activePulses: [ActivePulseConnectionEntity] = []
    @Published var userLocation: UserLocationEntity?
    @Published var timeRange: GlobeViewStateEntity.TimeRange = .lastWeek
    @Published var isAutoRotating: Bool = true
    @Published var totalPulseCount: Int = 0
    @Published var activePulseCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private var realtimeSubscription: AnyCancellable?
    private var locationUpdateTimer: Timer?
    
    // Injected Dependencies
    @Injected private var globeRepository: GlobeRepositoryProtocol
    @Injected private var locationManager: LocationManager
    @Injected private var supabaseService: SupabaseService
    
    // SceneKit Reference
    weak var sceneView: SCNView?
    
    // MARK: - Initialization
    init() {
        setupBindings()
        loadInitialData()
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.stopRealtimeUpdates()
        }
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Update stars when time range changes
        $timeRange
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadPulseMatches()
                }
            }
            .store(in: &cancellables)
        
        // Update location when location manager changes
        locationManager.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] location in
                Task { @MainActor in
                    await self?.updateUserLocation(location.coordinate)
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            await loadPulseMatches()
            await loadActivePulses()
            await requestLocationPermission()
        }
    }
    
    // MARK: - Public Methods
    func startRealtimeUpdates() {
        setupRealtimeSubscriptions()
        startLocationUpdates()
    }
    
    func stopRealtimeUpdates() {
        realtimeSubscription?.cancel()
        realtimeSubscription = nil
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    func toggleAutoRotation() {
        isAutoRotating.toggle()
        
        if isAutoRotating {
            startGlobeRotation()
        } else {
            stopGlobeRotation()
        }
    }
    
    func refreshData() {
        Task {
            isLoading = true
            await loadPulseMatches()
            await loadActivePulses()
            isLoading = false
        }
    }
    
    // MARK: - Data Loading
    private func loadPulseMatches() async {
        do {
            let matches = try await globeRepository.getPulseMatches(
                timeRange: timeRange.timeInterval,
                limit: 1000
            )
            
            let newStars = matches.map { match in
                GlobeStarEntity(
                    id: match.id,
                    location: match.userLocation,
                    size: match.starSize,
                    color: match.starColor,
                    glowIntensity: match.glowIntensity,
                    pulseMatch: match
                )
            }
            
            stars = newStars
            totalPulseCount = matches.count
            
        } catch {
            errorMessage = "Failed to load pulse matches: \(error.localizedDescription)"
        }
    }
    
    private func loadActivePulses() async {
        do {
            let pulses = try await globeRepository.getActivePulses()
            activePulses = pulses
            activePulseCount = pulses.count
        } catch {
            errorMessage = "Failed to load active pulses: \(error.localizedDescription)"
        }
    }
    
    private func requestLocationPermission() async {
        await locationManager.requestLocationPermission()
    }
    
    // MARK: - Real-time Updates (Temporarily disabled)
    private func setupRealtimeSubscriptions() {
        // TODO: Implement real-time subscriptions with correct Supabase API
        print("Real-time subscriptions temporarily disabled")
    }
    
    private func handleNewPulseMatch(_ payload: [String: Any]) async {
        // TODO: Implement with proper Decodable conformance
        print("New pulse match received (handler disabled)")
    }
    
    private func handleUpdatedPulseMatch(_ payload: [String: Any]) async {
        // Update existing star
        guard let matchId = payload["id"] as? String,
              let uuid = UUID(uuidString: matchId) else { return }
        
        if stars.firstIndex(where: { $0.id == uuid }) != nil {
            // Update star properties based on payload
            await loadPulseMatches() // Reload to get updated data
        }
    }
    
    private func handleLocationUpdate(_ payload: [String: Any]) async {
        // Handle real-time location updates for active pulses
        await loadActivePulses()
    }
    
    // MARK: - Location Updates
    private func startLocationUpdates() {
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateCurrentLocation()
            }
        }
    }
    
    private func updateCurrentLocation() async {
        guard let location = locationManager.currentLocation else { return }
        await updateUserLocation(location.coordinate)
    }
    
    private func updateUserLocation(_ coordinate: CLLocationCoordinate2D) async {
        do {
            try await globeRepository.updateUserLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                accuracy: locationManager.currentLocation?.horizontalAccuracy
            )
        } catch {
            print("Failed to update user location: \(error)")
        }
    }
    
    // MARK: - Globe Animations
    private func startGlobeRotation() {
        guard let sceneView = sceneView,
              let earthNode = sceneView.scene?.rootNode.childNode(withName: "earth", recursively: true) else {
            return
        }
        
        let rotationAction = SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 60.0)
        let repeatAction = SCNAction.repeatForever(rotationAction)
        earthNode.runAction(repeatAction, forKey: "rotation")
    }
    
    private func stopGlobeRotation() {
        guard let sceneView = sceneView,
              let earthNode = sceneView.scene?.rootNode.childNode(withName: "earth", recursively: true) else {
            return
        }
        
        earthNode.removeAction(forKey: "rotation")
    }
    
    private func animateNewStar(_ star: GlobeStarEntity) {
        // Find the star node and animate its appearance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let sceneView = self?.sceneView,
                  let starNode = sceneView.scene?.rootNode.childNode(withName: star.id.uuidString, recursively: true) else {
                return
            }
            
            // Start with zero scale
            starNode.scale = SCNVector3(0, 0, 0)
            
            // Animate to full scale
            let scaleAction = SCNAction.scale(to: 1.0, duration: 0.5)
            scaleAction.timingMode = .easeOut
            starNode.runAction(scaleAction)
            
            // Add extra glow effect for new stars
            let glowAction = SCNAction.sequence([
                SCNAction.scale(to: 1.5, duration: 0.3),
                SCNAction.scale(to: 1.0, duration: 0.3)
            ])
            starNode.runAction(glowAction, forKey: "newStarGlow")
        }
    }
    
    // MARK: - Globe Interaction
    func selectStar(withId starId: UUID) -> GlobeStarEntity? {
        return stars.first { $0.id == starId }
    }
    
    func focusOnLocation(_ coordinate: CLLocationCoordinate2D) {
        guard let sceneView = sceneView else { return }
        
        // Convert to 3D coordinates
        let earthRadius: Float = 1.0
        let lat = Float(coordinate.latitude) * .pi / 180.0
        let lon = Float(coordinate.longitude) * .pi / 180.0
        
        let x = earthRadius * cos(lat) * cos(lon) * 3.0 // Distance from center
        let y = earthRadius * sin(lat) * 3.0
        let z = earthRadius * cos(lat) * sin(lon) * 3.0
        
        // Animate camera to location
        if let cameraNode = sceneView.pointOfView {
            let moveAction = SCNAction.move(to: SCNVector3(x, y, z), duration: 1.0)
            moveAction.timingMode = .easeInEaseOut
            cameraNode.runAction(moveAction)
        }
    }
    
    // MARK: - Data Export (for debugging)
    func exportGlobeData() -> [String: Any] {
        return [
            "totalStars": stars.count,
            "activePulses": activePulses.count,
            "timeRange": timeRange,
            "userLocation": userLocation?.currentLocation != nil ? "\(userLocation!.currentLocation.latitude),\(userLocation!.currentLocation.longitude)" : "Unknown",
            "isAutoRotating": isAutoRotating
        ]
    }
}

// MARK: - Mock Data (for testing)
extension GlobeViewModel {
    func loadMockData() {
        // Create mock pulse matches for testing
        let mockMatches = [
            createMockPulseMatch(lat: 40.7128, lon: -74.0060, duration: 240), // NYC
            createMockPulseMatch(lat: 51.5074, lon: -0.1278, duration: 180), // London
            createMockPulseMatch(lat: 35.6762, lon: 139.6503, duration: 420), // Tokyo
            createMockPulseMatch(lat: -33.8688, lon: 151.2093, duration: 90), // Sydney
            createMockPulseMatch(lat: 37.7749, lon: -122.4194, duration: 360), // SF
        ]
        
        stars = mockMatches.map { match in
            GlobeStarEntity(
                id: match.id,
                location: match.userLocation,
                size: match.starSize,
                color: match.starColor,
                glowIntensity: match.glowIntensity,
                pulseMatch: match
            )
        }
        
        totalPulseCount = stars.count
        
        // Create mock active pulse
        activePulses = [
            ActivePulseConnectionEntity(
                id: UUID(),
                userLocation: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
                partnerLocation: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
                startTime: Date().addingTimeInterval(-60),
                isActive: true
            )
        ]
        
        activePulseCount = activePulses.count
    }
    
    private func createMockPulseMatch(lat: Double, lon: Double, duration: TimeInterval) -> PulseMatchEntity {
        PulseMatchEntity(
            id: UUID(),
            userId: UUID(),
            partnerId: UUID(),
            userLocation: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            partnerLocation: CLLocationCoordinate2D(latitude: lat + 0.1, longitude: lon + 0.1),
            pulseDuration: duration,
            photoCount: Int.random(in: 3...15),
            sessionStartedAt: Date().addingTimeInterval(-Double.random(in: 3600...86400)),
            sessionEndedAt: Date().addingTimeInterval(-Double.random(in: 0...3600)),
            createdAt: Date().addingTimeInterval(-Double.random(in: 0...604800))
        )
    }
} 