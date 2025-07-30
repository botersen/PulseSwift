import Foundation
import Combine
import Security

// MARK: - Token Manager (Production-Ready Security)
protocol TokenManagerProtocol {
    func getValidToken() async throws -> String
    func refreshToken() async throws -> String
    func saveTokens(_ accessToken: String, refreshToken: String?, expiresIn: TimeInterval?) async
    func clearTokens() async
    func isTokenValid() async -> Bool
    
    var tokenDidExpire: AnyPublisher<Void, Never> { get }
}

final class TokenManager: TokenManagerProtocol {
    
    // MARK: - Properties
    private let keychainService: KeychainServiceProtocol
    private let networkService: NetworkServiceProtocol
    
    // MARK: - Publishers
    private let tokenExpiredSubject = PassthroughSubject<Void, Never>()
    var tokenDidExpire: AnyPublisher<Void, Never> {
        tokenExpiredSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Token Storage Keys
    private enum TokenKeys {
        static let accessToken = "pulse_access_token"
        static let refreshToken = "pulse_refresh_token"
        static let tokenExpiry = "pulse_token_expiry"
        static let tokenType = "pulse_token_type"
    }
    
    // MARK: - Configuration
    private let refreshThresholdMinutes: TimeInterval = 5 * 60 // Refresh 5 min before expiry
    private let maxRefreshAttempts = 3
    
    // MARK: - State
    private var isRefreshing = false
    private var refreshCompletions: [CheckedContinuation<String, Error>] = []
    private let refreshQueue = DispatchQueue(label: "com.pulse.token.refresh", qos: .userInitiated)
    
    init(keychainService: KeychainServiceProtocol, networkService: NetworkServiceProtocol) {
        self.keychainService = keychainService
        self.networkService = networkService
        
        setupTokenExpirationMonitoring()
        print("✅ TokenManager: Initialized with auto-refresh")
    }
    
    // MARK: - Public Methods
    func getValidToken() async throws -> String {
        // Check if we have a token
        guard let token = await getStoredAccessToken() else {
            throw TokenError.noTokenAvailable
        }
        
        // Check if token is still valid
        if await isTokenExpiredOrExpiringSoon() {
            // Try to refresh token
            return try await refreshToken()
        }
        
        return token
    }
    
    func refreshToken() async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            refreshQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: TokenError.managerDeallocated)
                    return
                }
                
                // If already refreshing, queue this request
                if self.isRefreshing {
                    self.refreshCompletions.append(continuation)
                    return
                }
                
                // Start refresh process
                self.isRefreshing = true
                self.refreshCompletions.append(continuation)
                
                Task {
                    do {
                        let newToken = try await self.performTokenRefresh()
                        await self.completeRefreshRequests(with: .success(newToken))
                    } catch {
                        await self.completeRefreshRequests(with: .failure(error))
                    }
                }
            }
        }
    }
    
    func saveTokens(_ accessToken: String, refreshToken: String?, expiresIn: TimeInterval?) async {
        // Calculate expiry time
        let expiryDate: Date
        if let expiresIn = expiresIn {
            expiryDate = Date().addingTimeInterval(expiresIn)
        } else {
            // Default to 1 hour if not specified
            expiryDate = Date().addingTimeInterval(3600)
        }
        
        // Save tokens to keychain
        await keychainService.save(accessToken, forKey: TokenKeys.accessToken)
        
        if let refreshToken = refreshToken {
            await keychainService.save(refreshToken, forKey: TokenKeys.refreshToken)
        }
        
        // Save expiry time
        let expiryTimestamp = expiryDate.timeIntervalSince1970
        await keychainService.save(String(expiryTimestamp), forKey: TokenKeys.tokenExpiry)
        
        print("✅ TokenManager: Tokens saved, expires at \(expiryDate)")
    }
    
    func clearTokens() async {
        await keychainService.delete(forKey: TokenKeys.accessToken)
        await keychainService.delete(forKey: TokenKeys.refreshToken)
        await keychainService.delete(forKey: TokenKeys.tokenExpiry)
        await keychainService.delete(forKey: TokenKeys.tokenType)
        
        print("✅ TokenManager: All tokens cleared")
    }
    
    func isTokenValid() async -> Bool {
        guard await getStoredAccessToken() != nil else {
            return false
        }
        
        return !(await isTokenExpiredOrExpiringSoon())
    }
    
    // MARK: - Private Methods
    private func setupTokenExpirationMonitoring() {
        // Monitor for token expiration every minute
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.checkTokenExpiration()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func checkTokenExpiration() async {
        if await isTokenExpiredOrExpiringSoon() {
            print("⚠️ TokenManager: Token expired or expiring soon")
            tokenExpiredSubject.send()
        }
    }
    
    private func getStoredAccessToken() async -> String? {
        return await keychainService.get(forKey: TokenKeys.accessToken)
    }
    
    private func getStoredRefreshToken() async -> String? {
        return await keychainService.get(forKey: TokenKeys.refreshToken)
    }
    
    private func getTokenExpiryDate() async -> Date? {
        guard let expiryString = await keychainService.get(forKey: TokenKeys.tokenExpiry),
              let expiryTimestamp = Double(expiryString) else {
            return nil
        }
        
        return Date(timeIntervalSince1970: expiryTimestamp)
    }
    
    private func isTokenExpiredOrExpiringSoon() async -> Bool {
        guard let expiryDate = await getTokenExpiryDate() else {
            // If we can't determine expiry, assume it's expired
            return true
        }
        
        let now = Date()
        let thresholdDate = expiryDate.addingTimeInterval(-refreshThresholdMinutes)
        
        return now >= thresholdDate
    }
    
    private func performTokenRefresh() async throws -> String {
        guard let refreshToken = await getStoredRefreshToken() else {
            throw TokenError.noRefreshTokenAvailable
        }
        
        let endpoint = TokenRefreshEndpoint(refreshToken: refreshToken)
        
        do {
            let response: TokenResponse = try await networkService.request(
                endpoint,
                responseType: TokenResponse.self
            )
            
            // Save new tokens
            await saveTokens(
                response.accessToken,
                refreshToken: response.refreshToken ?? refreshToken,
                expiresIn: response.expiresIn
            )
            
            print("✅ TokenManager: Token refreshed successfully")
            return response.accessToken
            
        } catch {
            // If refresh fails, clear all tokens
            await clearTokens()
            print("❌ TokenManager: Token refresh failed, tokens cleared")
            throw TokenError.refreshFailed(error)
        }
    }
    
    private func completeRefreshRequests(with result: Result<String, Error>) async {
        await MainActor.run {
            refreshQueue.async { [weak self] in
                guard let self = self else { return }
                
                // Complete all pending requests
                for completion in self.refreshCompletions {
                    completion.resume(with: result)
                }
                
                self.refreshCompletions.removeAll()
                self.isRefreshing = false
            }
        }
    }
}

// MARK: - Enhanced Keychain Service
protocol KeychainServiceProtocol {
    func save(_ value: String, forKey key: String) async
    func get(forKey key: String) async -> String?
    func delete(forKey key: String) async
    func deleteAll() async
}

final class EnhancedKeychainService: KeychainServiceProtocol {
    
    private let serviceIdentifier = "com.pulse.app"
    private let accessGroup: String? = nil // Can be set for app group sharing
    
    func save(_ value: String, forKey key: String) async {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        await delete(forKey: key)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Keychain: Saved \(key)")
        } else {
            print("❌ Keychain: Failed to save \(key), status: \(status)")
        }
    }
    
    func get(forKey key: String) async -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            if status != errSecItemNotFound {
                print("❌ Keychain: Failed to get \(key), status: \(status)")
            }
            return nil
        }
        
        return string
    }
    
    func delete(forKey key: String) async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ Keychain: Deleted \(key)")
        } else {
            print("❌ Keychain: Failed to delete \(key), status: \(status)")
        }
    }
    
    func deleteAll() async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        print("✅ Keychain: Deleted all items, status: \(status)")
    }
}

// MARK: - Token Refresh Endpoint
struct TokenRefreshEndpoint: APIEndpoint {
    let refreshToken: String
    
    var baseURL: String {
        return AppConfiguration.current.apiBaseURL
    }
    
    var path: String {
        return "/auth/refresh"
    }
    
    var method: HTTPMethod {
        return .POST
    }
    
    var headers: [String: String] {
        return [
            "Authorization": "Bearer \(refreshToken)",
            "Content-Type": "application/json"
        ]
    }
    
    var body: [String: Any]? {
        return [
            "refresh_token": refreshToken
        ]
    }
}

// MARK: - Token Response Model
struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: TimeInterval?
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

// MARK: - Token Errors
enum TokenError: LocalizedError, Equatable {
    case noTokenAvailable
    case noRefreshTokenAvailable
    case refreshFailed(Error)
    case tokenExpired
    case managerDeallocated
    
    var errorDescription: String? {
        switch self {
        case .noTokenAvailable:
            return "No authentication token available. Please sign in."
        case .noRefreshTokenAvailable:
            return "Unable to refresh authentication. Please sign in again."
        case .refreshFailed(let error):
            return "Token refresh failed: \(error.localizedDescription)"
        case .tokenExpired:
            return "Authentication expired. Please sign in again."
        case .managerDeallocated:
            return "Token manager was deallocated during refresh."
        }
    }
    
    static func == (lhs: TokenError, rhs: TokenError) -> Bool {
        switch (lhs, rhs) {
        case (.noTokenAvailable, .noTokenAvailable),
             (.noRefreshTokenAvailable, .noRefreshTokenAvailable),
             (.tokenExpired, .tokenExpired),
             (.managerDeallocated, .managerDeallocated):
            return true
        case (.refreshFailed, .refreshFailed):
            return true // Simplified comparison for errors
        default:
            return false
        }
    }
} 