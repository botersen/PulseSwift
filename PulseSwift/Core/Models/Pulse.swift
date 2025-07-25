//
//  Pulse.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import CoreLocation

struct Pulse: Codable, Identifiable {
    let id: UUID
    let senderId: UUID
    let recipientId: UUID?
    let mediaURL: String
    let mediaType: PulseMediaType
    let caption: String?
    let originalLanguage: String
    let translatedCaption: String?
    let targetLanguage: String?
    
    // Location data
    let senderLocation: UserLocation
    let targetRadius: Double // in meters
    
    // Timing
    let createdAt: Date
    let expiresAt: Date
    let openedAt: Date?
    let respondedAt: Date?
    
    // Status
    let status: PulseStatus
    let attemptNumber: Int // 1-5 for the matching attempts
    
    init(
        senderId: UUID,
        mediaURL: String,
        mediaType: PulseMediaType,
        caption: String? = nil,
        senderLocation: UserLocation,
        targetRadius: Double
    ) {
        self.id = UUID()
        self.senderId = senderId
        self.recipientId = nil
        self.mediaURL = mediaURL
        self.mediaType = mediaType
        self.caption = caption
        self.originalLanguage = "en" // Default, should be detected
        self.translatedCaption = nil
        self.targetLanguage = nil
        self.senderLocation = senderLocation
        self.targetRadius = targetRadius
        self.createdAt = Date()
        self.expiresAt = Date().addingTimeInterval(180) // 3 minutes
        self.openedAt = nil
        self.respondedAt = nil
        self.status = .searching
        self.attemptNumber = 1
    }
}

enum PulseMediaType: String, Codable {
    case photo = "photo"
    case video = "video"
}

enum PulseStatus: String, Codable {
    case searching = "searching"      // Looking for recipient
    case delivered = "delivered"      // Sent to recipient
    case opened = "opened"           // Recipient opened it
    case responded = "responded"     // Recipient responded
    case expired = "expired"         // Timed out
    case rejected = "rejected"       // Recipient declined
    case failed = "failed"          // All 5 attempts failed ("ether")
}

struct PulseMatch: Codable, Identifiable {
    let id: UUID
    let pulseId: UUID
    let senderId: UUID
    let recipientId: UUID
    let matchedAt: Date
    let lastActivityAt: Date
    let status: MatchStatus
    let location: UserLocation
    
    // Conversation thread
    let messages: [PulseMessage]
}

enum MatchStatus: String, Codable {
    case active = "active"
    case expired = "expired"
    case completed = "completed"
}

struct PulseMessage: Codable, Identifiable {
    let id: UUID
    let pulseMatchId: UUID
    let senderId: UUID
    let mediaURL: String
    let mediaType: PulseMediaType
    let caption: String?
    let translatedCaption: String?
    let sentAt: Date
    let expiresAt: Date
    let openedAt: Date?
    let status: MessageStatus
}

enum MessageStatus: String, Codable {
    case sent = "sent"
    case delivered = "delivered"
    case opened = "opened"
    case expired = "expired"
} 