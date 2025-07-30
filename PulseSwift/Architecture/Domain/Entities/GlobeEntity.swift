import Foundation
import CoreLocation

// MARK: - Globe Domain Entities

// MARK: - Pulse Match Entity
struct PulseMatchEntity {
    let id: UUID
    let userId: UUID
    let partnerId: UUID
    let userLocation: CLLocationCoordinate2D
    let partnerLocation: CLLocationCoordinate2D
    let pulseDuration: TimeInterval
    let photoCount: Int
    let sessionStartedAt: Date
    let sessionEndedAt: Date?
    let createdAt: Date
    
    // Computed properties for globe visualization
    var starSize: Float {
        // Base size + duration multiplier (max 3x size)
        let baseSizeMultiplier: Float = 1.0
        let durationMultiplier = Float(min(pulseDuration / 300.0, 2.0)) // Max 2x for 5+ minutes
        return baseSizeMultiplier + durationMultiplier
    }
    
    var glowIntensity: Float {
        // Recent pulses glow brighter
        let hoursSinceCreated = Date().timeIntervalSince(createdAt) / 3600.0
        let intensityMultiplier = max(0.3, 1.0 - Float(hoursSinceCreated / 168.0)) // Fade over 1 week
        return intensityMultiplier
    }
    
    var starColor: StarColor {
        if pulseDuration > 600 { // 10+ minutes
            return .gold
        } else if pulseDuration > 180 { // 3+ minutes
            return .brightYellow
        } else {
            return .yellow
        }
    }
}

// MARK: - User Location Entity
struct UserLocationEntity {
    let userId: UUID
    let currentLocation: CLLocationCoordinate2D
    let locationAccuracy: Double?
    let isActivelyPulsing: Bool
    let currentPulsePartnerId: UUID?
    let lastUpdated: Date
    
    var isLocationRecent: Bool {
        Date().timeIntervalSince(lastUpdated) < 300 // 5 minutes
    }
}

// MARK: - Pulse History Entity (for individual stars)
struct PulseHistoryEntity {
    let id: UUID
    let pulseMatchId: UUID
    let userId: UUID
    let partnerId: UUID
    let pulseLocation: CLLocationCoordinate2D
    let pulseTimestamp: Date
    let starSizeMultiplier: Float
    let totalPulseDuration: TimeInterval
    let createdAt: Date
}

// MARK: - Globe Visual Elements

// MARK: - Star Color Enum
enum StarColor: CaseIterable {
    case yellow
    case brightYellow
    case gold
    
    var rgba: (red: Float, green: Float, blue: Float, alpha: Float) {
        switch self {
        case .yellow:
            return (1.0, 1.0, 0.0, 0.8)
        case .brightYellow:
            return (1.0, 1.0, 0.2, 0.9)
        case .gold:
            return (1.0, 0.84, 0.0, 1.0)
        }
    }
}

// MARK: - Globe Star Entity
struct GlobeStarEntity {
    let id: UUID
    let location: CLLocationCoordinate2D
    let size: Float
    let color: StarColor
    let glowIntensity: Float
    let pulseMatch: PulseMatchEntity
    
    // 3D coordinates for SceneKit
    var sphereCoordinates: (x: Float, y: Float, z: Float) {
        let earthRadius: Float = 1.0 // SceneKit sphere radius
        let lat = Float(location.latitude) * .pi / 180.0
        let lon = Float(location.longitude) * .pi / 180.0
        
        let x = earthRadius * cos(lat) * cos(lon)
        let y = earthRadius * sin(lat)
        let z = earthRadius * cos(lat) * sin(lon)
        
        return (x, y, z)
    }
}

// MARK: - Active Pulse Connection Entity
struct ActivePulseConnectionEntity {
    let id: UUID
    let userLocation: CLLocationCoordinate2D
    let partnerLocation: CLLocationCoordinate2D
    let startTime: Date
    let isActive: Bool
    
    var connectionDuration: TimeInterval {
        Date().timeIntervalSince(startTime)
    }
    
    var pulseLineIntensity: Float {
        // Pulse line fades over time during active connection
        let duration = connectionDuration
        if duration < 60 { // First minute: bright
            return 1.0
        } else if duration < 180 { // Next 2 minutes: medium
            return 0.7
        } else { // Final minute: dim
            return 0.4
        }
    }
}

// MARK: - Globe View State Entity
struct GlobeViewStateEntity {
    var cameraPosition: (latitude: Float, longitude: Float, altitude: Float)
    var rotationSpeed: Float
    var isAutoRotating: Bool
    var selectedStar: UUID?
    var showActivePulses: Bool
    var showHistoricalStars: Bool
    var timeRange: TimeRange
    
    enum TimeRange {
        case last24Hours
        case lastWeek
        case lastMonth
        case allTime
        
        var timeInterval: TimeInterval {
            switch self {
            case .last24Hours: return 86400
            case .lastWeek: return 604800
            case .lastMonth: return 2592000
            case .allTime: return .greatestFiniteMagnitude
            }
        }
    }
}

// MARK: - Globe Interaction Entity
struct GlobeInteractionEntity {
    let starId: UUID
    let interactionType: InteractionType
    let timestamp: Date
    
    enum InteractionType {
        case tap
        case longPress
        case hover
    }
}

// MARK: - Real-time Update Entity
struct GlobeRealtimeUpdateEntity {
    let updateType: UpdateType
    let data: UpdateData
    let timestamp: Date
    
    enum UpdateType {
        case newPulseMatch
        case locationUpdate
        case pulseStarted
        case pulseEnded
        case starSizeUpdate
    }
    
    enum UpdateData {
        case pulseMatch(PulseMatchEntity)
        case userLocation(UserLocationEntity)
        case activePulse(ActivePulseConnectionEntity)
    }
}

// MARK: - Globe Configuration Entity
struct GlobeConfigurationEntity {
    let earthTextureURL: String
    let starTexture: String
    let particleTexture: String
    let maxStarsVisible: Int
    let animationDuration: TimeInterval
    let rotationSpeed: Float
    let cameraConstraints: CameraConstraints
    
    struct CameraConstraints {
        let minAltitude: Float
        let maxAltitude: Float
        let allowedLatitudeRange: ClosedRange<Float>
        let allowedLongitudeRange: ClosedRange<Float>
    }
    
    static let `default` = GlobeConfigurationEntity(
        earthTextureURL: "earth_texture_4k",
        starTexture: "star_glow",
        particleTexture: "particle_glow",
        maxStarsVisible: 1000,
        animationDuration: 0.3,
        rotationSpeed: 0.01,
        cameraConstraints: CameraConstraints(
            minAltitude: 1.2,
            maxAltitude: 5.0,
            allowedLatitudeRange: -90...90,
            allowedLongitudeRange: -180...180
        )
    )
} 