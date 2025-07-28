//
//  SubscriptionView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                PulseTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: PulseTheme.Spacing.xl) {
                        // Header
                        VStack(spacing: PulseTheme.Spacing.md) {
                            Text("Upgrade to Premium")
                                .font(.custom("Special Gothic Expanded One", size: 28))
                                .fontWeight(.bold)
                                .foregroundColor(PulseTheme.Colors.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("Connect with the world")
                                .font(PulseTheme.Typography.body)
                                .foregroundColor(PulseTheme.Colors.secondary)
                        }
                        .padding(.top, PulseTheme.Spacing.lg)
                        
                        // Features
                        VStack(spacing: PulseTheme.Spacing.md) {
                            ForEach(SubscriptionFeature.allFeatures, id: \.title) { feature in
                                FeatureRowView(feature: feature)
                            }
                        }
                        .padding(.horizontal, PulseTheme.Spacing.lg)
                        
                        // Pricing
                        VStack(spacing: PulseTheme.Spacing.lg) {
                            VStack(spacing: PulseTheme.Spacing.sm) {
                                Text(subscriptionManager.formattedPremiumPrice)
                                    .font(.custom("Special Gothic Expanded One", size: 32))
                                    .fontWeight(.bold)
                                    .foregroundColor(PulseTheme.Colors.primary)
                                
                                Text("per month")
                                    .font(PulseTheme.Typography.bodySmall)
                                    .foregroundColor(PulseTheme.Colors.secondary)
                            }
                            
                            GlassButton(
                                "START FREE TRIAL",
                                isLoading: subscriptionManager.isLoading
                            ) {
                                Task {
                                    if let product = subscriptionManager.premiumProduct {
                                        await subscriptionManager.purchase(product)
                                        if subscriptionManager.isPremiumActive {
                                            dismiss()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, PulseTheme.Spacing.lg)
                            
                            Button("Restore Purchases") {
                                Task {
                                    await subscriptionManager.restorePurchases()
                                }
                            }
                            .font(PulseTheme.Typography.bodySmall)
                            .foregroundColor(PulseTheme.Colors.secondary)
                            
                            // Terms
                            Text("7-day free trial, then $3.99/month. Cancel anytime.")
                                .font(PulseTheme.Typography.caption)
                                .foregroundColor(PulseTheme.Colors.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, PulseTheme.Spacing.lg)
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(PulseTheme.Colors.primary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct FeatureRowView: View {
    let feature: SubscriptionFeature
    
    var body: some View {
        HStack(spacing: PulseTheme.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(feature.isPremiumOnly ? Color.yellow.opacity(0.2) : PulseTheme.Colors.glassBackground)
                    .frame(width: 40, height: 40)
                
                Image(systemName: feature.icon)
                    .foregroundColor(feature.isPremiumOnly ? .yellow : PulseTheme.Colors.primary)
                    .font(.system(size: 16, weight: .semibold))
            }
            
            // Content
            VStack(alignment: .leading, spacing: PulseTheme.Spacing.xs) {
                Text(feature.title)
                    .font(PulseTheme.Typography.body)
                    .foregroundColor(PulseTheme.Colors.primary)
                    .fontWeight(.semibold)
                
                Text(feature.description)
                    .font(PulseTheme.Typography.bodySmall)
                    .foregroundColor(PulseTheme.Colors.secondary)
            }
            
            Spacer()
            
            // Premium badge
            if feature.isPremiumOnly {
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.yellow)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.yellow.opacity(0.2))
                    )
            }
        }
        .padding(PulseTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.md)
                .fill(PulseTheme.Colors.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: PulseTheme.CornerRadius.md)
                        .strokeBorder(
                            feature.isPremiumOnly ? Color.yellow.opacity(0.3) : PulseTheme.Colors.glassBorder,
                            lineWidth: 1
                        )
                )
        )
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(SubscriptionManager())
} 