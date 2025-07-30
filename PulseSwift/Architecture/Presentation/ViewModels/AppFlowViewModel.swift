import Foundation
import Combine
import SwiftUI
import AVFoundation // Added for AVCaptureDevice
import CoreLocation // Added for CLLocationManager
import UserNotifications // Added for UNUserNotificationCenter

// MARK: - App Flow State Management
@MainActor
final class AppFlowViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentFlow: AppFlow = .splash
    @Published var isFirstLaunch: Bool = true
    @Published var hasCompletedOnboarding: Bool = false
    @Published var hasCompletedProfileSetup: Bool = false
    
    // MARK: - Dependencies
    @Injected private var authUseCases: AuthUseCasesProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Developer Tools (for constant rebuilding)
    #if DEBUG
    @Published var debugMode: Bool = false
    @Published var forceOnboarding: Bool = false
    #endif
    
    init() {
        checkAppLaunchState()
        checkProfileSetupState()
        setupAuthStateBinding()
    }
    
    // MARK: - Public Methods
    func handleAppLaunch() {
        // Check if user is returning and should go directly to camera
        if shouldSkipToCamera() {
            // Pre-load camera for instant startup
            prepareForCameraTransition()
            currentFlow = .capturePulse
            print("🚀 AppFlowViewModel: Returning user - direct to camera")
        } else {
            // New/signed-out user - show splash then auth
            currentFlow = .splash
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.currentFlow = .authentication
            }
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        currentFlow = .capturePulse
        print("✅ AppFlowViewModel: Onboarding completed")
    }
    
    func handleAuthSuccess(isFirstTime: Bool) {
        // Store auth token for returning user detection
        UserDefaults.standard.set("authenticated_user_token", forKey: "userAuthToken")
        
        if isFirstTime || !hasCompletedProfileSetup {
            currentFlow = .profileSetup
        } else {
            // Returning user with completed setup - pre-load camera
            prepareForCameraTransition()
            currentFlow = .capturePulse
        }
        
        print("✅ AppFlowViewModel: Auth success - firstTime: \(isFirstTime), profileSetup: \(hasCompletedProfileSetup)")
    }

    func completeProfileSetup() {
        hasCompletedProfileSetup = true
        UserDefaults.standard.set(true, forKey: "hasCompletedProfileSetup")
        
        // Pre-load camera for instant startup
        prepareForCameraTransition()
        
        currentFlow = .capturePulse
    }

    func signOut() {
        hasCompletedProfileSetup = false
        UserDefaults.standard.removeObject(forKey: "hasCompletedProfileSetup")
        UserDefaults.standard.removeObject(forKey: "userAuthToken")
        currentFlow = .authentication
        print("✅ AppFlowViewModel: User signed out, reset to first launch")
    }
    
    #if DEBUG
    func resetToFirstLaunch() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = false
        isFirstLaunch = true
        currentFlow = .authentication
        print("🔧 AppFlowViewModel: Reset to first launch (DEBUG)")
    }
    
    func goDirectlyToCamera() {
        currentFlow = .camera
        print("🔧 AppFlowViewModel: Direct to camera (DEBUG)")
    }
    #endif
    
    // MARK: - Returning User Logic
    private func shouldSkipToCamera() -> Bool {
        // Check if user has completed onboarding AND profile setup AND is authenticated
        let hasCompletedBoth = hasCompletedOnboarding && hasCompletedProfileSetup
        let isAuthenticated = isUserAuthenticated()
        
        #if DEBUG
        // Don't skip if debug mode forces onboarding
        if forceOnboarding {
            return false
        }
        #endif
        
        let shouldSkip = hasCompletedBoth && isAuthenticated
        print("🔍 AppFlowViewModel: shouldSkipToCamera - onboarding: \(hasCompletedOnboarding), profile: \(hasCompletedProfileSetup), auth: \(isAuthenticated) -> \(shouldSkip)")
        return shouldSkip
    }
    
    private func isUserAuthenticated() -> Bool {
        // Check if user has valid auth session
        // This would typically check keychain/UserDefaults for auth tokens
        let hasAuthToken = UserDefaults.standard.string(forKey: "userAuthToken") != nil
        return hasAuthToken
    }
    
    // MARK: - Camera Preparation
    private func prepareForCameraTransition() {
        print("🚀 AppFlowViewModel: Pre-loading camera for instant startup")
        // Trigger camera preparation in background while user is on profile screen
        // This way when they click "Skip for now", camera is already ready
        NotificationCenter.default.post(name: .prepareCameraForInstantStartup, object: nil)
    }
    
    // MARK: - Private Methods
    private func checkAppLaunchState() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        #if DEBUG
        if forceOnboarding {
            hasCompletedOnboarding = false
            isFirstLaunch = true
        }
        #endif
        
        print("✅ AppFlowViewModel: hasCompletedOnboarding = \(hasCompletedOnboarding)")
    }

    private func checkProfileSetupState() {
        hasCompletedProfileSetup = UserDefaults.standard.bool(forKey: "hasCompletedProfileSetup")
    }
    
    private func setupAuthStateBinding() {
        // This would bind to the auth repository's state changes
        // For now, we'll implement basic state management
    }
    
    private func determineInitialFlow() {
        Task {
            let isAuthenticated = await authUseCases.checkAuthenticationStatus()
            
            await MainActor.run {
                if case .authenticated = isAuthenticated {
                    // User is signed in
                    if self.hasCompletedOnboarding {
                        // Returning user → Direct to main app
                        self.currentFlow = .mainApp
                        print("✅ AppFlowViewModel: Returning user → Camera")
                    } else {
                        // Signed in but hasn't completed onboarding → Profile customization
                        self.currentFlow = .profileCustomization
                        print("✅ AppFlowViewModel: Authenticated but incomplete onboarding → Profile")
                    }
                } else {
                    // User not signed in → Authentication
                    self.currentFlow = .authentication
                    print("✅ AppFlowViewModel: Not authenticated → Auth")
                }
            }
        }
    }

    func requestAllPermissionsIfNeeded() {
        // Camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if cameraStatus == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }
        // Location
        let locationStatus = CLLocationManager().authorizationStatus
        if locationStatus == .notDetermined {
            let locationManager = CLLocationManager()
            locationManager.requestWhenInUseAuthorization()
        }
        // Notifications
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            }
        }
    }
}

// MARK: - App Flow States
enum AppFlow {
    case splash
    case authentication
    case profileCustomization
    case camera
    case mainApp // New state for camera+globe tabbed interface
    case profileSetup
    case capturePulse
    case globe
    case settings
    case loading // (optional, for background tasks)
}

// MARK: - Flow State Helpers
extension AppFlowViewModel {
    var shouldShowAuthFlow: Bool {
        currentFlow == .authentication
    }
    
    var shouldShowProfileCustomization: Bool {
        currentFlow == .profileCustomization
    }
    
    var shouldShowCamera: Bool {
        currentFlow == .camera
    }
    
    var shouldShowMainApp: Bool {
        currentFlow == .mainApp
    }
    
    var isLoading: Bool {
        currentFlow == .loading
    }
    
    // MARK: - Navigation Methods
    func navigateToMainApp() {
        currentFlow = .mainApp
        print("✅ AppFlowViewModel: Navigated to main app")
    }
    
    func navigateToGlobe() {
        // For now, globe is part of mainApp flow
        // This could be expanded if globe becomes standalone
        if currentFlow != .mainApp {
            navigateToMainApp()
        }
    }
} 