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
                    SwipeNavigationContainer()
                        .transition(.opacity)
                        
                case .globe:
                    SwipeNavigationContainer()
                        .transition(.opacity)
                        
                case .settings:
                    SettingsScreen()
                        .transition(.opacity)
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

// MARK: - Swipe Navigation Container
struct SwipeNavigationContainer: View {
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    @State private var currentIndex: Int = 1 // Start at camera (middle screen)
    @State private var offset: CGFloat = 0
    @State private var globeLoaded: Bool = false // Lazy loading for globe
    @State private var settingsLoaded: Bool = false // Lazy loading for settings
    
    private let screens = [0, 1, 2] // 0 = Settings, 1 = Camera, 2 = Globe
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HStack(spacing: 0) {
                    // Settings Screen (Index 0) - Lazy loaded
                    if settingsLoaded {
                        SettingsScreen()
                            .frame(width: geometry.size.width)
                    } else {
                        SettingsPlaceholderView()
                            .frame(width: geometry.size.width)
                    }
                    
                    // Camera Screen (Index 1) - Always loaded for instant startup
                    CameraScreen()
                        .frame(width: geometry.size.width)
                    
                    // Globe Screen (Index 2) - Lazy loaded for performance  
                    if globeLoaded {
                        GlobeScreen()
                            .frame(width: geometry.size.width)
                    } else {
                        // Placeholder while globe loads
                        GlobePlaceholderView()
                            .frame(width: geometry.size.width)
                    }
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
                DragGesture()
                    .onChanged { value in
                        // Calculate offset based on drag
                        let dragOffset = value.translation.width
                        let baseOffset = -CGFloat(currentIndex) * geometry.size.width
                        offset = baseOffset + dragOffset
                    }
                    .onEnded { value in
                        // Determine if we should snap to next/previous screen
                        let threshold: CGFloat = geometry.size.width * 0.25
                        let velocity = value.predictedEndTranslation.width - value.translation.width
                        
                        var newIndex = currentIndex
                        
                        if value.translation.width > threshold || velocity > 1000 {
                            // Swipe right - go to previous screen
                            newIndex = max(0, currentIndex - 1)
                            
                            // Ensure settings is loaded when swiping to it
                            if newIndex == 0 && !settingsLoaded {
                                settingsLoaded = true
                                print("⚙️ SwipeNavigation: Loading settings due to swipe")
                            }
                        } else if value.translation.width < -threshold || velocity < -1000 {
                            // Swipe left - go to next screen
                            newIndex = min(screens.count - 1, currentIndex + 1)
                            
                            // Ensure globe is loaded when swiping to it
                            if newIndex == 2 && !globeLoaded {
                                globeLoaded = true
                                print("🌍 SwipeNavigation: Loading globe due to swipe")
                            }
                        }
                        
                        // Animate to the new position
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentIndex = newIndex
                            offset = -CGFloat(newIndex) * geometry.size.width
                            
                            // Update app flow state to match current screen
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
                
                // Pre-load screens based on starting position
                if initialIndex == 1 { // Starting on camera
                    // Pre-load globe after 1 second for smooth swiping
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        globeLoaded = true
                        print("🌍 SwipeNavigation: Globe pre-loaded for smooth swiping")
                    }
                    // Pre-load settings after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        settingsLoaded = true
                        print("⚙️ SwipeNavigation: Settings pre-loaded for smooth swiping")
                    }
                } else if initialIndex == 2 { // Starting on globe
                    globeLoaded = true
                } else if initialIndex == 0 { // Starting on settings
                    settingsLoaded = true
                }
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

// MARK: - Placeholder Views for Lazy Loading
struct GlobePlaceholderView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Loading animation
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                
                Text("Loading Globe...")
                    .font(.custom("DM Mono", size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
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