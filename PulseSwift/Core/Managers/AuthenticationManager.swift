//
//  AuthenticationManager.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import AuthenticationServices
import SwiftUI
import GoogleSignIn

// MARK: - Password Validation Structure
struct PasswordValidation {
    var hasMinLength: Bool = false
    var hasUppercase: Bool = false
    var hasNumber: Bool = false
    var hasSpecialChar: Bool = false
    
    var isValid: Bool {
        hasMinLength && hasUppercase && hasNumber && hasSpecialChar
    }
}

// MARK: - Temporary Credentials Storage
struct TempCredentials {
    let username: String
    let password: String
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Real-time password validation
    @Published var passwordValidation = PasswordValidation()
    
    // Profile customization state
    @Published var showUsernameCustomization = false
    @Published var suggestedUsername = ""
    @Published var userEmail = ""
    
    // Temporary storage for username/password sign-up
    private var tempCredentials: TempCredentials?
    
    private let keychainService = KeychainService()
    private var oneSignalManager: OneSignalManager?
    private var appleSignInDelegate: AppleSignInDelegate?
    
    init() {
        configureGoogleSignIn()
        checkExistingAuthentication()
    }
    
    // MARK: - OneSignal Integration
    
    func setOneSignalManager(_ manager: OneSignalManager) {
        self.oneSignalManager = manager
    }
    
    private func syncUserWithOneSignal(_ user: User) {
        guard let oneSignalManager = oneSignalManager else { return }
        
        // Identify user with OneSignal
        oneSignalManager.identifyUser(userId: user.id.uuidString)
        
        // Update user properties
        oneSignalManager.updateUserProperties(
            username: user.username,
            subscriptionTier: user.subscriptionTier.rawValue
        )
        
        // Store OneSignal player ID in Supabase if available
        if let playerId = oneSignalManager.playerId {
            Task {
                do {
                    try await SupabaseService.shared.updateUserOneSignalPlayerId(
                        userId: user.id,
                        playerId: playerId
                    )
                } catch {
                    print("❌ Failed to update OneSignal player ID: \(error)")
                }
            }
        }
    }
    
    private func logoutFromOneSignal() {
        oneSignalManager?.logoutUser()
    }
    
    // MARK: - Google Sign In Configuration
    
    private func configureGoogleSignIn() {
        // Configure Google Sign In with client ID from Google.plist
        if let path = Bundle.main.path(forResource: "Google", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientId = plist["CLIENT_ID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
            print("✅ Google Sign In configured with client ID: \(clientId)")
        } else {
            print("❌ Failed to configure Google Sign In - Google.plist not found or invalid")
        }
    }
    
    // MARK: - Apple Sign In
    
    func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                handleAppleSignInSuccess(credential: appleIDCredential)
            }
        case .failure(let error):
            handleAppleSignInError(error)
        }
    }
    
    func signInWithApple() {
        print("🍎 Starting Apple Sign-In...")
        isLoading = true
        errorMessage = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        
        // Create delegate and keep it alive
        let delegate = AppleSignInDelegate(authManager: self)
        authorizationController.delegate = delegate
        authorizationController.presentationContextProvider = delegate
        
        // Store delegate to prevent deallocation
        self.appleSignInDelegate = delegate
        
        authorizationController.performRequests()
        
        // Add timeout to prevent hanging
        Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            if isLoading {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Apple Sign-In timed out. Please try again."
                    self.appleSignInDelegate = nil
                }
            }
        }
    }
    
    func handleAppleSignInSuccess(credential: ASAuthorizationAppleIDCredential) {
        Task {
            do {
                // Extract identity token
                guard let identityToken = credential.identityToken,
                      let tokenString = String(data: identityToken, encoding: .utf8) else {
                    throw AuthenticationError.invalidCredential
                }
                
                // Create user data
                let email = credential.email ?? ""
                let fullName = credential.fullName
                let firstName = fullName?.givenName ?? ""
                let lastName = fullName?.familyName ?? ""
                let username = self.generateUsername(
                    from: firstName, 
                    lastName: lastName, 
                    email: email, 
                    provider: "apple"
                )
                
                // Send to Supabase for authentication
                let user = try await SupabaseService.shared.signInWithApple(
                    identityToken: tokenString,
                    email: email,
                    username: username,
                    firstName: firstName,
                    lastName: lastName
                )
                
                // Store token in keychain
                keychainService.saveToken(tokenString)
                
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = nil
                    self.appleSignInDelegate = nil // Clear delegate
                    
                    // Store user data but don't mark as authenticated yet
                    self.currentUser = user
                    
                    // Show username customization
                    self.suggestedUsername = username
                    self.userEmail = email
                    self.showUsernameCustomization = true
                    
                    // Don't set authenticated yet - wait for profile completion
                    // self.isAuthenticated = true will be set in completeProfileSetup()
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func handleAppleSignInError(_ error: Error) {
        print("❌ Apple Sign-In Error: \(error)")
        isLoading = false
        appleSignInDelegate = nil // Clear delegate
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                errorMessage = nil // User canceled, don't show error
            case .failed:
                errorMessage = "Apple Sign In failed"
            case .invalidResponse:
                errorMessage = "Invalid response from Apple"
            case .notHandled:
                errorMessage = "Apple Sign In not handled"
            case .unknown:
                errorMessage = "Unknown Apple Sign In error"
            case .notInteractive:
                errorMessage = "Apple Sign In not available"
            case .matchedExcludedCredential:
                errorMessage = "Apple Sign In credential excluded"
            case .credentialImport:
                errorMessage = "Apple Sign In credential import error"
            case .credentialExport:
                errorMessage = "Apple Sign In credential export error"
            @unknown default:
                errorMessage = "Apple Sign In error occurred"
            }
        } else {
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle() {
        print("🟢 Starting Google Sign-In...")
        isLoading = true
        errorMessage = nil
        
        // Get the presenting view controller using modern iOS API
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let presentingViewController = window.rootViewController else {
            print("❌ Unable to get presenting view controller")
            errorMessage = "Unable to present Google Sign In"
            isLoading = false
            return
        }
        
        // Check if Google Sign In is configured
        guard GIDSignIn.sharedInstance.configuration != nil else {
            print("❌ Google Sign In not configured")
            errorMessage = "Google Sign In not configured"
            isLoading = false
            return
        }
        
        print("🟢 Calling Google Sign In with presenting VC...")
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Google Sign In error: \(error.localizedDescription)")
                    self.errorMessage = "Google Sign In failed: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                guard let result = result else {
                    print("❌ No Google Sign In result")
                    self.errorMessage = "Google Sign In failed - no result"
                    self.isLoading = false
                    return
                }
                
                guard let idToken = result.user.idToken?.tokenString else {
                    print("❌ No Google ID token")
                    self.errorMessage = "Failed to get Google ID token"
                    self.isLoading = false
                    return
                }
                
                print("✅ Google Sign In successful, got ID token")
                
                do {
                    let profile = result.user.profile
                    let email = profile?.email ?? ""
                    let firstName = profile?.givenName ?? ""
                    let lastName = profile?.familyName ?? ""
                    let username = self.generateUsername(
                        from: firstName,
                        lastName: lastName,
                        email: email,
                        provider: "google"
                    )
                    
                    // Send to Supabase for authentication
                    let user = try await SupabaseService.shared.signInWithGoogle(
                        idToken: idToken,
                        email: email,
                        username: username,
                        firstName: firstName,
                        lastName: lastName
                    )
                    
                    // Store token in keychain
                    self.keychainService.saveToken(idToken)
                    
                    self.isLoading = false
                    self.errorMessage = nil
                    
                    // Store user data but don't mark as authenticated yet
                    self.currentUser = user
                    
                    // Show username customization
                    self.suggestedUsername = username
                    self.userEmail = email
                    self.showUsernameCustomization = true
                    
                    // Don't set authenticated yet - wait for profile completion
                    // self.isAuthenticated = true will be set in completeProfileSetup()
                    
                } catch {
                    self.errorMessage = "Google Sign In failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Email/Password Sign In
    
    func signIn(email: String, password: String) async {
        await signIn(usernameOrEmail: email, password: password)
    }
    
    func signIn(usernameOrEmail: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Determine if input is email or username
            let emailToUse: String
            if usernameOrEmail.contains("@") {
                // Input looks like an email
                emailToUse = usernameOrEmail
            } else {
                // Input looks like a username, need to get email from database
                emailToUse = try await SupabaseService.shared.getEmailByUsername(usernameOrEmail)
            }
            
            let user = try await SupabaseService.shared.signIn(email: emailToUse, password: password)
            
            // Store session token
            if let token = try? await SupabaseService.shared.getCurrentSessionToken() {
                keychainService.saveToken(token)
            }
            
            currentUser = user
            isAuthenticated = true
            isLoading = false
            errorMessage = nil
            
            // Sync with OneSignal
            syncUserWithOneSignal(user)
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func signUp(email: String, password: String, username: String) async {
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        guard isValidPassword(password) else {
            errorMessage = "Password must include one capital letter, one number, and one special character (!$%^&*)"
            return
        }
        
        guard isValidUsername(username) else {
            errorMessage = "Username must be 3-20 characters and contain only letters, numbers, and underscores"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await SupabaseService.shared.signUp(email: email, password: password, username: username)
            
            // Store session token
            if let token = try? await SupabaseService.shared.getCurrentSessionToken() {
                keychainService.saveToken(token)
            }
            
            currentUser = user
            isAuthenticated = true
            isLoading = false
            errorMessage = nil
            
            // Sync with OneSignal
            syncUserWithOneSignal(user)
        } catch {
            errorMessage = "Sign up failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    // MARK: - Credentials Sign Up
    
    func signUpWithCredentials(username: String, password: String) {
        guard isValidUsername(username) else {
            errorMessage = "Username must be 3-20 characters and contain only letters, numbers, and underscores"
            return
        }
        
        guard isValidPassword(password) else {
            errorMessage = "Password must include one capital letter, one number, and one special character (!$%^&*)"
            return
        }
        
        // Store the credentials temporarily and show profile customization
        self.tempCredentials = TempCredentials(username: username, password: password)
        self.suggestedUsername = username
        self.userEmail = "" // User will need to provide this
        self.showUsernameCustomization = true
    }
    
    // MARK: - Profile Management
    
    func updateUserProfile(username: String, preferredLanguage: String, profileImageURL: String?) async throws {
        guard let currentUser = currentUser else {
            throw AuthenticationError.notAuthenticated
        }
        
        // Update user in Supabase
        let updatedUser = try await SupabaseService.shared.updateUserProfile(
            userId: currentUser.id,
            username: username,
            preferredLanguage: preferredLanguage,
            profileImageURL: profileImageURL
        )
        
        // Update local user
        self.currentUser = updatedUser
    }
    
    func completeProfileSetup(user: User) {
        currentUser = user
        isAuthenticated = true
        showUsernameCustomization = false
        tempCredentials = nil // Clear temporary storage
        
        // Sync with OneSignal
        syncUserWithOneSignal(user)
    }
    
    func completeUsernamePasswordSetup(finalUsername: String, email: String, preferredLanguage: String, profileImageURL: String?) async throws {
        guard let credentials = tempCredentials else {
            throw AuthenticationError.invalidCredential
        }
        
        // Don't set isLoading here since it's already set in the calling view
        errorMessage = nil
        
        do {
            let user = try await SupabaseService.shared.signUp(
                email: email, 
                password: credentials.password, 
                username: finalUsername,
                preferredLanguage: preferredLanguage
            )
            
            // Store session token
            if let token = try? await SupabaseService.shared.getCurrentSessionToken() {
                keychainService.saveToken(token)
            }
            
            // Update user with profile image if provided
            var finalUser = user
            if let profileImageURL = profileImageURL {
                finalUser = try await SupabaseService.shared.updateUserProfile(
                    userId: user.id,
                    username: finalUsername,
                    preferredLanguage: preferredLanguage,
                    profileImageURL: profileImageURL
                )
            }
            
            // Since this class is @MainActor, we're already on the main thread
            self.completeProfileSetup(user: finalUser)
            
        } catch {
            // Since this class is @MainActor, we're already on the main thread
            self.errorMessage = "Sign up failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        do {
            try await SupabaseService.shared.signOut()
            keychainService.deleteToken()
            
            // Logout from OneSignal
            logoutFromOneSignal()
            
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = "Sign out failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Validation
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        // At least 8 characters, one uppercase, one number, one special character from approved list
        let passwordRegex = "^(?=.*[A-Z])(?=.*\\d)(?=.*[!@#$%^&*_\\.-])(?=.*[a-z]).{8,}$"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        return passwordPredicate.evaluate(with: password)
    }
    
    func validatePasswordRealTime(_ password: String) {
        passwordValidation.hasMinLength = password.count >= 8
        passwordValidation.hasUppercase = password.contains { $0.isUppercase }
        passwordValidation.hasNumber = password.contains { $0.isNumber }
        passwordValidation.hasSpecialChar = password.contains { "!@#$%^&*_-.".contains($0) }
    }
    
    // MARK: - Smart Username Generation
    
    private func generateUsername(from firstName: String, lastName: String, email: String, provider: String) -> String {
        let cleanFirstName = cleanString(firstName)
        let cleanLastName = cleanString(lastName)
        let emailPrefix = email.components(separatedBy: "@").first ?? ""
        
        // Strategy 1: Use full name if available
        if !cleanFirstName.isEmpty && !cleanLastName.isEmpty {
            let fullName = "\(cleanFirstName.lowercased())\(cleanLastName.lowercased())"
            if fullName.count >= 3 && fullName.count <= 20 {
                return fullName
            }
        }
        
        // Strategy 2: Use first name + random number
        if !cleanFirstName.isEmpty {
            let randomNum = Int.random(in: 10...99)
            let username = "\(cleanFirstName.lowercased())\(randomNum)"
            if username.count <= 20 {
                return username
            }
        }
        
        // Strategy 3: Use email prefix if clean
        if !emailPrefix.isEmpty && emailPrefix.count >= 3 {
            let cleanEmail = cleanString(emailPrefix)
            if cleanEmail.count >= 3 && cleanEmail.count <= 20 {
                return cleanEmail.lowercased()
            }
        }
        
        // Strategy 4: Provider-based fallback with random number
        let randomNum = Int.random(in: 1000...9999)
        return "\(provider)_user_\(randomNum)"
    }
    
    private func cleanString(_ input: String) -> String {
        // Remove non-alphanumeric characters and keep only valid username chars
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return input.components(separatedBy: allowed.inverted).joined()
    }
    
    private func isValidUsername(_ username: String) -> Bool {
        // 3-20 characters, letters, numbers, underscores only
        let usernameRegex = "^[a-zA-Z0-9_]{3,20}$"
        let usernamePredicate = NSPredicate(format: "SELF MATCHES %@", usernameRegex)
        return usernamePredicate.evaluate(with: username)
    }
    
    // MARK: - Check Existing Authentication
    
    private func checkExistingAuthentication() {
        print("🔍 Checking existing authentication...")
        
        // Ensure we start with loading false and no auth
        isLoading = false
        isAuthenticated = false
        currentUser = nil
        
        if let token = keychainService.getToken() {
            print("🔑 Found existing token, validating...")
            isLoading = true
            
            Task {
                do {
                    // Try to validate the token
                    let user = try await withTimeout(seconds: 5) {
                        try await SupabaseService.shared.getCurrentUser()
                    }
                    
                    print("✅ Token validated, user authenticated")
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
                        self.isLoading = false
                        
                        // Sync with OneSignal if user is restored
                        if let user = user {
                            self.syncUserWithOneSignal(user)
                        }
                    }
                } catch {
                    // Token is invalid or network timeout, clear it
                    print("❌ Authentication check failed: \(error)")
                    keychainService.deleteToken()
                    
                    await MainActor.run {
                        self.isAuthenticated = false
                        self.currentUser = nil
                        self.isLoading = false
                    }
                }
            }
        } else {
            print("📭 No existing token found")
            isLoading = false
        }
    }
    
    // Helper function for timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AuthenticationError.networkError
            }
            
            guard let result = try await group.next() else {
                throw AuthenticationError.networkError
            }
            
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Authentication Errors

enum AuthenticationError: LocalizedError {
    case notAuthenticated
    case invalidCredential
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidCredential:
            return "Invalid credentials"
        case .networkError:
            return "Network error occurred"
        }
    }
}

// MARK: - Apple Sign In Delegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    weak var authManager: AuthenticationManager?
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            authManager?.handleAppleSignInSuccess(credential: appleIDCredential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        authManager?.handleAppleSignInError(error)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            // Fallback: create a basic window if no scene available
            return UIWindow()
        }
        return window
    }
}

// MARK: - Temporary placeholders until Google Sign In SDK is added
struct GoogleSignInResult {
    // Placeholder for Google Sign In result
}

 