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
    
    // MARK: - Computed Properties
    var hasActivePulse: Bool {
        !activePulses.isEmpty
    }
    
    var currentPulseLocation: String {
        guard let firstPulse = activePulses.first else {
            return "Unknown location"
        }
        
        let lat = firstPulse.partnerLocation.latitude
        let lon = firstPulse.partnerLocation.longitude
        
        // Format coordinates with approximate location
        let latStr = String(format: "%.2f", lat)
        let lonStr = String(format: "%.2f", lon)
        
        // Simple region detection based on coordinates
        let region = getRegionName(for: firstPulse.partnerLocation)
        
        return "\(region) (\(latStr), \(lonStr))"
    }
    
    private func getRegionName(for coordinate: CLLocationCoordinate2D) -> String {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // Simple geographic region detection
        if lat >= 25 && lat <= 49 && lon >= -125 && lon <= -66 {
            return "United States"
        } else if lat >= 35 && lat <= 71 && lon >= -10 && lon <= 40 {
            return "Europe"
        } else if lat >= 45 && lat <= 83 && lon >= -141 && lon <= -60 {
            return "Canada"
        } else if lat >= -55 && lat <= -10 && lon >= -82 && lon <= -35 {
            return "South America"
        } else if lat >= -37 && lat <= 38 && lon >= 113 && lon <= 154 {
            return "Australia"
        } else if lat >= 20 && lat <= 46 && lon >= 73 && lon <= 135 {
            return "Asia"
        } else {
            return "Remote Location"
        }
    }
    
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
            
            // Request location permission on background thread
            Task.detached(priority: .background) { @Sendable [weak self] in
                await self?.requestLocationPermission()
            }
        }
    }
    
    // MARK: - Public Methods
    func startRealtimeUpdates() {
        setupRealtimeSubscriptions()
        
        // Start location updates on background thread
        Task.detached(priority: .background) { @Sendable [weak self] in
            await self?.startLocationUpdates()
        }
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
    private func startLocationUpdates() async {
        await MainActor.run { [weak self] in
            self?.locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    await self?.updateCurrentLocation()
                }
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
    
    func addTestPulseLocations() {
        // Simulate real-time pulse activity for demo
        addUserLocationPin()
        addActivePulseMatches()
        addPastPulseMatches()
    }
    
    private func addUserLocationPin() {
        // Add user's current location as a special pin
        guard let userLocation = locationManager.currentLocation else {
            // Fallback to SF for demo
            let demoLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            addUserPin(at: demoLocation)
            return
        }
        addUserPin(at: userLocation.coordinate)
    }
    
    private func addUserPin(at location: CLLocationCoordinate2D) {
        let userPin = GlobeStarEntity(
            id: UUID(),
            location: location,
            size: 1.2, // Larger for user location
            color: .blue, // Distinctive color for user
            glowIntensity: 1.0,
            pulseMatch: nil // No match data for user location
        )
        
        DispatchQueue.main.async {
            // Add user pin to existing stars or replace if exists
            self.stars.removeAll { $0.color == .blue } // Remove old user pin
            self.stars.append(userPin)
            print("📍 Added user location pin at: \(location.latitude), \(location.longitude)")
        }
    }
    
    private func addActivePulseMatches() {
        // Simulate active pulse matches (bright, pulsing)
        let activeLocations = [
            ("Tokyo", CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)),
            ("London", CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
            ("Sydney", CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093))
        ]
        
        let activeStars = activeLocations.enumerated().map { index, location in
            let mockMatch = PulseMatchEntity(
                id: UUID(),
                userId: UUID(),
                partnerId: UUID(),
                userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // User in SF
                partnerLocation: location.1,
                pulseDuration: Double(15 + index * 5), // Active = shorter duration
                photoCount: 1,
                sessionStartedAt: Date(), // Just started
                sessionEndedAt: nil, // Still active
                createdAt: Date()
            )
            
            return GlobeStarEntity(
                id: UUID(),
                location: location.1,
                size: Float(1.0),
                color: .brightYellow, // Bright yellow for active matches
                glowIntensity: Float(1.0), // Full glow for active
                pulseMatch: mockMatch
            )
        }
        
        DispatchQueue.main.async {
            self.stars.append(contentsOf: activeStars)
            print("⚡ Added \(activeStars.count) active pulse matches")
        }
    }
    
    private func addPastPulseMatches() {
        // YC DEMO: 50 diverse pulse matches across all major countries and continents
        let demoLocations = [
            // North America (12 locations)
            ("New York City", CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)),
            ("Los Angeles", CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437)),
            ("Chicago", CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298)),
            ("Miami", CLLocationCoordinate2D(latitude: 25.7617, longitude: -80.1918)),
            ("Toronto", CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)),
            ("Vancouver", CLLocationCoordinate2D(latitude: 49.2827, longitude: -123.1207)),
            ("Mexico City", CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332)),
            ("Austin", CLLocationCoordinate2D(latitude: 30.2672, longitude: -97.7431)),
            ("Seattle", CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)),
            ("Boston", CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589)),
            ("Montreal", CLLocationCoordinate2D(latitude: 45.5017, longitude: -73.5673)),
            ("Denver", CLLocationCoordinate2D(latitude: 39.7392, longitude: -104.9903)),
            
            // Europe (12 locations)
            ("London", CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)),
            ("Paris", CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)),
            ("Berlin", CLLocationCoordinate2D(latitude: 52.5200, longitude: 13.4050)),
            ("Rome", CLLocationCoordinate2D(latitude: 41.9028, longitude: 12.4964)),
            ("Madrid", CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)),
            ("Amsterdam", CLLocationCoordinate2D(latitude: 52.3676, longitude: 4.9041)),
            ("Stockholm", CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686)),
            ("Vienna", CLLocationCoordinate2D(latitude: 48.2082, longitude: 16.3738)),
            ("Barcelona", CLLocationCoordinate2D(latitude: 41.3851, longitude: 2.1734)),
            ("Copenhagen", CLLocationCoordinate2D(latitude: 55.6761, longitude: 12.5683)),
            ("Dublin", CLLocationCoordinate2D(latitude: 53.3498, longitude: -6.2603)),
            ("Prague", CLLocationCoordinate2D(latitude: 50.0755, longitude: 14.4378)),
            
            // Asia (15 locations)
            ("Tokyo", CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503)),
            ("Seoul", CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)),
            ("Singapore", CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198)),
            ("Hong Kong", CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694)),
            ("Mumbai", CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)),
            ("Bangkok", CLLocationCoordinate2D(latitude: 13.7563, longitude: 100.5018)),
            ("Beijing", CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)),
            ("Shanghai", CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)),
            ("Delhi", CLLocationCoordinate2D(latitude: 28.7041, longitude: 77.1025)),
            ("Bangalore", CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946)),
            ("Jakarta", CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456)),
            ("Kuala Lumpur", CLLocationCoordinate2D(latitude: 3.1390, longitude: 101.6869)),
            ("Manila", CLLocationCoordinate2D(latitude: 14.5995, longitude: 120.9842)),
            ("Tel Aviv", CLLocationCoordinate2D(latitude: 32.0853, longitude: 34.7818)),
            ("Dubai", CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708)),
            
            // South America (4 locations)
            ("São Paulo", CLLocationCoordinate2D(latitude: -23.5505, longitude: -46.6333)),
            ("Buenos Aires", CLLocationCoordinate2D(latitude: -34.6037, longitude: -58.3816)),
            ("Rio de Janeiro", CLLocationCoordinate2D(latitude: -22.9068, longitude: -43.1729)),
            ("Lima", CLLocationCoordinate2D(latitude: -12.0464, longitude: -77.0428)),
            
            // Africa (4 locations)
            ("Cairo", CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357)),
            ("Lagos", CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792)),
            ("Cape Town", CLLocationCoordinate2D(latitude: -33.9249, longitude: 18.4241)),
            ("Nairobi", CLLocationCoordinate2D(latitude: -1.2921, longitude: 36.8219)),
            
            // Oceania (3 locations)
            ("Sydney", CLLocationCoordinate2D(latitude: -33.8688, longitude: 151.2093)),
            ("Melbourne", CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)),
            ("Auckland", CLLocationCoordinate2D(latitude: -36.8485, longitude: 174.7633))
        ]
        
        let demoStars = demoLocations.enumerated().map { index, location in
            // Create variety in match types for realistic demo
            let daysSinceMatch = Double(index % 30 + 1) // 1-30 days ago
            let matchQuality = index % 4 // 0-3 quality levels
            let conversationLength = [20, 45, 90, 180][matchQuality] // Different conversation lengths
            let photoCount = [1, 2, 3, 5][matchQuality] // More photos = better matches
            
            let mockMatch = PulseMatchEntity(
                id: UUID(),
                userId: UUID(),
                partnerId: UUID(),
                userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // User in SF
                partnerLocation: location.1,
                pulseDuration: Double(conversationLength + Int.random(in: -10...20)), // Add randomness
                photoCount: photoCount,
                sessionStartedAt: Date().addingTimeInterval(-daysSinceMatch * 86400),
                sessionEndedAt: Date().addingTimeInterval(-daysSinceMatch * 86400 + Double(conversationLength)),
                createdAt: Date().addingTimeInterval(-daysSinceMatch * 86400)
            )
            
            // Vary star appearance based on match quality and recency
            let size: Float = {
                switch matchQuality {
                case 0: return Float.random(in: 0.5...0.7) // Small - brief matches
                case 1: return Float.random(in: 0.7...0.9) // Medium - good matches
                case 2: return Float.random(in: 0.9...1.2) // Large - great matches
                case 3: return Float.random(in: 1.2...1.5) // Extra large - amazing matches
                default: return 0.8
                }
            }()
            
            let color: StarColor = {
                switch matchQuality {
                case 0: return .gray         // Brief encounters
                case 1: return .yellow       // Standard matches
                case 2: return .gold         // Good matches
                case 3: return .brightYellow // Exceptional matches
                default: return .yellow
                }
            }()
            
            let glowIntensity: Float = {
                let baseGlow = Float(matchQuality) * 0.2 + 0.2 // 0.2-0.8 based on quality
                let recencyBoost: Float = daysSinceMatch < 7 ? 0.3 : 0.0 // Recent matches glow more
                return min(1.0, baseGlow + recencyBoost)
            }()
            
            return GlobeStarEntity(
                id: UUID(),
                location: location.1,
                size: size,
                color: color,
                glowIntensity: glowIntensity,
                pulseMatch: mockMatch
            )
        }
        
        DispatchQueue.main.async {
            self.stars.append(contentsOf: demoStars)
            print("🌟 YC DEMO: Added \(demoStars.count) pulse matches across all continents!")
            print("   📊 Quality distribution: Brief(\(demoStars.filter { $0.color == .gray }.count)), Standard(\(demoStars.filter { $0.color == .yellow }.count)), Good(\(demoStars.filter { $0.color == .gold }.count)), Amazing(\(demoStars.filter { $0.color == .brightYellow }.count))")
        }
    }
    
    // MARK: - Real-time Updates
    func startRealTimeUpdates() {
        // Start timer to simulate real-time pulse activity
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.simulateNewPulseActivity()
        }
        print("🎮 Started real-time pulse simulation")
    }
    
    private func simulateNewPulseActivity() {
        // Randomly add new pulse matches to simulate real activity
        let randomLocations = [
            CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522), // Paris
            CLLocationCoordinate2D(latitude: -34.6037, longitude: -58.3816), // Buenos Aires
            CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074), // Beijing
            CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6176), // Moscow
            CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473) // Johannesburg
        ]
        
        guard let randomLocation = randomLocations.randomElement() else { return }
        
        let newMatch = PulseMatchEntity(
            id: UUID(),
            userId: UUID(),
            partnerId: UUID(),
            userLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            partnerLocation: randomLocation,
            pulseDuration: Double.random(in: 10...30),
            photoCount: 1,
            sessionStartedAt: Date(),
            sessionEndedAt: nil,
            createdAt: Date()
        )
        
        let newStar = GlobeStarEntity(
            id: UUID(),
            location: randomLocation,
            size: 1.2, // Larger for new matches
            color: .green, // Bright green for new matches
            glowIntensity: 1.0,
            pulseMatch: newMatch
        )
        
        DispatchQueue.main.async {
            self.stars.append(newStar)
            self.totalPulseCount += 1
            self.activePulseCount += 1
            print("✨ New pulse match added at: \(randomLocation.latitude), \(randomLocation.longitude)")
            
            // Convert to past match after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                if let index = self.stars.firstIndex(where: { $0.id == newStar.id }) {
                    self.stars[index] = GlobeStarEntity(
                        id: newStar.id,
                        location: newStar.location,
                        size: 0.8,
                        color: .gray,
                        glowIntensity: 0.4,
                        pulseMatch: newStar.pulseMatch
                    )
                    self.activePulseCount = max(0, self.activePulseCount - 1)
                    print("⏰ Pulse match moved to past: \(randomLocation.latitude), \(randomLocation.longitude)")
                }
            }
        }
    }
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