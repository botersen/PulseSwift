import Foundation
import Supabase
import Auth
import Combine

// MARK: - Supabase Service
class SupabaseService {
    
    // MARK: - Singleton
    static let shared = SupabaseService()
    
    // MARK: - Properties
    let client: SupabaseClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Current User
    var currentUserId: UUID? {
        return client.auth.currentUser?.id
    }
    
    var currentUser: User? {
        return client.auth.currentUser
    }
    
    var isAuthenticated: Bool {
        return client.auth.currentUser != nil
    }
    
    // MARK: - Initialization
    private init() {
        // Use environment variables for Supabase credentials
        // To set these in Xcode: Edit Scheme > Run > Arguments > Environment Variables
        // SUPABASE_URL = https://nlkmhztubzbnkjjgkpop.supabase.co
        // SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5sa21oenR1YnpibmtqamdrcG9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMzNzIzMDAsImV4cCI6MjA2ODk0ODMwMH0.W2tAupHuyUIrpWNHMC3-XY2m15pCoz2QRoTbRITuqg0
        let supabaseURLString = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://placeholder.supabase.co"
        let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "placeholder-key"
        
        guard let supabaseURL = URL(string: supabaseURLString) else {
            print("⚠️ SupabaseService: Invalid URL configuration, using development mode")
            let fallbackURL = URL(string: "https://demo.supabase.co")!
            self.client = SupabaseClient(
                supabaseURL: fallbackURL,
                supabaseKey: "demo-key"
            )
            return
        }
        
        print("✅ SupabaseService: Initializing with URL: \(supabaseURL)")
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey
        )
        
        setupAuthStateListener()
    }
    
    // MARK: - Auth State Management
    private func setupAuthStateListener() {
        // TODO: Fix auth state listener with proper async context
        print("⚠️ SupabaseService: Auth state listener temporarily disabled")
    }
    
    // MARK: - Authentication Methods
    func signIn(email: String, password: String) async throws -> Session {
        return try await client.auth.signIn(email: email, password: password)
    }
    
    func signUp(email: String, password: String) async throws -> Session {
        let authResponse = try await client.auth.signUp(email: email, password: password)
        guard let session = authResponse.session else {
            throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No session returned from signup"])
        }
        return session
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func refreshSession() async throws {
        try await client.auth.refreshSession()
    }
    
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }
    
    func signInWithAppleIdToken(idToken: String) async throws -> Session {
        // Uses Supabase's signInWithIdToken for Apple (latest SDK)
        let credentials = OpenIDConnectCredentials(
            provider: OpenIDConnectCredentials.Provider.apple, // use the enum, not a string
            idToken: idToken,
            nonce: nil
        )
        return try await client.auth.signInWithIdToken(credentials: credentials)
    }
    
    // MARK: - Database Operations
    func insert<T: Codable>(_ values: T, into table: String) async throws -> T {
        return try await client
            .from(table)
            .insert(values)
            .select("*")
            .single()
            .execute()
            .value
    }
    
    func select<T: Codable>(
        _ type: T.Type,
        from table: String,
        where condition: String? = nil
    ) async throws -> [T] {
        var query = client.from(table).select("*")
        
        if let condition = condition {
            query = query.eq("id", value: condition)
        }
        
        return try await query.execute().value
    }
    
    func update<T: Codable>(
        _ values: T,
        in table: String,
        where condition: String
    ) async throws -> T {
        return try await client
            .from(table)
            .update(values)
            .eq("id", value: condition)
            .select("*")
            .single()
            .execute()
            .value
    }
    
    func delete(from table: String, where condition: String) async throws {
        try await client
            .from(table)
            .delete()
            .eq("id", value: condition)
            .execute()
    }
    
    // MARK: - Real-time Subscriptions
    func createRealtimeChannel(channelName: String) -> RealtimeChannelV2 {
        return client.realtimeV2.channel(channelName)
    }
    
    // MARK: - Storage Operations
    func uploadFile(
        bucket: String,
        path: String,
        file: Data,
        fileOptions: FileOptions? = nil
    ) async throws -> FileUploadResponse {
        // Use the new signature: upload(_ path: String, data: Data, options: FileOptions?)
        return try await client.storage
            .from(bucket)
            .upload(path, data: file, options: fileOptions ?? FileOptions())
    }
    
    func downloadFile(bucket: String, path: String) async throws -> Data {
        return try await client.storage
            .from(bucket)
            .download(path: path)
    }
    
    func deleteFile(bucket: String, paths: [String]) async throws -> [FileObject] {
        return try await client.storage
            .from(bucket)
            .remove(paths: paths)
    }
    
    func getPublicURL(bucket: String, path: String) throws -> URL {
        return try client.storage
            .from(bucket)
            .getPublicURL(path: path)
    }
    
    // MARK: - RPC (Remote Procedure Calls)
    func callFunction<T: Codable>(
        _ functionName: String,
        parameters: [String: AnyJSON] = [:],
        returning type: T.Type
    ) async throws -> T {
        return try await client
            .rpc(functionName, params: parameters)
            .execute()
            .value
    }
}

// MARK: - Configuration
extension SupabaseService {
    enum Config {
        static let supabaseURL = "YOUR_SUPABASE_URL"
        static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
        
        // Table names
        static let usersTable = "users"
        static let pulsesTable = "pulses"
        static let matchesTable = "matches"
        static let pulseMatchesTable = "pulse_matches"
        static let userLocationsTable = "user_locations"
        static let pulseHistoryTable = "pulse_history"
        
        // Storage buckets
        static let profileImagesBucket = "profile-images"
        static let pulseMediaBucket = "pulse-media"
        static let thumbnailsBucket = "thumbnails"
    }
}

// MARK: - Error Handling
extension SupabaseService {
    enum SupabaseServiceError: Error, LocalizedError {
        case notAuthenticated
        case invalidResponse
        case networkError(Error)
        case decodingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "User is not authenticated"
            case .invalidResponse:
                return "Invalid response from server"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Decoding error: \(error.localizedDescription)"
            }
        }
    }
} 