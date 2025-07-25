//
//  CapturedMediaView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI
import AVKit

struct CapturedMediaView: View {
    let media: CapturedMedia
    let onRetake: () -> Void
    
    var body: some View {
        ZStack {
            PulseTheme.Colors.background
                .ignoresSafeArea()
            
            // Media content
            Group {
                switch media.type {
                case .photo:
                    if let uiImage = UIImage(data: media.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .ignoresSafeArea()
                    }
                    
                case .video:
                    if let url = media.url {
                        VideoPlayer(player: AVPlayer(url: url))
                            .ignoresSafeArea()
                    }
                }
            }
            
            // Retake button overlay
            VStack {
                HStack {
                    Button {
                        onRetake()
                    } label: {
                        HStack(spacing: PulseTheme.Spacing.sm) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Retake")
                                .font(PulseTheme.Typography.bodySmall)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(PulseTheme.Colors.primary)
                        .padding(.horizontal, PulseTheme.Spacing.md)
                        .padding(.vertical, PulseTheme.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(PulseTheme.Colors.glassBackground)
                                .overlay(
                                    Capsule()
                                        .strokeBorder(PulseTheme.Colors.glassBorder, lineWidth: 1)
                                )
                        )
                    }
                    
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.horizontal, PulseTheme.Spacing.lg)
                
                Spacer()
            }
        }
    }
}

#Preview {
    CapturedMediaView(
        media: CapturedMedia(type: .photo, data: Data()),
        onRetake: {}
    )
} 