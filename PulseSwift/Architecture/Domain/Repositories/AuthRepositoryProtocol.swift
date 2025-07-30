import Foundation
import Combine
import AuthenticationServices

// MARK: - Authentication Repository Protocol (Domain Interface)
protocol AuthRepositoryProtocol {
    // State Publishers
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }
    var currentUserPublisher: AnyPublisher<UserEntity?, Never> { get }
    
    // Authentication Methods
    func signInWithApple() async throws -> UserEntity
    func processAppleSignInResult(_ authorization: ASAuthorization) async throws -> UserEntity
    func signInWithGoogle() async throws -> UserEntity
    func signInWithCredentials(username: String, password: String) async throws -> UserEntity
    func signUp(username: String, email: String, password: String) async throws -> UserEntity
    func signOut() async throws
    
    // Session Management
    func checkAuthStatus() async -> Bool
    func refreshSession() async throws
    
    // User Management
    func updateProfile(username: String?, profileImageURL: String?) async throws -> UserEntity
}

// MARK: - Auth State
enum AuthState {
    case unauthenticated
    case authenticating
    case authenticated(UserEntity)
    case error(AuthError)
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError
    case userCancelled
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .networkError:
            return "Network connection error"
        case .userCancelled:
            return "Authentication cancelled"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
} 