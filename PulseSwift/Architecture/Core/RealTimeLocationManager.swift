import Foundation
import CoreLocation
import Combine

// MARK: - Real-Time Location Manager
@MainActor
class RealTimeLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = RealTimeLocationManager()
    
    // MARK: - Published Properties
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var currentLocationName: String = "Locating..."
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocating: Bool = false
    
    // MARK: - Private Properties
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // Update every 100 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            print("❌ Location access denied")
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            break
        }
    }
    
    func startLocationUpdates() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("❌ Location not authorized")
            return
        }
        
        isLocating = true
        locationManager.startUpdatingLocation()
        print("📍 Started location updates")
    }
    
    func stopLocationUpdates() {
        isLocating = false
        locationManager.stopUpdatingLocation()
        print("⏹️ Stopped location updates")
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location.coordinate
        print("📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        print("📍 Is this Toledo area? Lat should be ~41.6, Lon should be ~-83.5")
        
        // Reverse geocode to get location name
        reverseGeocode(location: location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location error: \(error.localizedDescription)")
        isLocating = false
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        print("📍 Location authorization changed: \(status.rawValue)")
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            print("❌ Location access denied")
            isLocating = false
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    // MARK: - Reverse Geocoding
    private func reverseGeocode(location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                if let error = error {
                    print("❌ Geocoding error: \(error.localizedDescription)")
                    self?.currentLocationName = "Unknown Location"
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    self?.currentLocationName = "Unknown Location"
                    return
                }
                
                // Format location name
                let city = placemark.locality ?? ""
                let state = placemark.administrativeArea ?? ""
                let country = placemark.country ?? ""
                
                if !city.isEmpty && !state.isEmpty && !country.isEmpty {
                    self?.currentLocationName = "\(city), \(state) \(country)"
                } else if !city.isEmpty && !country.isEmpty {
                    self?.currentLocationName = "\(city), \(country)"
                } else if !country.isEmpty {
                    self?.currentLocationName = country
                } else {
                    self?.currentLocationName = "Current Location"
                }
                
                print("📍 Location name: \(self?.currentLocationName ?? "Unknown")")
            }
        }
    }
}