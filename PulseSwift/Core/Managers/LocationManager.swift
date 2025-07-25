//
//  LocationManager.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var currentCity: String?
    @Published var currentCountry: String?
    @Published var isLocationEnabled = false
    @Published var errorMessage: String?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var oneSignalManager: OneSignalManager?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - OneSignal Integration
    
    @MainActor
    func setOneSignalManager(_ manager: OneSignalManager) {
        self.oneSignalManager = manager
    }
    
    // MARK: - Location Permissions
    
    func requestLocationPermission() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "Location access is required for pulse matching. Please enable in Settings."
            }
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationServices()
        @unknown default:
            break
        }
    }
    
    func openLocationSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    // MARK: - Location Services
    
    private func startLocationServices() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            DispatchQueue.main.async {
                self.errorMessage = "Location services are disabled. Please enable in Settings."
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isLocationEnabled = true
        }
        locationManager.startUpdatingLocation()
        
        // Get initial location
        if let location = locationManager.location {
            updateLocation(location)
        }
    }
    
    func stopLocationServices() {
        locationManager.stopUpdatingLocation()
        DispatchQueue.main.async {
            self.isLocationEnabled = false
        }
    }
    
    // MARK: - Location Updates
    
    private func updateLocation(_ location: CLLocation) {
        DispatchQueue.main.async {
            self.currentLocation = location
        }
        
        // Update location in Supabase
        Task {
            do {
                try await SupabaseService.shared.updateUserLocation(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    city: currentCity,
                    country: currentCountry
                )
            } catch {
                print("❌ Failed to update location in Supabase: \(error)")
            }
        }
        
        // Reverse geocode to get city/country
        reverseGeocodeLocation(location)
        
        // Update OneSignal with location
        updateOneSignalLocation()
    }
    
    private func reverseGeocodeLocation(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self, let placemark = placemarks?.first else {
                return
            }
            
            DispatchQueue.main.async {
                self.currentCity = placemark.locality
                self.currentCountry = placemark.country
            }
            
            // Update Supabase with complete location info
            Task {
                do {
                    try await SupabaseService.shared.updateUserLocation(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        city: self.currentCity,
                        country: self.currentCountry
                    )
                } catch {
                    print("❌ Failed to update geocoded location: \(error)")
                }
            }
            
            // Update OneSignal
            self.updateOneSignalLocation()
        }
    }
    
    private func updateOneSignalLocation() {
        guard let location = currentLocation else { return }
        
        Task { @MainActor in
            oneSignalManager?.updateLocation(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                city: currentCity,
                country: currentCountry
            )
        }
    }
    
    // MARK: - Distance Calculations
    
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        
        let targetLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        return currentLocation.distance(from: targetLocation)
    }
    
    func isWithinRadius(_ radiusMeters: Double, of coordinate: CLLocationCoordinate2D) -> Bool {
        guard let distance = distance(to: coordinate) else { return false }
        return distance <= radiusMeters
    }
    
    // MARK: - User Discovery
    
    func findNearbyUsers(radiusMeters: Double) async throws -> [UserProfile] {
        guard let location = currentLocation else {
            throw LocationError.locationNotAvailable
        }
        
        guard let currentUser = try await SupabaseService.shared.getCurrentUser() else {
            throw LocationError.userNotAuthenticated
        }
        
        return try await SupabaseService.shared.findNearbyUsers(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            radiusMeters: radiusMeters,
            excludeUserId: currentUser.id
        )
    }
    
    // MARK: - Location for Pulse Sending
    
    func getCurrentUserLocation() -> UserLocation? {
        guard let location = currentLocation else { return nil }
        
        return UserLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            city: currentCity,
            country: currentCountry,
            updatedAt: Date()
        )
    }
    
    // MARK: - Background Location (for future)
    
    func enableBackgroundLocation() {
        // For premium users who want background pulse matching
        locationManager.requestAlwaysAuthorization()
    }
    
    func setupGeofencing(center: CLLocationCoordinate2D, radius: Double, identifier: String) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            print("❌ Geofencing not available on this device")
            return
        }
        
        let region = CLCircularRegion(
            center: center,
            radius: radius,
            identifier: identifier
        )
        
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        locationManager.startMonitoring(for: region)
    }
    
    func removeGeofencing(identifier: String) {
        let regionsToRemove = locationManager.monitoredRegions.filter { $0.identifier == identifier }
        for region in regionsToRemove {
            locationManager.stopMonitoring(for: region)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        updateLocation(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            DispatchQueue.main.async {
                self.errorMessage = nil
            }
            startLocationServices()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "Location access denied. Enable in Settings to use pulse matching."
            }
            stopLocationServices()
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager failed with error: \(error)")
        
        let errorMsg: String
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                errorMsg = "Location access denied"
            case .network:
                errorMsg = "Network error while getting location"
            case .locationUnknown:
                errorMsg = "Unable to determine location"
            default:
                errorMsg = "Location error: \(clError.localizedDescription)"
            }
        } else {
            errorMsg = "Location error: \(error.localizedDescription)"
        }
        
        DispatchQueue.main.async {
            self.errorMessage = errorMsg
        }
    }
    
    // MARK: - Geofencing Delegate Methods
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("📍 Entered region: \(region.identifier)")
        
        // Handle entering a pulse radius - could trigger notifications
        NotificationCenter.default.post(
            name: .didEnterPulseRegion,
            object: region.identifier
        )
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("📍 Exited region: \(region.identifier)")
        
        // Handle exiting a pulse radius
        NotificationCenter.default.post(
            name: .didExitPulseRegion,
            object: region.identifier
        )
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("❌ Geofencing failed for region \(region?.identifier ?? "unknown"): \(error)")
    }
}

// MARK: - Location Errors

enum LocationError: LocalizedError {
    case locationNotAvailable
    case permissionDenied
    case userNotAuthenticated
    case geocodingFailed
    
    var errorDescription: String? {
        switch self {
        case .locationNotAvailable:
            return "Location not available"
        case .permissionDenied:
            return "Location permission denied"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .geocodingFailed:
            return "Failed to get location details"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let didEnterPulseRegion = Notification.Name("didEnterPulseRegion")
    static let didExitPulseRegion = Notification.Name("didExitPulseRegion")
}

// MARK: - Location Permissions Helper

extension CLAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorizedAlways:
            return "Always Authorized"
        case .authorizedWhenInUse:
            return "When In Use"
        @unknown default:
            return "Unknown"
        }
    }
    
    var isAuthorized: Bool {
        return self == .authorizedWhenInUse || self == .authorizedAlways
    }
} 