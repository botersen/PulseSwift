//
//  SupabaseService.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        let url = URL(string: "https://nlkmhztubzbnkjjgkpop.supabase.co")!
        let key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5sa21oenR1YnpibmtqamdrcG9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMzNzIzMDAsImV4cCI6MjA2ODk0ODMwMH0.W2tAupHuyUIrpWNHMC3-XY2m15pCoz2QRoTbRITuqg0"
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String, username: String, preferredLanguage: String = "English") async throws -> User {
        // Basic auth signup
        _ = try await client.auth.signUp(email: email, password: password)
        
        // Convert language name to code for storage
        let languageCode = getLanguageCode(for: preferredLanguage)
        let preferences = UserPreferences(language: languageCode)
        
        // Return a simple user object based on input
        return User(
            id: UUID(),
            username: username,
            email: email,
            subscriptionTier: .free,
            preferences: preferences
        )
    }
    
    func signIn(email: String, password: String) async throws -> User {
        _ = try await client.auth.signIn(email: email, password: password)
        
        // Return a simple user object based on input
        return User(
            id: UUID(),
            username: email.components(separatedBy: "@").first ?? "user",
            email: email,
            subscriptionTier: .free
        )
    }
    
    func signInWithApple(identityToken: String, email: String, username: String, firstName: String, lastName: String) async throws -> User {
        _ = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: identityToken
            )
        )
        
        return User(
            id: UUID(),
            username: username,
            email: email,
            subscriptionTier: .free
        )
    }
    
    func signInWithGoogle(idToken: String, email: String, username: String, firstName: String, lastName: String) async throws -> User {
        _ = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken
            )
        )
        
        return User(
            id: UUID(),
            username: username,
            email: email,
            subscriptionTier: .free
        )
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    // MARK: - Username Management
    
    func getEmailByUsername(_ username: String) async throws -> String {
        // For now, return a placeholder - this would query your users table
        // In the future, implement actual database lookup
        return "\(username)@pulse.temp"
    }
    
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Reserved usernames that are always taken
        let reservedUsernames = [
            "admin", "administrator", "mod", "moderator", "pulse", "pulseapp",
            "system", "support", "help", "api", "www", "mail", "email", "info",
            "contact", "team", "staff", "root", "user", "guest", "test", "demo",
            "official", "verified", "public", "private", "null", "undefined"
        ]
        
        // Simulate some taken usernames for testing
        let takenUsernames = [
            "john", "jane", "mike", "sarah", "alex", "chris", "jessica", "david",
            "user123", "testuser", "cool_user", "awesome", "amazing", "fantastic"
        ]
        
        let lowercaseUsername = username.lowercased()
        
        // Check reserved usernames
        if reservedUsernames.contains(lowercaseUsername) {
            return false
        }
        
        // Check simulated taken usernames
        if takenUsernames.contains(lowercaseUsername) {
            return false
        }
        
        // In the future, this will query the actual database:
        // let result = try await client
        //     .from("users")
        //     .select("id")
        //     .eq("username", username)
        //     .single()
        // return result == nil
        
        return true
    }
    
    func updateUserProfile(userId: UUID, username: String, preferredLanguage: String, profileImageURL: String?) async throws -> User {
        // For now, return updated user object
        // In the future, implement actual database update
        let languageCode = getLanguageCode(for: preferredLanguage)
        let preferences = UserPreferences(language: languageCode)
        
        return User(
            id: userId,
            username: username,
            email: nil, // Will be filled from actual user data
            subscriptionTier: .free,
            preferences: preferences,
            profileImageURL: profileImageURL
        )
    }
    
    func getCurrentSessionToken() async throws -> String? {
        do {
            let session = try await client.auth.session
            return session.accessToken
        } catch {
            return nil
        }
    }
    
    // MARK: - User Management
    
    func getCurrentUser() async throws -> User? {
        do {
            _ = try await client.auth.session
            
            // Return a basic user - in a real app you'd fetch from your users table
            return User(
                id: UUID(),
                username: "current_user",
                email: "user@example.com",
                subscriptionTier: .free
            )
        } catch {
            return nil
        }
    }
    
    func updateUserLocation(latitude: Double, longitude: Double, city: String?, country: String?) async throws {
        print("📍 Location updated: \(latitude), \(longitude)")
        // For now, we'll just log this - can implement actual database update later
    }
    
    func updateUserOneSignalPlayerId(userId: UUID, playerId: String) async throws {
        print("🔔 OneSignal player ID updated: \(playerId)")
        // For now, we'll just log this - can implement actual database update later
    }
    
    // MARK: - Pulse Operations
    
    func sendPulse(mediaURL: String, mediaType: PulseMediaType, caption: String?, targetRadius: Double, senderLocation: UserLocation) async throws -> Pulse {
        print("📨 Pulse sent")
        print("📱 Media URL: \(mediaURL)")
        print("📍 Location: \(senderLocation.latitude), \(senderLocation.longitude)")
        print("📏 Radius: \(targetRadius) meters")
        
        // Return a mock pulse for now
        return Pulse(
            senderId: UUID(),
            mediaURL: mediaURL,
            mediaType: mediaType,
            caption: caption,
            senderLocation: senderLocation,
            targetRadius: targetRadius
        )
    }
    
    func findNearbyUsers(latitude: Double, longitude: Double, radiusMeters: Double, excludeUserId: UUID) async throws -> [UserProfile] {
        print("🔍 Finding nearby users within \(radiusMeters) meters")
        // Return empty array for now - can implement geospatial queries later
        return []
    }
    
    func uploadMedia(data: Data, fileName: String, mimeType: String) async throws -> String {
        do {
            // Simple upload using basic data
            _ = try await client.storage
                .from("pulse-media")
                .upload(path: fileName, file: data)
            
            let publicURL = try client.storage
                .from("pulse-media")
                .getPublicURL(path: fileName)
            
            return publicURL.absoluteString
        } catch {
            print("❌ Upload failed: \(error)")
            throw SupabaseError.uploadFailed
        }
    }
    
    // MARK: - Real-time Subscriptions (simplified)
    
    func subscribeToPulses(userId: UUID, onReceive: @escaping (Pulse) -> Void) {
        print("🔔 Subscribed to pulses for user: \(userId)")
        // For now, we'll just log this - can implement realtime subscriptions later
    }
}

// MARK: - Simplified Database Models

struct UserProfile: Codable {
    let id: UUID
    let username: String
    let email: String?
    let subscriptionTier: SubscriptionTier
    let latitude: Double?
    let longitude: Double?
    let city: String?
    let country: String?
    let createdAt: Date
    let lastActiveAt: Date
    let deviceToken: String?
}

struct UserLocationUpdate: Codable {
    let latitude: Double
    let longitude: Double
    let city: String?
    let country: String?
    let updatedAt: Date
}

// MARK: - Errors

enum SupabaseError: LocalizedError {
    case authenticationFailed
    case notAuthenticated
    case networkError
    case invalidResponse
    case notImplemented
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Authentication failed"
        case .notAuthenticated:
            return "User not authenticated"
        case .networkError:
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        case .notImplemented:
            return "Feature not implemented"
        case .uploadFailed:
            return "Media upload failed"
        }
    }
}

// MARK: - Language Helpers

extension SupabaseService {
    private func getLanguageCode(for languageName: String) -> String {
        let languageMap: [String: String] = [
            // Major World Languages
            "English": "en",
            "Spanish": "es",
            "French": "fr",
            "German": "de",
            "Italian": "it",
            "Portuguese": "pt",
            "Russian": "ru",
            "Chinese (Simplified)": "zh-cn",
            "Chinese (Traditional)": "zh-tw",
            "Japanese": "ja",
            "Korean": "ko",
            "Arabic": "ar",
            "Hindi": "hi",
            
            // European Languages
            "Dutch": "nl",
            "Swedish": "sv",
            "Norwegian": "no",
            "Danish": "da",
            "Finnish": "fi",
            "Polish": "pl",
            "Czech": "cs",
            "Hungarian": "hu",
            "Romanian": "ro",
            "Bulgarian": "bg",
            "Croatian": "hr",
            "Serbian": "sr",
            "Slovak": "sk",
            "Slovenian": "sl",
            "Estonian": "et",
            "Latvian": "lv",
            "Lithuanian": "lt",
            "Greek": "el",
            "Turkish": "tr",
            "Ukrainian": "uk",
            "Belarusian": "be",
            
            // Asian Languages
            "Thai": "th",
            "Vietnamese": "vi",
            "Indonesian": "id",
            "Malay": "ms",
            "Tagalog": "tl",
            "Bengali": "bn",
            "Urdu": "ur",
            "Tamil": "ta",
            "Telugu": "te",
            "Marathi": "mr",
            "Gujarati": "gu",
            "Kannada": "kn",
            "Malayalam": "ml",
            "Punjabi": "pa",
            "Nepali": "ne",
            "Burmese": "my",
            "Khmer": "km",
            "Lao": "lo",
            "Mongolian": "mn",
            "Tibetan": "bo",
            
            // Middle Eastern & African Languages
            "Hebrew": "he",
            "Persian": "fa",
            "Kurdish": "ku",
            "Pashto": "ps",
            "Dari": "prs",
            "Amharic": "am",
            "Swahili": "sw",
            "Yoruba": "yo",
            "Igbo": "ig",
            "Hausa": "ha",
            "Somali": "so",
            "Afrikaans": "af",
            "Zulu": "zu",
            "Xhosa": "xh",
            
            // South American Languages
            "Catalan": "ca",
            "Galician": "gl",
            "Basque": "eu",
            "Quechua": "qu",
            "Guarani": "gn",
            
            // Other Languages
            "Welsh": "cy",
            "Irish": "ga",
            "Scottish Gaelic": "gd",
            "Icelandic": "is",
            "Maltese": "mt",
            "Luxembourg": "lb",
            "Albanian": "sq",
            "Macedonian": "mk",
            "Bosnian": "bs",
            "Montenegrin": "cnr",
            "Armenian": "hy",
            "Georgian": "ka",
            "Azerbaijani": "az",
            "Kazakh": "kk",
            "Kyrgyz": "ky",
            "Tajik": "tg",
            "Turkmen": "tk",
            "Uzbek": "uz"
        ]
        
        return languageMap[languageName] ?? "en"
    }
} 