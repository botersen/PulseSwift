import SwiftUI
import GoogleSignIn

// MARK: - Clean Architecture App Entry Point
// Note: @main removed to avoid conflict with PulseSwiftApp.swift
struct PulseApp: App {
    
    init() {
        setupDependencies()
        setupAppConfigurations()
    }
    
    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .onOpenURL { url in
                    // Handle Google Sign In URL callbacks
                    GIDSignIn.sharedInstance.handle(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    handleAppBecameActive()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    handleAppWillResignActive()
                }
        }
    }
    
    // MARK: - Setup Methods
    private func setupDependencies() {
        // Initialize DI Container with all services
        DIContainer.shared.setupServices()
        print("✅ PulseApp: Dependency injection configured")
    }
    
    private func setupAppConfigurations() {
        // Register custom fonts
        registerCustomFonts()
        
        // Setup OneSignal
        setupNotifications()
        
        print("✅ PulseApp: App configurations complete")
    }
    
    private func registerCustomFonts() {
        // Font registration happens automatically via Info.plist
        // But we can verify they're available
        if UIFont(name: "Special Gothic Expanded One", size: 16) != nil {
            print("✅ PulseApp: Special Gothic font available")
        } else {
            print("⚠️ PulseApp: Special Gothic font not available")
        }
        
        if UIFont(name: "DM Mono", size: 16) != nil {
            print("✅ PulseApp: DM Mono font available")
        } else {
            print("⚠️ PulseApp: DM Mono font not available")
        }
    }
    
    private func setupNotifications() {
        // OneSignal setup would happen here
        print("✅ PulseApp: Notification setup complete")
    }
    
    private func handleAppBecameActive() {
        print("📱 PulseApp: App became active")
        // Notify camera to resume if needed
        NotificationCenter.default.post(name: .appBecameActive, object: nil)
    }
    
    private func handleAppWillResignActive() {
        print("📱 PulseApp: App will resign active")
        // Notify camera to prepare for background
        NotificationCenter.default.post(name: .appWillResignActive, object: nil)
    }
}

// MARK: - App Coordinator (Smart Flow Navigation)
struct AppCoordinator: View {
    @StateObject private var appFlowViewModel = AppFlowViewModel()
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some View {
        ZStack {
            // App background
            Color.black
                .ignoresSafeArea()
            
            // Smart flow navigation
            Group {
                switch appFlowViewModel.currentFlow {
                case .splash:
                    SplashScreen()
                case .loading:
                    LoadingScreen()
                        .transition(.opacity)
                    
                case .authentication:
                    AuthScreen()
                        .transition(.opacity)
                    
                case .profileSetup:
                    ProfileCustomizationScreen()
                        .transition(.slide)
                    
                case .capturePulse:
                    CameraScreen()
                        .transition(.opacity)
                        
                case .globe:
                    GlobeScreen()
                        .transition(.opacity)
                        
                case .settings:
                    SettingsScreen()
                        .transition(.opacity)
                default:
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appFlowViewModel.currentFlow)
            
            // Developer tools overlay (DEBUG only)
            #if DEBUG
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        appFlowViewModel.debugMode.toggle()
                    } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                            )
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 50)
                }
                
                Spacer()
            }
            
            if appFlowViewModel.debugMode {
                DeveloperToolsOverlay()
            }
            #endif
        }
        .environmentObject(authViewModel)
        .environmentObject(appFlowViewModel)
        .onAppear {
            appFlowViewModel.handleAppLaunch()
        }
        .onChange(of: authViewModel.isAuthenticated) { _, isAuthenticated in
            if !isAuthenticated {
                appFlowViewModel.signOut()
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let appBecameActive = Notification.Name("appBecameActive")
    static let appWillResignActive = Notification.Name("appWillResignActive")
} 

struct SplashScreen: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                Text("PULSE")
                    .font(.custom("Special Gothic Expanded One", size: calculateFontSize(for: geometry.size.width)))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18) // ~quarter inch padding on each side
            }
        }
    }
    private func calculateFontSize(for screenWidth: CGFloat) -> CGFloat {
        // Fill width minus padding (36 points = ~half inch total)
        // Optimized for Special Gothic Expanded One character width
        let availableWidth = screenWidth - 36
        return availableWidth * 0.25 // Adjust multiplier for best fit
    }
} 

struct ProfileSetupScreen: View {
    var body: some View {
        Text("Profile Setup Screen")
            .foregroundColor(.white)
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
}

struct CapturePulseScreen: View {
    var body: some View {
        Text("Capture Pulse Screen")
            .foregroundColor(.white)
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
}

struct GlobeScreen: View {
    var body: some View {
        Text("Globe Screen")
            .foregroundColor(.white)
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
}

struct SettingsScreen: View {
    var body: some View {
        Text("Settings Screen")
            .foregroundColor(.white)
            .font(.largeTitle)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }
} 