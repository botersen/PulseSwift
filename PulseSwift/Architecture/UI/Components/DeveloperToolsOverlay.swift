import SwiftUI

// MARK: - Developer Tools Overlay (DEBUG Only)
#if DEBUG
struct DeveloperToolsOverlay: View {
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(spacing: 0) {
                    // Toggle button
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "xmark.circle.fill" : "hammer.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 44, height: 44)
                            )
                    }
                    
                    // Tools panel
                    if isExpanded {
                        DeveloperToolsPanel()
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 100)
        }
    }
}

struct DeveloperToolsPanel: View {
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            Text("DEV TOOLS")
                .font(.custom("DM Mono", size: 12))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.top, 12)
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Flow Controls
            VStack(spacing: 8) {
                Text("FLOW CONTROL")
                    .font(.custom("DM Mono", size: 10))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 8) {
                    DevButton(title: "Auth") {
                        appFlowViewModel.currentFlow = .authentication
                    }
                    
                    
                    DevButton(title: "Camera") {
                        appFlowViewModel.goDirectlyToCamera()
                    }
                }
                
                DevButton(title: "Reset First Launch") {
                    appFlowViewModel.resetToFirstLaunch()
                }
                DevButton(title: "Reset Onboarding & Permissions") {
                    UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                    appFlowViewModel.signOut()
                    // Note: Permissions must be reset via Settings or by deleting the app.
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Auth Controls
            VStack(spacing: 8) {
                Text("AUTH CONTROL")
                    .font(.custom("DM Mono", size: 10))
                    .foregroundColor(.white.opacity(0.7))
                
                DevButton(title: "Sign Out") {
                    authViewModel.signOut()
                }
                
                DevButton(title: "Clear Auth Cache") {
                    UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
                    // Clear keychain if needed
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // Current State Info
            VStack(spacing: 4) {
                Text("CURRENT STATE")
                    .font(.custom("DM Mono", size: 10))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("Flow: \(appFlowViewModel.currentFlow.debugDescription)")
                    .font(.custom("DM Mono", size: 9))
                    .foregroundColor(.green)
                
                Text("Auth: \(authViewModel.isAuthenticated ? "✅" : "❌")")
                    .font(.custom("DM Mono", size: 9))
                    .foregroundColor(.green)
                
                Text("Onboarding: \(appFlowViewModel.hasCompletedOnboarding ? "✅" : "❌")")
                    .font(.custom("DM Mono", size: 9))
                    .foregroundColor(.green)
            }
            
            Spacer(minLength: 12)
        }
        .padding(.horizontal, 16)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 2)
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10)
    }
}

struct DevButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("DM Mono", size: 10))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.7))
                )
        }
    }
}

// MARK: - AppFlow Debug Extension
extension AppFlow {
    var debugDescription: String {
        switch self {
        case .splash: return "Splash"
        case .loading: return "Loading"
        case .authentication: return "Auth"
        case .capturePulse: return "Camera"
        case .globe: return "Globe"
        case .settings: return "Settings"
        }
    }
}

#endif 