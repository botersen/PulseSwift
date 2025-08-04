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
        setupAuthStateBinding()
    }
    
    // MARK: - Public Methods
    func handleAppLaunch() {
        print("🚀 AppFlowViewModel: handleAppLaunch called")
        
        // Check if user is returning and should go directly to camera
        if shouldSkipToCamera() {
            // Pre-load camera for instant startup
            prepareForCameraTransition()
            currentFlow = .capturePulse
            print("🚀 AppFlowViewModel: Returning user - direct to camera")
        } else {
            // New/signed-out user - show splash then auth with polished timing
            print("🚀 AppFlowViewModel: New user - showing splash then auth")
            currentFlow = .splash
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.currentFlow = .authentication
                }
                print("🚀 AppFlowViewModel: Transitioned to authentication screen")
            }
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Smooth transition to camera with pre-loading
        prepareForCameraTransition()
        withAnimation(.easeInOut(duration: 0.5)) {
            currentFlow = .capturePulse
        }
        print("✅ AppFlowViewModel: Onboarding completed")
    }
    
    func handleAuthSuccess(isFirstTime: Bool) {
        // Store auth token for returning user detection
        UserDefaults.standard.set("authenticated_user_token", forKey: "userAuthToken")
        
        // Skip profile setup - go directly to camera for all users
        prepareForCameraTransition()
        withAnimation(.easeInOut(duration: 0.5)) {
            currentFlow = .capturePulse
        }
        
        print("✅ AppFlowViewModel: Auth success - going directly to camera")
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: "userAuthToken")
        currentFlow = .authentication
        print("✅ AppFlowViewModel: User signed out")
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
        currentFlow = .capturePulse
        print("🔧 AppFlowViewModel: Direct to camera (DEBUG)")
    }
    #endif
    
    // MARK: - Returning User Logic
    private func shouldSkipToCamera() -> Bool {
        // Check if user has completed onboarding and is authenticated
        let isAuthenticated = isUserAuthenticated()
        
        #if DEBUG
        // Don't skip if debug mode forces onboarding
        if forceOnboarding {
            return false
        }
        #endif
        
        let shouldSkip = hasCompletedOnboarding && isAuthenticated
        print("🔍 AppFlowViewModel: shouldSkipToCamera - onboarding: \(hasCompletedOnboarding), auth: \(isAuthenticated) -> \(shouldSkip)")
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
        let authToken = UserDefaults.standard.string(forKey: "userAuthToken")
        
        #if DEBUG
        if forceOnboarding {
            hasCompletedOnboarding = false
            isFirstLaunch = true
        }
        #endif
        
        print("✅ AppFlowViewModel: hasCompletedOnboarding = \(hasCompletedOnboarding)")
        print("✅ AppFlowViewModel: authToken exists = \(authToken != nil)")
        print("✅ AppFlowViewModel: isFirstLaunch = \(isFirstLaunch)")
    }

    
    private func setupAuthStateBinding() {
        // This would bind to the auth repository's state changes
        // For now, we'll implement basic state management
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

// MARK: - App Flow States (Streamlined)
enum AppFlow {
    case splash
    case authentication
    case capturePulse     // Main camera screen
    case globe           // Globe screen
    case settings        // Settings screen
    case loading         // Loading states
}

// MARK: - Flow State Helpers (Streamlined)
extension AppFlowViewModel {
    var isLoading: Bool {
        currentFlow == .loading
    }
    
    // MARK: - Navigation Methods  
    func navigateToCamera() {
        currentFlow = .capturePulse
        print("✅ AppFlowViewModel: Navigated to camera")
    }
    
    func navigateToGlobe() {
        currentFlow = .globe
        print("✅ AppFlowViewModel: Navigated to globe")
    }
    
    func navigateToSettings() {
        currentFlow = .settings
        print("✅ AppFlowViewModel: Navigated to settings")
    }
} 