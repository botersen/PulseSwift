//
//  ProfileView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showingSubscriptionSheet = false
    
    var body: some View {
        ZStack {
            PulseTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: PulseTheme.Spacing.xl) {
                // Header
                HStack {
                    Text("Profile")
                        .font(.custom("MonumentExtended-Regular", size: 24))
                        .fontWeight(.bold)
                        .foregroundColor(PulseTheme.Colors.primary)
                    
                    Spacer()
                    
                    Button {
                        Task {
                            await authManager.signOut()
                        }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(PulseTheme.Colors.secondary)
                            .font(.system(size: 20))
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, PulseTheme.Spacing.lg)
                
                // User info
                VStack(spacing: PulseTheme.Spacing.md) {
                    // Avatar placeholder
                    Circle()
                        .fill(PulseTheme.Colors.glassBackground)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 2)
                        )
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(PulseTheme.Colors.secondary)
                                .font(.system(size: 32))
                        )
                    
                    if let user = authManager.currentUser {
                        Text(user.username)
                            .font(PulseTheme.Typography.title3)
                            .foregroundColor(PulseTheme.Colors.primary)
                            .fontWeight(.semibold)
                        
                        // Subscription badge
                        HStack(spacing: PulseTheme.Spacing.xs) {
                            if subscriptionManager.isPremiumActive {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 12))
                                Text("PREMIUM")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.yellow)
                            } else {
                                Text("FREE")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(PulseTheme.Colors.secondary)
                            }
                        }
                        .padding(.horizontal, PulseTheme.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(PulseTheme.Colors.glassBackground)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 1)
                                )
                        )
                    }
                }
                
                // Stats
                HStack(spacing: PulseTheme.Spacing.xl) {
                    StatItemView(title: "Pulses Sent", value: "12")
                    StatItemView(title: "Connections", value: "5")
                    StatItemView(title: "Countries", value: "3")
                }
                .padding(.horizontal, PulseTheme.Spacing.lg)
                
                // Subscription section
                VStack(spacing: PulseTheme.Spacing.lg) {
                    if !subscriptionManager.isPremiumActive {
                        VStack(spacing: PulseTheme.Spacing.md) {
                            Text("Upgrade to Premium")
                                .font(PulseTheme.Typography.title3)
                                .foregroundColor(PulseTheme.Colors.primary)
                                .fontWeight(.semibold)
                            
                            Text("Connect globally, unlimited pulses,\nenhanced translations & more")
                                .font(PulseTheme.Typography.bodySmall)
                                .foregroundColor(PulseTheme.Colors.secondary)
                                .multilineTextAlignment(.center)
                            
                            GlassButton("Upgrade for $3.99/month") {
                                showingSubscriptionSheet = true
                            }
                        }
                        .padding(PulseTheme.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.lg)
                                .fill(PulseTheme.Colors.glassBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.lg)
                                        .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, PulseTheme.Spacing.lg)
                    }
                    
                    // Settings options
                    VStack(spacing: PulseTheme.Spacing.sm) {
                        SettingsRowView(title: "Notifications", icon: "bell") { }
                        SettingsRowView(title: "Privacy", icon: "lock") { }
                        SettingsRowView(title: "Support", icon: "questionmark.circle") { }
                        SettingsRowView(title: "Terms of Service", icon: "doc.text") { }
                    }
                    .padding(.horizontal, PulseTheme.Spacing.lg)
                }
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingSubscriptionSheet) {
            SubscriptionView()
        }
    }
}

struct StatItemView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: PulseTheme.Spacing.xs) {
            Text(value)
                .font(PulseTheme.Typography.title2)
                .foregroundColor(PulseTheme.Colors.primary)
                .fontWeight(.bold)
            
            Text(title)
                .font(PulseTheme.Typography.caption)
                .foregroundColor(PulseTheme.Colors.secondary)
        }
    }
}

struct SettingsRowView: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: PulseTheme.Spacing.md) {
                Image(systemName: icon)
                    .foregroundColor(PulseTheme.Colors.secondary)
                    .font(.system(size: 16))
                    .frame(width: 20)
                
                Text(title)
                    .font(PulseTheme.Typography.body)
                    .foregroundColor(PulseTheme.Colors.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(PulseTheme.Colors.secondary)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, PulseTheme.Spacing.md)
            .padding(.vertical, PulseTheme.Spacing.md + 2)
            .background(
                RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.md)
                    .fill(PulseTheme.Colors.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.md)
                            .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 1)
                    )
            )
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthenticationManager())
        .environmentObject(SubscriptionManager())
} 