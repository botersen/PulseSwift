//
//  Subscription.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation

enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }
    
    var price: String {
        switch self {
        case .free: return "Free"
        case .premium: return "$3.99/month"
        }
    }
    
    // Feature limits
    var maxPulsesPerDay: Int {
        switch self {
        case .free: return 10
        case .premium: return Int.max
        }
    }
    
    var maxTranslationsPerDay: Int {
        switch self {
        case .free: return 5
        case .premium: return 200
        }
    }
    
    var maxRadiusMeters: Double {
        switch self {
        case .free: return 160934 // 100 miles
        case .premium: return Double.greatestFiniteMagnitude // Global
        }
    }
    
    var allowsGlobalMatching: Bool {
        switch self {
        case .free: return false
        case .premium: return true
        }
    }
    
    var hasPriorityMatching: Bool {
        switch self {
        case .free: return false
        case .premium: return true
        }
    }
    
    var pulseHistoryDays: Int {
        switch self {
        case .free: return 30
        case .premium: return Int.max
        }
    }
}

struct SubscriptionFeature {
    let title: String
    let description: String
    let icon: String
    let isPremiumOnly: Bool
    
    static let allFeatures: [SubscriptionFeature] = [
        SubscriptionFeature(
            title: "Global Connections",
            description: "Connect with people anywhere in the world",
            icon: "globe",
            isPremiumOnly: true
        ),
        SubscriptionFeature(
            title: "Unlimited Pulses",
            description: "Send as many pulses as you want",
            icon: "infinity",
            isPremiumOnly: true
        ),
        SubscriptionFeature(
            title: "Enhanced Translations",
            description: "200 AI translations per month",
            icon: "translate",
            isPremiumOnly: true
        ),
        SubscriptionFeature(
            title: "Priority Matching",
            description: "Get shown first in pulse queues",
            icon: "star.fill",
            isPremiumOnly: true
        ),
        SubscriptionFeature(
            title: "Unlimited History",
            description: "Keep all your pulse memories forever",
            icon: "clock.fill",
            isPremiumOnly: true
        )
    ]
} 