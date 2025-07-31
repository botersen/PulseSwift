import Foundation
import CoreLocation
import Combine

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationUpdateActive: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private var lastLocationUpdate: Date?
    private let minimumUpdateInterval: TimeInterval = 30 // 30 seconds
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50 // Update every 50 meters
        
        // Check initial authorization status
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    func requestLocationPermission() async {
        await MainActor.run {
            switch authorizationStatus {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                errorMessage = "Location access is required for pulse matching. Please enable it in Settings."
            case .authorizedWhenInUse, .authorizedAlways:
                // Start location updates on background thread to avoid main thread warning
                Task.detached(priority: .background) { @Sendable [weak self] in
                    self?.startLocationUpdates()
                }
            @unknown default:
                errorMessage = "Unknown location authorization status"
            }
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            DispatchQueue.main.async { @Sendable [weak self] in
                self?.errorMessage = "Location permission not granted"
            }
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            DispatchQueue.main.async { @Sendable [weak self] in
                self?.errorMessage = "Location services are disabled"
            }
            return
        }
        
        DispatchQueue.main.async { @Sendable [weak self] in
            self?.locationManager.startUpdatingLocation()
            self?.isLocationUpdateActive = true
        }
        print("✅ LocationManager: Started location updates")
    }
    
    func stopLocationUpdates() {
        DispatchQueue.main.async { @Sendable [weak self] in
            self?.locationManager.stopUpdatingLocation()
            self?.isLocationUpdateActive = false
        }
        print("✅ LocationManager: Stopped location updates")
    }
    
    func requestOneTimeLocation() async -> CLLocation? {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            await requestLocationPermission()
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { @Sendable [weak self] in
                self?.locationManager.requestLocation()
            }
            
            // Set a timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { @Sendable [weak self] in
                if self?.currentLocation == nil {
                    continuation.resume(returning: nil)
                }
            }
            
            // Wait for location update
            var cancellable: AnyCancellable?
            cancellable = $currentLocation
                .compactMap { $0 }
                .first()
                .sink { location in
                    continuation.resume(returning: location)
                    cancellable?.cancel()
                }
        }
    }
    
    // MARK: - Utility Methods
    func distanceFromCurrentLocation(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }
    
    func isLocationRecent(within interval: TimeInterval = 300) -> Bool {
        guard let lastUpdate = lastLocationUpdate else { return false }
        return Date().timeIntervalSince(lastUpdate) < interval
    }
    
    // MARK: - Permission Status Helpers
    var isLocationPermissionGranted: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var canRequestLocation: Bool {
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }
    
    var shouldShowLocationPermissionAlert: Bool {
        return authorizationStatus == .denied || authorizationStatus == .restricted
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Throttle updates to prevent excessive processing
        if let lastUpdate = lastLocationUpdate,
           Date().timeIntervalSince(lastUpdate) < minimumUpdateInterval {
            return
        }
        
        DispatchQueue.main.async { @Sendable [weak self] in
            self?.currentLocation = location
            self?.lastLocationUpdate = Date()
            self?.errorMessage = nil
        }
        
        print("✅ LocationManager: Updated location: \(location.coordinate)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { @Sendable [weak self] in
            self?.errorMessage = "Location update failed: \(error.localizedDescription)"
            self?.isLocationUpdateActive = false
        }
        
        print("❌ LocationManager: Failed with error: \(error)")
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { @Sendable [weak self] in
            self?.authorizationStatus = status
            
            switch status {
            case .notDetermined:
                print("📍 LocationManager: Authorization not determined")
                
            case .denied, .restricted:
                self?.errorMessage = "Location access denied. Enable in Settings to use pulse matching."
                DispatchQueue.global(qos: .background).async {
                    self?.stopLocationUpdates()
                }
                print("❌ LocationManager: Authorization denied/restricted")
                
            case .authorizedWhenInUse:
                self?.errorMessage = nil
                DispatchQueue.global(qos: .background).async {
                    self?.startLocationUpdates()
                }
                print("✅ LocationManager: Authorization granted (when in use)")
                
            case .authorizedAlways:
                self?.errorMessage = nil
                DispatchQueue.global(qos: .background).async {
                    self?.startLocationUpdates()
                }
                print("✅ LocationManager: Authorization granted (always)")
                
            @unknown default:
                self?.errorMessage = "Unknown location authorization status"
                print("⚠️ LocationManager: Unknown authorization status")
            }
        }
    }
}

// MARK: - Location Utilities
extension LocationManager {
    
    // Calculate bearing between two coordinates
    func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let x = sin(deltaLon) * cos(lat2)
        let y = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(x, y) * 180 / .pi
        return bearing >= 0 ? bearing : bearing + 360
    }
    
    // Check if coordinate is within a certain radius
    func isCoordinate(_ coordinate: CLLocationCoordinate2D, withinRadius radius: CLLocationDistance, of center: CLLocationCoordinate2D) -> Bool {
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return centerLocation.distance(from: targetLocation) <= radius
    }
    
    // Format location for display
    func formatLocation(_ location: CLLocation) -> String {
        return String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
}

// MARK: - Location Errors
extension LocationManager {
    enum LocationError: Error, LocalizedError {
        case permissionDenied
        case locationServicesDisabled
        case timeout
        case unavailable
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Location permission denied"
            case .locationServicesDisabled:
                return "Location services are disabled"
            case .timeout:
                return "Location request timed out"
            case .unavailable:
                return "Location is unavailable"
            }
        }
    }
} 