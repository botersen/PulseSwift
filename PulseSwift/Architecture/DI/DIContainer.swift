import Foundation

// MARK: - Dependency Injection Container
final class DIContainer {
    static let shared = DIContainer()
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    
    private init() {}
    
    // MARK: - Registration
    func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        services[key] = instance
    }
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    // MARK: - Resolution
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        // Check for existing instance
        if let service = services[key] as? T {
            return service
        }
        
        // Check for factory
        if let factory = factories[key] {
            let instance = factory() as! T
            services[key] = instance
            return instance
        }
        
        fatalError("Service \(key) not registered")
    }
    
    // MARK: - Setup
    func setupServices() {
        // Register core foundation services
        register(NetworkService.self, factory: { NetworkService() })
        register(KeychainService.self, factory: { KeychainService() })
        register(SupabaseService.self, instance: SupabaseService.shared)
        register(LocationManager.self, factory: { LocationManager() })
        register(MediaProcessor.self, factory: { MediaProcessor() })
        
        // Register security services (temporarily commented out due to dependency issues)
        // register(TokenManager.self, factory: {
        //     TokenManager(
        //         keychainService: DIContainer.shared.resolve(KeychainService.self),
        //         networkService: DIContainer.shared.resolve(NetworkService.self)
        //     )
        // })
        
        // Register repositories
        register(AuthRepositoryProtocol.self, factory: { AuthRepository() })
        register(CameraRepositoryProtocol.self, factory: { CameraRepository() })
        register(GlobeRepositoryProtocol.self, factory: { GlobeRepository() })
        
        // Register use cases
        register(AuthUseCasesProtocol.self, factory: {
            AuthUseCases(authRepository: DIContainer.shared.resolve(AuthRepositoryProtocol.self))
        })
        
        register(CameraUseCasesProtocol.self, factory: {
            CameraUseCases(cameraRepository: DIContainer.shared.resolve(CameraRepositoryProtocol.self))
        })
        
        // Note: ViewModels are @MainActor and created directly in UI layer
        
        // Initialize configuration validation
        do {
            try AppConfiguration.current.validate()
        } catch {
            print("❌ DI Container: Configuration validation failed - \(error)")
        }
        
        print("✅ DI Container: All foundation services registered")
        print("🎯 Environment: \(AppConfiguration.current.environment)")
        print("🔧 Features: \(AppConfiguration.current.features.debugDescription)")
    }
}

// MARK: - Property Wrapper for Injection
@propertyWrapper
struct Injected<T> {
    let wrappedValue: T
    
    init() {
        self.wrappedValue = DIContainer.shared.resolve(T.self)
    }
} 