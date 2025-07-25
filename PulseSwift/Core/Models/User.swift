//
//  User.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import CoreLocation

struct User: Codable, Identifiable {
    let id: UUID
    let username: String
    let email: String?
    let createdAt: Date
    let lastActiveAt: Date
    let subscriptionTier: SubscriptionTier
    let location: UserLocation?
    let preferences: UserPreferences
    let stats: UserStats
    
    // Profile data
    let profileImageURL: String?
    let deviceToken: String? // For push notifications
    
    init(
        id: UUID,
        username: String,
        email: String? = nil,
        subscriptionTier: SubscriptionTier = .free,
        location: UserLocation? = nil,
        createdAt: Date = Date(),
        lastActiveAt: Date = Date(),
        preferences: UserPreferences? = nil,
        stats: UserStats? = nil,
        profileImageURL: String? = nil,
        deviceToken: String? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.subscriptionTier = subscriptionTier
        self.location = location
        self.preferences = preferences ?? UserPreferences()
        self.stats = stats ?? UserStats()
        self.profileImageURL = profileImageURL
        self.deviceToken = deviceToken
    }
}

struct UserLocation: Codable {
    let latitude: Double
    let longitude: Double
    let city: String?
    let country: String?
    let updatedAt: Date
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct UserPreferences: Codable {
    let language: String
    let allowsGlobalMatching: Bool
    let maxRadius: Double // in meters
    let enabledNotifications: Bool
    
    init(
        language: String = "en",
        allowsGlobalMatching: Bool = false,
        maxRadius: Double = 160934, // 100 miles in meters
        enabledNotifications: Bool = true
    ) {
        self.language = language
        self.allowsGlobalMatching = allowsGlobalMatching
        self.maxRadius = maxRadius
        self.enabledNotifications = enabledNotifications
    }
}

struct UserStats: Codable {
    let totalPulsesSent: Int
    let totalPulsesReceived: Int
    let totalMatches: Int
    let translationsUsedToday: Int
    let lastTranslationReset: Date
    
    init() {
        self.totalPulsesSent = 0
        self.totalPulsesReceived = 0
        self.totalMatches = 0
        self.translationsUsedToday = 0
        self.lastTranslationReset = Date()
    }
} 