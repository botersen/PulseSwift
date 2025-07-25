//
//  AppState.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .launch
    @Published var isFirstLaunch: Bool = true
    @Published var hasCompletedOnboarding: Bool = false
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadAppState()
    }
    
    func navigateTo(_ screen: AppScreen) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentScreen = screen
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: "hasCompletedOnboarding")
    }
    
    private func loadAppState() {
        hasCompletedOnboarding = userDefaults.bool(forKey: "hasCompletedOnboarding")
        isFirstLaunch = !userDefaults.bool(forKey: "hasLaunchedBefore")
        
        if isFirstLaunch {
            userDefaults.set(true, forKey: "hasLaunchedBefore")
        }
    }
}

enum AppScreen {
    case launch
    case welcome
    case authentication
    case main
} 