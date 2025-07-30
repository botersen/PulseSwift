import Foundation
import Combine
import AuthenticationServices
import SwiftUI

// MARK: - Authentication ViewModel (Reactive State Management)
@MainActor
final class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI State)
    @Published var authState: AuthState = .unauthenticated
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showUsernameCustomization: Bool = false
    
    // MARK: - Input Properties
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    
    // MARK: - Validation State
    @Published var isUsernameValid: Bool = false
    @Published var isEmailValid: Bool = false
    @Published var isPasswordValid: Bool = false
    @Published var passwordsMatch: Bool = false
    
    // MARK: - Dependencies
    @Injected private var authUseCases: AuthUseCasesProtocol
    private var cancellables = Set<AnyCancellable>()
    weak var appFlowViewModel: AppFlowViewModel?
    
    // MARK: - Computed Properties
    var isSignInEnabled: Bool {
        !username.isEmpty && !password.isEmpty && !isLoading
    }
    
    var isSignUpEnabled: Bool {
        isUsernameValid && isEmailValid && isPasswordValid && passwordsMatch && !isLoading
    }
    
    var currentUser: UserEntity? {
        if case .authenticated(let user) = authState {
            return user
        }
        return nil
    }
    
    init() {
        setupValidation()
        setupAuthStateBinding()
        checkInitialAuthState()
    }
    
    // MARK: - Public Methods
    func signInWithApple() {
        performAuthAction {
            try await self.authUseCases.signInWithApple()
        }
    }
    
    func handleAppleSignInResult(_ authorization: ASAuthorization) {
        performAuthAction {
            return try await self.authUseCases.processAppleSignInResult(authorization)
        }
    }
    
    func handleAppleSignInError(_ error: Error) {
        handleAuthError(error)
    }
    
    func signInWithGoogle() {
        performAuthAction {
            try await self.authUseCases.signInWithGoogle()
        }
    }
    
    func signInWithCredentials() {
        guard isSignInEnabled else { return }
        
        performAuthAction {
            try await self.authUseCases.signInWithCredentials(
                username: self.username,
                password: self.password
            )
        }
    }
    
    func signUp() {
        guard isSignUpEnabled else { return }
        
        performAuthAction {
            try await self.authUseCases.signUp(
                username: self.username,
                email: self.email,
                password: self.password
            )
        }
    }
    
    func signOut() {
        performAuthAction {
            try await self.authUseCases.signOut()
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func resetForm() {
        username = ""
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    private func performAuthAction(_ action: @escaping () async throws -> UserEntity) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let user = try await action()
                await MainActor.run {
                    self.authState = .authenticated(user)
                    self.isLoading = false
                    self.handleSuccessfulAuth(user: user)
                }
            } catch {
                await MainActor.run {
                    self.handleAuthError(error)
                }
            }
        }
    }
    
    private func performAuthAction(_ action: @escaping () async throws -> Void) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await action()
                await MainActor.run {
                    self.authState = .unauthenticated
                    self.isLoading = false
                    self.resetForm()
                }
            } catch {
                await MainActor.run {
                    self.handleAuthError(error)
                }
            }
        }
    }
    
    private func handleSuccessfulAuth(user: UserEntity) {
        // Handle post-authentication logic
        if shouldShowUsernameCustomization(for: user) {
            showUsernameCustomization = true
        }
        
        // Analytics/logging
        print("✅ Auth successful for user: \(user.username)")
        // Advance navigation after successful sign-in
        DispatchQueue.main.async {
            self.appFlowViewModel?.handleAuthSuccess(isFirstTime: false)
        }
    }
    
    private func handleAuthError(_ error: Error) {
        isLoading = false
        
        if let authError = error as? AuthError {
            errorMessage = authError.errorDescription
        } else {
            errorMessage = "An unexpected error occurred. Please try again."
        }
        
        authState = .error(error as? AuthError ?? .unknown(error))
        
        // Analytics/logging
        print("❌ Auth error: \(error)")
    }
    
    private func shouldShowUsernameCustomization(for user: UserEntity) -> Bool {
        // Business logic: Show customization for social logins
        return user.email?.isEmpty == false && user.username.contains("google") || user.username.contains("apple")
    }
    
    private func checkInitialAuthState() {
        Task {
            let authState = await authUseCases.checkAuthenticationStatus()
            await MainActor.run {
                self.authState = authState
            }
        }
    }
    
    private func setupValidation() {
        // Username validation
        $username
            .map { username in
                username.count >= 3 && username.count <= 20 && 
                username.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
            }
            .assign(to: &$isUsernameValid)
        
        // Email validation
        $email
            .map { email in
                email.contains("@") && email.contains(".") && email.count >= 5
            }
            .assign(to: &$isEmailValid)
        
        // Password validation
        $password
            .map { password in
                password.count >= 8 &&
                password.contains { $0.isUppercase } &&
                password.contains { $0.isNumber } &&
                password.contains { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }
            }
            .assign(to: &$isPasswordValid)
        
        // Password match validation
        Publishers.CombineLatest($password, $confirmPassword)
            .map { password, confirmPassword in
                !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword
            }
            .assign(to: &$passwordsMatch)
    }
    
    private func setupAuthStateBinding() {
        // Bind to auth repository state if needed
        // This creates a reactive connection between repository and ViewModel
    }
}

// MARK: - Auth State Helpers
extension AuthViewModel {
    var isAuthenticated: Bool {
        if case .authenticated = authState {
            return true
        }
        return false
    }
    
    var isAuthenticating: Bool {
        if case .authenticating = authState {
            return true
        }
        return isLoading
    }
    
    var hasError: Bool {
        if case .error = authState {
            return true
        }
        return errorMessage != nil
    }
} 