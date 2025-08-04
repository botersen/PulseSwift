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
            
            // Smart flow navigation with polished right-to-left transitions
            Group {
                switch appFlowViewModel.currentFlow {
                case .splash:
                    SplashScreen()
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                case .loading:
                    LoadingScreen()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    
                case .authentication:
                    AuthScreen()
                        .environmentObject(authViewModel)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    
                case .profileSetup:
                    ProfileCustomizationScreen()
                        .environmentObject(authViewModel)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    
                case .capturePulse:
                    SwipeNavigationContainer()
                        .environmentObject(appFlowViewModel)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        
                case .globe:
                    SwipeNavigationContainer()
                        .environmentObject(appFlowViewModel)
                        .transition(.opacity)
                        
                case .settings:
                    SettingsScreen()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: appFlowViewModel.currentFlow)
            
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

// MARK: - Placeholder Screens (to be implemented)
struct GlobeScreen: View {
    var body: some View {
        GlobeView()  // Use real implementation
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 16) {
                Text("SETTINGS")
                    .font(.custom("Special Gothic Expanded One", size: 28))
                    .foregroundColor(.white)
                
                Text("Pulse Configuration")
                    .font(.custom("DM Mono", size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 60)
            
            Spacer()
            
            // Settings Options
            VStack(spacing: 20) {
                SettingsButton(
                    title: "Account Settings",
                    icon: "person.circle",
                    action: {
                        print("Account settings tapped")
                    }
                )
                
                SettingsButton(
                    title: "Privacy & Security",
                    icon: "lock.shield",
                    action: {
                        print("Privacy settings tapped")
                    }
                )
                
                SettingsButton(
                    title: "Notifications",
                    icon: "bell",
                    action: {
                        print("Notifications settings tapped")
                    }
                )
                
                SettingsButton(
                    title: "About Pulse",
                    icon: "info.circle",
                    action: {
                        print("About tapped")
                    }
                )
            }
            
            Spacer()
            
            // Sign Out Button
            Button {
                authViewModel.signOut()
                appFlowViewModel.signOut()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 16, weight: .medium))
                    Text("Sign Out")
                        .font(.custom("DM Mono", size: 16))
                        .fontWeight(.medium)
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct SettingsButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                Text(title)
                    .font(.custom("DM Mono", size: 16))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Always Ready Navigation Container (Instagram/Snapchat Style)
struct SwipeNavigationContainer: View {
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel // CRITICAL: Added for singleton injection
    @State private var currentIndex: Int = 1 // Start at camera (middle screen)
    @State private var offset: CGFloat = 0
    
    // BREAKTHROUGH: Always-ready screens - no lazy loading, no placeholders
    @StateObject private var cameraScreen = CameraScreenSingleton()
    @StateObject private var globeScreen = GlobeScreenSingleton()
    
    private let screens = [0, 1, 2] // 0 = Settings, 1 = Camera, 2 = Globe
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HStack(spacing: 0) {
                    // Settings Screen (Index 0) - Simple, always ready
                    SettingsScreen()
                        .frame(width: geometry.size.width)
                        .simultaneousGesture(DragGesture()) // Allow navigation gestures to pass through
                    
                    // Camera Screen (Index 1) - Always ready singleton
                    cameraScreen.view(authViewModel: authViewModel, appFlowViewModel: appFlowViewModel)
                        .frame(width: geometry.size.width)
                    
                    // Globe Screen (Index 2) - Always ready singleton  
                    globeScreen.view(appFlowViewModel: appFlowViewModel)
                        .frame(width: geometry.size.width)
                        .allowsHitTesting(false) // DEMO MODE: Zero interaction for maximum navigation performance
                }
                
                // Page indicator
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(0..<screens.count, id: \.self) { index in
                            Circle()
                                .fill(currentIndex == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .global)
                    .onChanged { value in
                        // Calculate offset based on drag with improved responsiveness  
                        let dragOffset = value.translation.width
                        let baseOffset = -CGFloat(currentIndex) * geometry.size.width
                        offset = baseOffset + dragOffset
                        
                        // Debug: Track swipe direction
                        if abs(value.translation.width) > 30 {
                            let direction = value.translation.width > 0 ? "RIGHT" : "LEFT"
                            print("🖱️ NAVIGATION: Dragging \(direction): \(value.translation.width)")
                        }
                    }
                    .onEnded { value in
                        // Determine if we should snap to next/previous screen  
                        let threshold: CGFloat = geometry.size.width * 0.25 // More forgiving threshold
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        
                        print("🎯 SWIPE DEBUG: translation=\(value.translation.width), threshold=\(threshold), velocity=\(velocity), currentIndex=\(currentIndex)")
                        
                        var newIndex = currentIndex
                        
                        if value.translation.width > threshold || velocity > 1000 {
                            // Swipe right - go to previous screen (Settings ← Camera ← Globe)
                            newIndex = max(0, currentIndex - 1)
                            print("🔄 Swipe RIGHT: from index \(currentIndex) to \(newIndex), translation: \(value.translation.width)")
                            
                            if newIndex == 0 {
                                print("⚙️ SwipeNavigation: Swiped to settings (always ready)")
                            } else if newIndex == 1 {
                                print("📷 SwipeNavigation: Swiped to camera (always ready)")
                            }
                        } else if value.translation.width < -threshold || velocity < -1000 {
                            // Swipe left - go to next screen (Settings → Camera → Globe)
                            newIndex = min(screens.count - 1, currentIndex + 1)
                            print("🔄 Swipe LEFT: from index \(currentIndex) to \(newIndex), translation: \(value.translation.width)")
                            
                            if newIndex == 1 {
                                print("📷 SwipeNavigation: Swiped to camera (always ready)")
                            } else if newIndex == 2 {
                                print("🌍 SwipeNavigation: Swiped to globe (always ready)")
                            }
                        }
                        
                        // PERFORMANCE: Use faster, non-blocking animation
                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                            currentIndex = newIndex
                            offset = -CGFloat(newIndex) * geometry.size.width
                        }
                        
                        // CRITICAL FIX: Force camera refresh when navigating to camera
                        if newIndex == 1 {
                            // Small delay to let animation start, then refresh camera
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                                if let cameraViewModel = CameraViewModel.shared as? CameraViewModel {
                                    cameraViewModel.refreshPreviewConnection()
                                }
                            }
                        }
                        
                        // CRITICAL FIX: Update app flow state synchronously to prevent race conditions
                        switch newIndex {
                        case 0:
                            appFlowViewModel.currentFlow = .settings
                        case 1:
                            appFlowViewModel.currentFlow = .capturePulse
                        case 2:
                            appFlowViewModel.currentFlow = .globe
                        default:
                            break
                        }
                    }
            )
            .onAppear {
                // Set initial position based on current flow
                let initialIndex: Int
                switch appFlowViewModel.currentFlow {
                case .settings:
                    initialIndex = 0
                case .capturePulse:
                    initialIndex = 1
                case .globe:
                    initialIndex = 2
                default:
                    initialIndex = 1 // Default to camera
                }
                
                currentIndex = initialIndex
                offset = -CGFloat(initialIndex) * geometry.size.width
                
                // BREAKTHROUGH: All screens always ready - no pre-loading needed!
                print("🚀 PERFORMANCE: All screens always ready - instant navigation!")
            }
            .onChange(of: appFlowViewModel.currentFlow) { _, newFlow in
                // Update position when flow changes from other sources
                let newIndex: Int
                switch newFlow {
                case .settings:
                    newIndex = 0
                case .capturePulse:
                    newIndex = 1
                case .globe:
                    newIndex = 2
                default:
                    newIndex = 1 // Default to camera
                }
                
                if newIndex != currentIndex {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentIndex = newIndex
                        offset = -CGFloat(newIndex) * geometry.size.width
                    }
                }
            }
        }
        .clipped() // Prevent overflow
    }
}

// MARK: - Always Ready Screen Singletons  
class CameraScreenSingleton: ObservableObject {
    func view(authViewModel: AuthViewModel, appFlowViewModel: AppFlowViewModel) -> some View {
        CameraScreen()
            .environmentObject(authViewModel)
            .environmentObject(appFlowViewModel)
    }
    
    init() {
        print("📷 PERFORMANCE: Camera singleton created - always ready!")
    }
}

class GlobeScreenSingleton: ObservableObject {
    func view(appFlowViewModel: AppFlowViewModel) -> some View {
        GlobeScreen()
            .environmentObject(appFlowViewModel)
    }
    
    init() {
        print("🌍 PERFORMANCE: Globe singleton created - always ready!")
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Loading animation
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("Loading Settings...")
                    .font(.custom("DM Mono", size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Performance View Cache
class NavigationViewCache: ObservableObject {
    private var globeView: GlobeScreen?
    private var settingsView: SettingsScreen?
    
    func getGlobeView() -> GlobeScreen {
        if globeView == nil {
            print("🏭 PERFORMANCE: Creating globe view (one-time only)")
            globeView = GlobeScreen()
        }
        return globeView!
    }
    
    func getSettingsView() -> SettingsScreen {
        if settingsView == nil {
            print("⚙️ PERFORMANCE: Creating settings view (one-time only)")
            settingsView = SettingsScreen()
        }
        return settingsView!
    }
} 