import Foundation
import Combine
import Network

// MARK: - Network Service (Production-Ready)
protocol NetworkServiceProtocol {
    func request<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T
    func upload<T: Codable>(_ endpoint: APIEndpoint, data: Data, responseType: T.Type) async throws -> T
    func download(_ endpoint: APIEndpoint) async throws -> Data
    
    var isOnline: AnyPublisher<Bool, Never> { get }
    var networkStatus: AnyPublisher<NetworkStatus, Never> { get }
}

final class NetworkService: NetworkServiceProtocol {
    
    // MARK: - Properties
    private let session: URLSession
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.pulse.network.monitor")
    
    // MARK: - Publishers
    private let isOnlineSubject = CurrentValueSubject<Bool, Never>(true)
    private let networkStatusSubject = CurrentValueSubject<NetworkStatus, Never>(.connected(.wifi))
    
    var isOnline: AnyPublisher<Bool, Never> {
        isOnlineSubject.eraseToAnyPublisher()
    }
    
    var networkStatus: AnyPublisher<NetworkStatus, Never> {
        networkStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Configuration
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let timeoutInterval: TimeInterval = 30.0
    
    init() {
        // Configure URLSession for optimal performance
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval * 2
        config.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024, // 50MB memory
            diskCapacity: 100 * 1024 * 1024,  // 100MB disk
            diskPath: "pulse_network_cache"
        )
        
        self.session = URLSession(configuration: config)
        
        setupNetworkMonitoring()
        print("✅ NetworkService: Initialized with monitoring")
    }
    
    // MARK: - Public Methods
    func request<T: Codable>(_ endpoint: APIEndpoint, responseType: T.Type) async throws -> T {
        // Check online status
        guard isOnlineSubject.value else {
            throw NetworkError.offline
        }
        
        let request = try buildRequest(for: endpoint)
        return try await performRequestWithRetry(request: request, responseType: responseType)
    }
    
    func upload<T: Codable>(_ endpoint: APIEndpoint, data: Data, responseType: T.Type) async throws -> T {
        guard isOnlineSubject.value else {
            throw NetworkError.offline
        }
        
        var request = try buildRequest(for: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        return try await performRequestWithRetry(request: request, responseType: responseType)
    }
    
    func download(_ endpoint: APIEndpoint) async throws -> Data {
        guard isOnlineSubject.value else {
            throw NetworkError.offline
        }
        
        let request = try buildRequest(for: endpoint)
        return try await performDownloadWithRetry(request: request)
    }
    
    // MARK: - Private Methods
    private func setupNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handleNetworkChange(path)
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    private func handleNetworkChange(_ path: NWPath) {
        let isConnected = path.status == .satisfied
        isOnlineSubject.send(isConnected)
        
        let status: NetworkStatus
        if !isConnected {
            status = .disconnected
        } else if path.usesInterfaceType(.wifi) {
            status = .connected(.wifi)
        } else if path.usesInterfaceType(.cellular) {
            status = .connected(.cellular)
        } else {
            status = .connected(.other)
        }
        
        networkStatusSubject.send(status)
        
        print("📡 NetworkService: Status changed to \(status)")
    }
    
    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        guard let url = URL(string: endpoint.fullURL) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = timeoutInterval
        
        // Add headers
        endpoint.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body for POST/PUT requests
        if let body = endpoint.body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        return request
    }
    
    private func performRequestWithRetry<T: Codable>(
        request: URLRequest,
        responseType: T.Type,
        attempt: Int = 1
    ) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle HTTP status codes
            switch httpResponse.statusCode {
            case 200...299:
                return try JSONDecoder().decode(responseType, from: data)
                
            case 401:
                throw NetworkError.unauthorized
                
            case 403:
                throw NetworkError.forbidden
                
            case 404:
                throw NetworkError.notFound
                
            case 429:
                // Rate limiting - wait and retry
                if attempt < maxRetries {
                    let delay = calculateRetryDelay(attempt: attempt, isRateLimit: true)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequestWithRetry(
                        request: request,
                        responseType: responseType,
                        attempt: attempt + 1
                    )
                }
                throw NetworkError.rateLimited
                
            case 500...599:
                // Server error - retry with exponential backoff
                if attempt < maxRetries {
                    let delay = calculateRetryDelay(attempt: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await performRequestWithRetry(
                        request: request,
                        responseType: responseType,
                        attempt: attempt + 1
                    )
                }
                throw NetworkError.serverError(httpResponse.statusCode)
                
            default:
                throw NetworkError.httpError(httpResponse.statusCode)
            }
            
        } catch {
            // Network errors - retry with exponential backoff
            if attempt < maxRetries && isRetryableError(error) {
                let delay = calculateRetryDelay(attempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await performRequestWithRetry(
                    request: request,
                    responseType: responseType,
                    attempt: attempt + 1
                )
            }
            
            throw mapError(error)
        }
    }
    
    private func performDownloadWithRetry(
        request: URLRequest,
        attempt: Int = 1
    ) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NetworkError.invalidResponse
            }
            
            return data
            
        } catch {
            if attempt < maxRetries && isRetryableError(error) {
                let delay = calculateRetryDelay(attempt: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await performDownloadWithRetry(request: request, attempt: attempt + 1)
            }
            
            throw mapError(error)
        }
    }
    
    private func calculateRetryDelay(attempt: Int, isRateLimit: Bool = false) -> TimeInterval {
        if isRateLimit {
            // Rate limit: wait longer
            return baseRetryDelay * pow(2.0, Double(attempt)) + Double.random(in: 0...1)
        } else {
            // Exponential backoff with jitter
            return baseRetryDelay * pow(1.5, Double(attempt - 1)) + Double.random(in: 0...0.5)
        }
    }
    
    private func isRetryableError(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .offline, .timeout, .connectionLost:
                return true
            default:
                return false
            }
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func mapError(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut:
                return .timeout
            case .notConnectedToInternet:
                return .offline
            case .networkConnectionLost:
                return .connectionLost
            default:
                return .unknown(error)
            }
        }
        
        return .unknown(error)
    }
}

// MARK: - API Endpoint Protocol
protocol APIEndpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var body: [String: Any]? { get }
    var fullURL: String { get }
}

extension APIEndpoint {
    var fullURL: String {
        return baseURL + path
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - Network Status
enum NetworkStatus {
    case connected(ConnectionType)
    case disconnected
    
    enum ConnectionType {
        case wifi
        case cellular
        case other
    }
}

// MARK: - Network Errors
enum NetworkError: LocalizedError, Equatable {
    case offline
    case timeout
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int)
    case connectionLost
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .offline:
            return "No internet connection. Please check your network and try again."
        case .timeout:
            return "Request timed out. Please try again."
        case .invalidURL:
            return "Invalid request URL."
        case .invalidResponse:
            return "Invalid server response."
        case .unauthorized:
            return "Authentication required. Please sign in again."
        case .forbidden:
            return "Access denied."
        case .notFound:
            return "Requested resource not found."
        case .rateLimited:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .httpError(let code):
            return "Request failed with status \(code)."
        case .connectionLost:
            return "Connection lost. Please check your network."
        case .unknown(let error):
            return error.localizedDescription
        }
    }
    
    static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        switch (lhs, rhs) {
        case (.offline, .offline),
             (.timeout, .timeout),
             (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.unauthorized, .unauthorized),
             (.forbidden, .forbidden),
             (.notFound, .notFound),
             (.rateLimited, .rateLimited),
             (.connectionLost, .connectionLost):
            return true
        case (.serverError(let lhsCode), .serverError(let rhsCode)):
            return lhsCode == rhsCode
        case (.httpError(let lhsCode), .httpError(let rhsCode)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
} 