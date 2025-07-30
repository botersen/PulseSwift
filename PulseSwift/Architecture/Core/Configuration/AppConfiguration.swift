import Foundation

// MARK: - App Configuration (Environment Management)
final class AppConfiguration {
    
    // MARK: - Singleton
    static let current = AppConfiguration()
    
    // MARK: - Environment
    let environment: Environment
    let buildConfiguration: BuildConfiguration
    
    // MARK: - API Configuration
    let apiBaseURL: String
    let supabaseURL: String
    let supabaseAnonKey: String
    
    // MARK: - Feature Flags
    let features: FeatureFlags
    
    // MARK: - Performance Settings
    let performance: PerformanceSettings
    
    // MARK: - Security Settings
    let security: SecuritySettings
    
    // MARK: - Analytics Configuration
    let analytics: AnalyticsConfiguration
    
    private init() {
        // Detect current environment
        self.buildConfiguration = BuildConfiguration.current
        self.environment = Environment.detect(from: buildConfiguration)
        
        // Load configuration based on environment
        let config = Self.loadConfiguration(for: environment)
        
        self.apiBaseURL = config.apiBaseURL
        self.supabaseURL = config.supabaseURL
        self.supabaseAnonKey = config.supabaseAnonKey
        self.features = config.features
        self.performance = config.performance
        self.security = config.security
        self.analytics = config.analytics
        
        print("✅ AppConfiguration: Loaded \(environment) configuration")
        print("📍 API Base URL: \(apiBaseURL)")
        print("🎯 Features: \(features.debugDescription)")
    }
    
    // MARK: - Configuration Loading
    private static func loadConfiguration(for environment: Environment) -> ConfigurationData {
        switch environment {
        case .development:
            return developmentConfiguration()
        case .staging:
            return stagingConfiguration()
        case .production:
            return productionConfiguration()
        case .testing:
            return testingConfiguration()
        }
    }
    
    // MARK: - Development Configuration
    private static func developmentConfiguration() -> ConfigurationData {
        return ConfigurationData(
            apiBaseURL: "https://dev-api.pulse.app",
            supabaseURL: getSupabaseURL(fallback: "https://dev-project.supabase.co"),
            supabaseAnonKey: getSupabaseAnonKey(fallback: "dev_anon_key"),
            features: FeatureFlags(
                debugMenu: true,
                crashReporting: false,
                analytics: false,
                performanceMonitoring: true,
                betaFeatures: true,
                mockData: true,
                verboseLogging: true,
                skipOnboarding: false,
                forceUpdate: false
            ),
            performance: PerformanceSettings(
                imageQuality: .medium,
                videoQuality: .medium,
                cacheSize: 50 * 1024 * 1024, // 50MB
                networkTimeout: 30.0,
                maxRetries: 3,
                enablePrefetching: true
            ),
            security: SecuritySettings(
                certificatePinning: false,
                tokenRefreshThreshold: 5 * 60, // 5 minutes
                biometricAuthentication: false,
                dataEncryption: false
            ),
            analytics: AnalyticsConfiguration(
                enabled: false,
                crashlytics: false,
                performanceMetrics: true,
                userBehavior: false,
                customEvents: true
            )
        )
    }
    
    // MARK: - Staging Configuration
    private static func stagingConfiguration() -> ConfigurationData {
        return ConfigurationData(
            apiBaseURL: "https://staging-api.pulse.app",
            supabaseURL: getSupabaseURL(fallback: "https://staging-project.supabase.co"),
            supabaseAnonKey: getSupabaseAnonKey(fallback: "staging_anon_key"),
            features: FeatureFlags(
                debugMenu: true,
                crashReporting: true,
                analytics: true,
                performanceMonitoring: true,
                betaFeatures: true,
                mockData: false,
                verboseLogging: false,
                skipOnboarding: false,
                forceUpdate: false
            ),
            performance: PerformanceSettings(
                imageQuality: .high,
                videoQuality: .high,
                cacheSize: 100 * 1024 * 1024, // 100MB
                networkTimeout: 30.0,
                maxRetries: 3,
                enablePrefetching: true
            ),
            security: SecuritySettings(
                certificatePinning: true,
                tokenRefreshThreshold: 5 * 60, // 5 minutes
                biometricAuthentication: true,
                dataEncryption: true
            ),
            analytics: AnalyticsConfiguration(
                enabled: true,
                crashlytics: true,
                performanceMetrics: true,
                userBehavior: true,
                customEvents: true
            )
        )
    }
    
    // MARK: - Production Configuration
    private static func productionConfiguration() -> ConfigurationData {
        return ConfigurationData(
            apiBaseURL: "https://api.pulse.app",
            supabaseURL: getSupabaseURL(fallback: "https://pulse-project.supabase.co"),
            supabaseAnonKey: getSupabaseAnonKey(fallback: "prod_anon_key"),
            features: FeatureFlags(
                debugMenu: false,
                crashReporting: true,
                analytics: true,
                performanceMonitoring: true,
                betaFeatures: false,
                mockData: false,
                verboseLogging: false,
                skipOnboarding: false,
                forceUpdate: true
            ),
            performance: PerformanceSettings(
                imageQuality: .high,
                videoQuality: .high,
                cacheSize: 200 * 1024 * 1024, // 200MB
                networkTimeout: 20.0,
                maxRetries: 5,
                enablePrefetching: true
            ),
            security: SecuritySettings(
                certificatePinning: true,
                tokenRefreshThreshold: 2 * 60, // 2 minutes
                biometricAuthentication: true,
                dataEncryption: true
            ),
            analytics: AnalyticsConfiguration(
                enabled: true,
                crashlytics: true,
                performanceMetrics: true,
                userBehavior: true,
                customEvents: true
            )
        )
    }
    
    // MARK: - Testing Configuration
    private static func testingConfiguration() -> ConfigurationData {
        return ConfigurationData(
            apiBaseURL: "https://test-api.pulse.app",
            supabaseURL: "https://test-project.supabase.co",
            supabaseAnonKey: "test_anon_key",
            features: FeatureFlags(
                debugMenu: false,
                crashReporting: false,
                analytics: false,
                performanceMonitoring: false,
                betaFeatures: false,
                mockData: true,
                verboseLogging: false,
                skipOnboarding: true,
                forceUpdate: false
            ),
            performance: PerformanceSettings(
                imageQuality: .low,
                videoQuality: .low,
                cacheSize: 10 * 1024 * 1024, // 10MB
                networkTimeout: 10.0,
                maxRetries: 1,
                enablePrefetching: false
            ),
            security: SecuritySettings(
                certificatePinning: false,
                tokenRefreshThreshold: 10 * 60, // 10 minutes
                biometricAuthentication: false,
                dataEncryption: false
            ),
            analytics: AnalyticsConfiguration(
                enabled: false,
                crashlytics: false,
                performanceMetrics: false,
                userBehavior: false,
                customEvents: false
            )
        )
    }
    
    // MARK: - Environment Variable Helpers
    private static func getSupabaseURL(fallback: String) -> String {
        return ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? fallback
    }
    
    private static func getSupabaseAnonKey(fallback: String) -> String {
        return ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? fallback
    }
}

// MARK: - Environment Detection
enum Environment: String, CaseIterable {
    case development = "Development"
    case staging = "Staging"
    case production = "Production"
    case testing = "Testing"
    
    static func detect(from buildConfig: BuildConfiguration) -> Environment {
        // Check for testing first
        if NSClassFromString("XCTestCase") != nil {
            return .testing
        }
        
        // Check environment variable override
        if let envOverride = ProcessInfo.processInfo.environment["PULSE_ENV"],
           let environment = Environment(rawValue: envOverride) {
            return environment
        }
        
        // Detect from build configuration
        switch buildConfig {
        case .debug:
            return .development
        case .release:
            // Check if this is staging or production
            if Bundle.main.bundleIdentifier?.contains("staging") == true {
                return .staging
            } else {
                return .production
            }
        }
    }
}

enum BuildConfiguration {
    case debug
    case release
    
    static var current: BuildConfiguration {
        #if DEBUG
        return .debug
        #else
        return .release
        #endif
    }
}

// MARK: - Configuration Data Structure
private struct ConfigurationData {
    let apiBaseURL: String
    let supabaseURL: String
    let supabaseAnonKey: String
    let features: FeatureFlags
    let performance: PerformanceSettings
    let security: SecuritySettings
    let analytics: AnalyticsConfiguration
}

// MARK: - Feature Flags
struct FeatureFlags {
    let debugMenu: Bool
    let crashReporting: Bool
    let analytics: Bool
    let performanceMonitoring: Bool
    let betaFeatures: Bool
    let mockData: Bool
    let verboseLogging: Bool
    let skipOnboarding: Bool
    let forceUpdate: Bool
    
    var debugDescription: String {
        var flags: [String] = []
        if debugMenu { flags.append("debug") }
        if crashReporting { flags.append("crash") }
        if analytics { flags.append("analytics") }
        if performanceMonitoring { flags.append("performance") }
        if betaFeatures { flags.append("beta") }
        if mockData { flags.append("mock") }
        if verboseLogging { flags.append("verbose") }
        if skipOnboarding { flags.append("skip-onboard") }
        if forceUpdate { flags.append("force-update") }
        return flags.isEmpty ? "none" : flags.joined(separator: ", ")
    }
}

// MARK: - Performance Settings
struct PerformanceSettings {
    let imageQuality: MediaQuality
    let videoQuality: MediaQuality
    let cacheSize: Int
    let networkTimeout: TimeInterval
    let maxRetries: Int
    let enablePrefetching: Bool
}

// MARK: - Security Settings
struct SecuritySettings {
    let certificatePinning: Bool
    let tokenRefreshThreshold: TimeInterval
    let biometricAuthentication: Bool
    let dataEncryption: Bool
}

// MARK: - Analytics Configuration
struct AnalyticsConfiguration {
    let enabled: Bool
    let crashlytics: Bool
    let performanceMetrics: Bool
    let userBehavior: Bool
    let customEvents: Bool
}

// MARK: - Remote Configuration (Future)
protocol RemoteConfigurationProtocol {
    func fetchRemoteConfig() async throws
    func getValue<T>(for key: String, defaultValue: T) -> T
    func getBoolValue(for key: String, defaultValue: Bool) -> Bool
    func getStringValue(for key: String, defaultValue: String) -> String
    func getIntValue(for key: String, defaultValue: Int) -> Int
}

// MARK: - Configuration Extensions
extension AppConfiguration {
    
    // MARK: - Convenience Properties
    var isDebug: Bool {
        return environment == .development || environment == .testing
    }
    
    var isProduction: Bool {
        return environment == .production
    }
    
    var shouldShowDebugInfo: Bool {
        return features.debugMenu || features.verboseLogging
    }
    
    var shouldUseMockData: Bool {
        return features.mockData
    }
    
    // MARK: - Dynamic Configuration Updates
    func updateFeatureFlag(_ keyPath: WritableKeyPath<FeatureFlags, Bool>, value: Bool) {
        // This would typically update a mutable copy and notify observers
        // For now, we'll just log the change
        print("🔧 Configuration: Feature flag updated - \(keyPath) = \(value)")
    }
}

// MARK: - Configuration Validation
extension AppConfiguration {
    
    func validate() throws {
        // Validate URLs
        guard URL(string: apiBaseURL) != nil else {
            throw ConfigurationError.invalidAPIURL
        }
        
        guard URL(string: supabaseURL) != nil else {
            throw ConfigurationError.invalidSupabaseURL
        }
        
        // Validate keys
        guard !supabaseAnonKey.isEmpty else {
            throw ConfigurationError.missingSupabaseKey
        }
        
        // Validate performance settings
        guard performance.cacheSize > 0 else {
            throw ConfigurationError.invalidCacheSize
        }
        
        guard performance.networkTimeout > 0 else {
            throw ConfigurationError.invalidNetworkTimeout
        }
        
        print("✅ Configuration validation passed")
    }
}

enum ConfigurationError: LocalizedError {
    case invalidAPIURL
    case invalidSupabaseURL
    case missingSupabaseKey
    case invalidCacheSize
    case invalidNetworkTimeout
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIURL:
            return "Invalid API base URL in configuration"
        case .invalidSupabaseURL:
            return "Invalid Supabase URL in configuration"
        case .missingSupabaseKey:
            return "Missing Supabase anonymous key"
        case .invalidCacheSize:
            return "Invalid cache size configuration"
        case .invalidNetworkTimeout:
            return "Invalid network timeout configuration"
        }
    }
} 