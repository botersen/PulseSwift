import Foundation

// MARK: - Domain Entity (Pure Business Logic)
struct UserEntity {
    let id: UUID
    let username: String
    let email: String?
    let subscriptionTier: SubscriptionTier
    let profileImageURL: String?
    let isAuthenticated: Bool
    
    init(
        id: UUID = UUID(),
        username: String,
        email: String? = nil,
        subscriptionTier: SubscriptionTier = .free,
        profileImageURL: String? = nil,
        isAuthenticated: Bool = false
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.subscriptionTier = subscriptionTier
        self.profileImageURL = profileImageURL
        self.isAuthenticated = isAuthenticated
    }
}

// MARK: - Subscription Tier
enum SubscriptionTier: String, CaseIterable, Codable {
    case free = "free"
    case premium = "premium"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }
}

