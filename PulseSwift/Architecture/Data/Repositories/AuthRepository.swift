import Foundation
import Combine
import AuthenticationServices
import GoogleSignIn
import Supabase
import Auth

// MARK: - Authentication Repository Implementation
final class AuthRepository: NSObject, AuthRepositoryProtocol {
    
    // MARK: - Publishers
    private let authStateSubject = CurrentValueSubject<AuthState, Never>(.unauthenticated)
    private let currentUserSubject = CurrentValueSubject<UserEntity?, Never>(nil)
    
    var authStatePublisher: AnyPublisher<AuthState, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    var currentUserPublisher: AnyPublisher<UserEntity?, Never> {
        currentUserSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Services
    @Injected private var keychainService: KeychainService
    @Injected private var supabaseService: SupabaseService
    private var appleSignInDelegate: AppleSignInDelegate?
    
    override init() {
        super.init()
        setupGoogleSignIn()
        checkAuthStatusOnLaunch()
    }
    
    // MARK: - Authentication Methods
    func signInWithApple() async throws -> UserEntity {
        return try await withCheckedThrowingContinuation { continuation in
            performAppleSignIn { result in
                continuation.resume(with: result)
            }
        }
    }
    
    func processAppleSignInResult(_ authorization: ASAuthorization) async throws -> UserEntity {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw AuthError.invalidCredentials
        }
        
        let email = appleIDCredential.email ?? ""
        let fullName = appleIDCredential.fullName
        let firstName = fullName?.givenName ?? ""
        let lastName = fullName?.familyName ?? ""
        
        return try await processAppleSignIn(
            tokenString: tokenString,
            email: email,
            firstName: firstName,
            lastName: lastName
        )
    }
    
    func signInWithGoogle() async throws -> UserEntity {
        // Must access UI elements on main thread
        let presentingVC = await MainActor.run { () -> UIViewController? in
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let presentingVC = window.rootViewController else {
                return nil
            }
            return presentingVC
        }
        
        guard let presentingVC = presentingVC else {
            throw AuthError.unknown(NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "No presenting view controller"]))
        }
        
        // CRITICAL: Use async Google Sign In API to resolve compiler warning
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingVC)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.invalidCredentials
        }
        
        return try await processGoogleSignIn(idToken: idToken, googleUser: result.user)
    }
    
    func signInWithCredentials(username: String, password: String) async throws -> UserEntity {
        authStateSubject.send(.authenticating)
        
        do {
            // Determine if input is email or username
            let email = username.contains("@") ? username : try await getEmailByUsername(username)
            let session = try await supabaseService.signIn(email: email, password: password)
            let userEntity = session.user.toEntity()
            await updateAuthState(.authenticated(userEntity))
            
            return userEntity
        } catch {
            await updateAuthState(.error(.networkError))
            throw AuthError.networkError
        }
    }
    
    func signUp(username: String, email: String, password: String) async throws -> UserEntity {
        authStateSubject.send(.authenticating)
        
        do {
            let session = try await supabaseService.signUp(email: email, password: password)
            let userEntity = session.user.toEntity()
            await updateAuthState(.authenticated(userEntity))
            return userEntity
        } catch {
            await updateAuthState(.error(.networkError))
            throw AuthError.networkError
        }
    }
    
    func signOut() async throws {
        try await supabaseService.signOut()
        try keychainService.delete(for: "auth_token")
        await updateAuthState(.unauthenticated)
    }
    
    func checkAuthStatus() async -> Bool {
        return (try? keychainService.retrieve(String.self, for: "auth_token")) != nil
    }
    
    func refreshSession() async throws {
        // Implement session refresh logic
    }
    
    func updateProfile(username: String?, profileImageURL: String?) async throws -> UserEntity {
        // Implement profile update logic
        guard let currentUser = currentUserSubject.value else {
            throw AuthError.invalidCredentials
        }
        
        // Return updated user entity
        return currentUser
    }
    
    // MARK: - Private Methods
    private func setupGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "Google", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("❌ AuthRepository: Failed to configure Google Sign In")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        print("✅ AuthRepository: Google Sign In configured")
    }
    
    private func checkAuthStatusOnLaunch() {
        if (try? keychainService.retrieve(String.self, for: "auth_token")) != nil {
            // Create basic user entity for fast startup
            let cachedUser = UserEntity(username: "cached_user", isAuthenticated: true)
            currentUserSubject.send(cachedUser)
            authStateSubject.send(.authenticated(cachedUser))
            
            // Validate in background
            Task.detached {
                await self.validateTokenInBackground()
            }
        }
    }
    
    private func validateTokenInBackground() async {
        // Background token validation without blocking UI
        if let _ = supabaseService.currentUser {
            print("✅ Background token validation successful")
        } else {
            print("⚠️ Background token validation failed - no current user")
            // Don't immediately log out - handle gracefully
        }
    }
    
    private func updateAuthState(_ state: AuthState) async {
        await MainActor.run {
            self.authStateSubject.send(state)
            
            switch state {
            case .authenticated(let user):
                self.currentUserSubject.send(user)
            case .unauthenticated, .error:
                self.currentUserSubject.send(nil)
            case .authenticating:
                break
            }
        }
    }
    
    private func performAppleSignIn(completion: @escaping (Result<UserEntity, Error>) -> Void) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authController = ASAuthorizationController(authorizationRequests: [request])
        
        let delegate = AppleSignInDelegate(authRepository: self) { result in
            completion(result)
        }
        
        self.appleSignInDelegate = delegate
        authController.delegate = delegate
        authController.presentationContextProvider = delegate
        authController.performRequests()
    }
    
    private func processGoogleSignIn(idToken: String, googleUser: GIDGoogleUser) async throws -> UserEntity {
        let email = googleUser.profile?.email ?? ""
        let username = generateUsername(from: googleUser.profile?.givenName ?? "", 
                                      lastName: googleUser.profile?.familyName ?? "", 
                                      email: email, 
                                      provider: "google")
        
        // Implement Google Sign In with Supabase
        do {
            // Create a user account with Supabase using Google credentials
            let tempPassword = UUID().uuidString // Generate secure temp password
            let session = try await self.supabaseService.signUp(email: email, password: tempPassword)
            
            // Store the Google token and password in keychain
            try self.keychainService.save(idToken, for: "google_id_token")
            try self.keychainService.save(tempPassword, for: "google_temp_password")
            
            // Create user entity
            let userEntity = UserEntity(
                id: session.user.id,
                username: username,
                email: email,
                subscriptionTier: .free,
                profileImageURL: googleUser.profile?.imageURL(withDimension: 200)?.absoluteString,
                isAuthenticated: true
            )
            
            print("✅ Google Sign In successful for user: \(email)")
            return userEntity
            
        } catch {
            // If user already exists, try to sign in instead
            do {
                if let savedPassword = try? self.keychainService.retrieve(String.self, for: "google_temp_password") {
                    let session = try await self.supabaseService.signIn(email: email, password: savedPassword)
                    let userEntity = session.user.toEntity()
                    print("✅ Google Sign In - existing user signed in: \(email)")
                    return userEntity
                } else {
                    throw AuthError.unknown(error)
                }
            } catch {
                print("❌ Google Sign In failed: \(error)")
                throw AuthError.unknown(error)
            }
        }
    }
    
    private func getEmailByUsername(_ username: String) async throws -> String {
        // TODO: Implement username lookup in database
        throw AuthError.invalidCredentials
    }
    
    func processAppleSignIn(
        tokenString: String,
        email: String,
        firstName: String,
        lastName: String
    ) async throws -> UserEntity {
        // Use Supabase's native Apple OAuth instead of fake emails
        do {
            let session = try await supabaseService.signInWithAppleIdToken(
                idToken: tokenString
            )
            
            // Store the Apple ID token in keychain for future reference
            try keychainService.save(tokenString, for: "apple_id_token")
            
            // Create user entity from Supabase user
            let userEntity = session.user.toEntity()
            
            print("✅ Apple Sign In successful with OAuth: \(session.user.email ?? "no email")")
            return userEntity
            
        } catch {
            print("❌ Apple Sign In OAuth failed: \(error)")
            throw AuthError.unknown(error)
        }
    }
    
    private func generateUsername(from firstName: String, lastName: String, email: String, provider: String) -> String {
        // Smart username generation logic
        if !firstName.isEmpty {
            return firstName.lowercased() + String(Int.random(in: 1000...9999))
        } else if !email.isEmpty {
            return String(email.prefix(while: { $0 != "@" }))
        } else {
            return provider + String(Int.random(in: 1000...9999))
        }
    }
}// MARK: - Apple Sign In Delegate
private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<UserEntity, Error>) -> Void
    weak var authRepository: AuthRepository?
    
    init(authRepository: AuthRepository, completion: @escaping (Result<UserEntity, Error>) -> Void) {
        self.authRepository = authRepository
        self.completion = completion
        super.init()
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            completion(.failure(AuthError.invalidCredentials))
            return
        }
        
        Task {
            let email = appleIDCredential.email ?? ""
            let fullName = appleIDCredential.fullName
            let firstName = fullName?.givenName ?? ""
            let lastName = fullName?.familyName ?? ""
            
            // Pass the credentials back to the main AuthRepository for processing
            Task { @MainActor in
                do {
                    guard let authRepository = self.authRepository else {
                        completion(.failure(AuthError.unknown(NSError(domain: "AuthRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "AuthRepository reference not found"]))))
                        return
                    }
                    
                    let userEntity = try await authRepository.processAppleSignIn(
                        tokenString: tokenString,
                        email: email,
                        firstName: firstName,
                        lastName: lastName
                    )
                    completion(.success(userEntity))
                } catch {
                    completion(.failure(AuthError.unknown(error)))
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(AuthError.unknown(error)))
    }
    
    @MainActor
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Supabase User Extension
private extension Auth.User {
    func toEntity() -> UserEntity {
        return UserEntity(
            id: self.id,
            username: extractString(from: self.userMetadata["username"]) ?? "User",
            email: self.email,
            subscriptionTier: .free, // Default for MVP
            profileImageURL: extractString(from: self.userMetadata["avatar_url"]),
            isAuthenticated: true
        )
    }
    
    private func extractString(from anyJSON: AnyJSON?) -> String? {
        switch anyJSON {
        case .string(let value):
            return value
        default:
            return nil
        }
    }
} 

