//
//  AppRootView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var oneSignalManager: OneSignalManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var cameraManager: CameraManager
    @EnvironmentObject private var matchingManager: MatchingManager

    
    var body: some View {
        ZStack {
            // Always black background
            PulseTheme.Colors.background
                .ignoresSafeArea()
            

            
            // Screen content
            Group {
                switch appState.currentScreen {
                case .launch:
                    LaunchView()
                        .transition(.opacity)
                        
                case .welcome:
                    WelcomeView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                        
                case .authentication:
                    AuthenticationView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                        
                case .main:
                    MainTabView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                }
            }
            .animation(PulseTheme.Animation.medium, value: appState.currentScreen)
        }
        .onAppear {
            handleAppLaunch()
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // User logged in - request location permission
                locationManager.requestLocationPermission()
                appState.navigateTo(.main)
            } else if appState.currentScreen == .main {
                // User logged out - stop location services
                locationManager.stopLocationServices()
                appState.navigateTo(.welcome)
            }
        }
        .onChange(of: oneSignalManager.playerId) { _, playerId in
            // Update Supabase when OneSignal player ID changes
            if let playerId = playerId,
               let user = authManager.currentUser {
                Task {
                    do {
                        try await SupabaseService.shared.updateUserOneSignalPlayerId(
                            userId: user.id,
                            playerId: playerId
                        )
                    } catch {
                        print("❌ Failed to sync OneSignal player ID: \(error)")
                    }
                }
            }
        }

    }
    
    private func handleAppLaunch() {
        // Show launch screen for 2-3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if authManager.isAuthenticated {
                appState.navigateTo(.main)
            } else if appState.hasCompletedOnboarding {
                appState.navigateTo(.authentication)
            } else {
                appState.navigateTo(.welcome)
            }
        }
    }
} 