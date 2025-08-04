import SwiftUI

// MARK: - Optimized Settings Screen
struct OptimizedSettingsScreen: View {
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("SETTINGS")
                        .font(.custom("Special Gothic Expanded One", size: 28))
                        .foregroundColor(.white)
                    
                    Text("Pulse Configuration")
                        .font(.custom("DM Mono", size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 80)
                .padding(.bottom, 40)
                
                // Settings Options
                ScrollView {
                    VStack(spacing: 12) {
                        SettingsRow(
                            icon: "person.circle",
                            title: "Account Settings",
                            action: { print("Account settings") }
                        )
                        
                        SettingsRow(
                            icon: "lock.shield",
                            title: "Privacy & Security",
                            action: { print("Privacy settings") }
                        )
                        
                        SettingsRow(
                            icon: "bell",
                            title: "Notifications",
                            action: { print("Notifications") }
                        )
                        
                        SettingsRow(
                            icon: "info.circle",
                            title: "About Pulse",
                            action: { print("About") }
                        )
                    }
                    .padding(.horizontal, 20)
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
                .padding(.bottom, 60)
            }
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}