import Foundation
import AuthenticationServices
import Combine

// MARK: - Authentication Use Cases (Business Logic)
protocol AuthUseCasesProtocol {
    func signInWithApple() async throws -> UserEntity
    func processAppleSignInResult(_ authorization: ASAuthorization) async throws -> UserEntity
    func signInWithGoogle() async throws -> UserEntity
    func signInWithCredentials(username: String, password: String) async throws -> UserEntity
    func signUp(username: String, email: String, password: String) async throws -> UserEntity
    func signOut() async throws
    func checkAuthenticationStatus() async -> AuthState
}

final class AuthUseCases: AuthUseCasesProtocol {
    private let authRepository: AuthRepositoryProtocol
    
    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }
    
    func signInWithApple() async throws -> UserEntity {
        // Business rule: Validate Apple Sign In flow
        do {
            let user = try await authRepository.signInWithApple()
            // Additional business logic (analytics, validation, etc.)
            logAuthenticationEvent(provider: "apple", success: true)
            return user
        } catch {
            logAuthenticationEvent(provider: "apple", success: false)
            throw error
        }
    }
    
    func processAppleSignInResult(_ authorization: ASAuthorization) async throws -> UserEntity {
        // Process the Apple Sign In result directly
        do {
            let user = try await authRepository.processAppleSignInResult(authorization)
            logAuthenticationEvent(provider: "apple", success: true)
            return user
        } catch {
            logAuthenticationEvent(provider: "apple", success: false)
            throw error
        }
    }
    
    func signInWithGoogle() async throws -> UserEntity {
        // Business rule: Validate Google Sign In flow
        do {
            let user = try await authRepository.signInWithGoogle()
            logAuthenticationEvent(provider: "google", success: true)
            return user
        } catch {
            logAuthenticationEvent(provider: "google", success: false)
            throw error
        }
    }
    
    func signInWithCredentials(username: String, password: String) async throws -> UserEntity {
        // Business rules: Validate input
        guard !username.isEmpty else {
            throw AuthError.invalidCredentials
        }
        guard password.count >= 8 else {
            throw AuthError.invalidCredentials
        }
        
        do {
            let user = try await authRepository.signInWithCredentials(username: username, password: password)
            logAuthenticationEvent(provider: "credentials", success: true)
            return user
        } catch {
            logAuthenticationEvent(provider: "credentials", success: false)
            throw error
        }
    }
    
    func signUp(username: String, email: String, password: String) async throws -> UserEntity {
        // Business rules: Validate signup data
        guard isValidUsername(username) else {
            throw AuthError.invalidCredentials
        }
        guard isValidEmail(email) else {
            throw AuthError.invalidCredentials
        }
        guard isValidPassword(password) else {
            throw AuthError.invalidCredentials
        }
        
        return try await authRepository.signUp(username: username, email: email, password: password)
    }
    
    func signOut() async throws {
        try await authRepository.signOut()
        logAuthenticationEvent(provider: "signout", success: true)
    }
    
    func checkAuthenticationStatus() async -> AuthState {
        let isAuthenticated = await authRepository.checkAuthStatus()
        return isAuthenticated ? .authenticated(UserEntity(username: "cached_user")) : .unauthenticated
    }
    
    // MARK: - Private Helpers
    private func isValidUsername(_ username: String) -> Bool {
        username.count >= 3 && username.count <= 20 && username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".")
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        password.count >= 8 && 
        password.contains { $0.isUppercase } &&
        password.contains { $0.isNumber } &&
        password.contains { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }
    }
    
    private func logAuthenticationEvent(provider: String, success: Bool) {
        // Analytics/logging logic
        print("🔐 Auth event: \(provider) - success: \(success)")
    }
} 