//
//  CameraView.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    @EnvironmentObject private var cameraManager: CameraManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var matchingManager: MatchingManager
    @EnvironmentObject private var appState: AppState
    
    @State private var capturedMedia: CapturedMedia?
    @State private var showingCaptionEditor = false
    @State private var isShowingRadiusSlider = false
    @State private var selectedRadius: Double = 160934 // Default 100 miles in meters
    @State private var caption: String = ""
    @State private var dragStartLocation: CGPoint = .zero
    
    var body: some View {
        ZStack {
            PulseTheme.Colors.background
                .ignoresSafeArea()
            
            // Camera preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
                .opacity(capturedMedia == nil ? 1 : 0)
            
            // Captured media preview
            if let media = capturedMedia {
                CapturedMediaView(media: media) {
                    // Retake
                    capturedMedia = nil
                    caption = ""
                }
            }
            
            // Matching status overlay
            if matchingManager.isSearchingForMatch || 
               matchingManager.matchingStatus == .matched ||
               matchingManager.matchingStatus == .headedToEther {
                MatchingStatusView(matchingManager: matchingManager)
                    .padding()
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Camera controls overlay
            VStack {
                Spacer()
                
                // Bottom controls
                HStack {
                    // Gallery button (left)
                    Button {
                        // Open gallery
                    } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(PulseTheme.Colors.glassBackground)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "photo.on.rectangle")
                                    .foregroundColor(PulseTheme.Colors.primary)
                            )
                    }
                    
                    Spacer()
                    
                    // Capture button (center)
                    CaptureButton(
                        isRecording: cameraManager.isRecording,
                        onTap: handleCapture,
                        onLongPress: handleVideoRecording
                    )
                    
                    Spacer()
                    
                    // Flash/Settings button (right)
                    Button {
                        cameraManager.toggleFlash()
                    } label: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(PulseTheme.Colors.glassBackground)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash")
                                    .foregroundColor(PulseTheme.Colors.primary)
                            )
                    }
                }
                .padding(.horizontal, PulseTheme.Spacing.lg)
                .padding(.bottom, 50)
            }
            
            // Radius slider overlay
            if isShowingRadiusSlider {
                RadiusSliderView(
                    selectedRadius: $selectedRadius,
                    maxRadius: subscriptionManager.maxAllowedRadius(),
                    isPremium: subscriptionManager.isPremiumActive
                )
                .transition(.move(edge: .trailing))
            }
            
            // Send pulse button (when media is captured)
            if capturedMedia != nil {
                VStack {
                    Spacer()
                    
                    GlassButton("SEND PULSE") {
                        sendPulse()
                    }
                    .padding(.horizontal, PulseTheme.Spacing.lg)
                    .padding(.bottom, 100)
                }
            }
            
            // Caption editor overlay
            if showingCaptionEditor {
                CaptionEditorView(
                    caption: $caption,
                    isPresented: $showingCaptionEditor
                )
            }
        }
        .gesture(
            // Long press to show radius slider
            LongPressGesture(minimumDuration: 0.5)
                .onChanged { value in
                    if value {
                        // Show radius slider on long press
                        if !isShowingRadiusSlider {
                            withAnimation(PulseTheme.Animation.spring) {
                                isShowingRadiusSlider = true
                            }
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(PulseTheme.Animation.spring) {
                        isShowingRadiusSlider = false
                    }
                }
        )
        .onAppear {
            cameraManager.requestPermission()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didFindPulseMatch)) { _ in
            // Reset camera state when match is found
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                capturedMedia = nil
                selectedRadius = 160934 // Reset to default
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pulseHeadedToEther)) { _ in
            // Reset camera state when pulse heads to ether
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                capturedMedia = nil
                selectedRadius = 160934 // Reset to default
            }
        }
    }
    
    private func handleCapture() {
        guard capturedMedia == nil else { return }
        
        cameraManager.capturePhoto { result in
            switch result {
            case .success(let imageData):
                capturedMedia = CapturedMedia(type: .photo, data: imageData)
                showingCaptionEditor = true
            case .failure(let error):
                print("Photo capture failed: \(error)")
            }
        }
    }
    
    private func handleVideoRecording() {
        if cameraManager.isRecording {
            cameraManager.stopRecording { result in
                switch result {
                case .success(let videoURL):
                    if let videoData = try? Data(contentsOf: videoURL) {
                        capturedMedia = CapturedMedia(type: .video, data: videoData, url: videoURL)
                        showingCaptionEditor = true
                    }
                case .failure(let error):
                    print("Video recording failed: \(error)")
                }
            }
        } else {
            cameraManager.startRecording()
        }
    }
    
    // Note: Radius adjustment will be handled by the RadiusSliderView component directly
    
    private func sendPulse() {
        guard let media = capturedMedia else { return }
        
        // Check subscription limits
        guard subscriptionManager.canSendPulse(currentCount: 0) else { // TODO: Get actual count
            // Show upgrade prompt
            return
        }
        
        // Check location availability
        guard locationManager.getCurrentUserLocation() != nil else {
            // Show location required alert
            return
        }
        
        Task {
            do {
                // Generate unique filename
                let timestamp = Int(Date().timeIntervalSince1970)
                let fileExtension = media.type == .photo ? "jpg" : "mp4"
                let fileName = "\(UUID().uuidString)_\(timestamp).\(fileExtension)"
                let mimeType = media.type == .photo ? "image/jpeg" : "video/mp4"
                
                // Upload media to Supabase storage
                let mediaURL = try await SupabaseService.shared.uploadMedia(
                    data: media.data,
                    fileName: fileName,
                    mimeType: mimeType
                )
                
                print("✅ Media uploaded successfully: \(mediaURL)")
                
                // Start the pulse sending and matching flow
                await appState.sendPulse(
                    mediaURL: mediaURL,
                    mediaType: media.type,
                    caption: caption.isEmpty ? nil : caption,
                    targetRadius: selectedRadius
                )
                
                // Reset state - keep captured media visible during matching
                caption = ""
                
                // Show success feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
                // TODO: Navigate to pulse tracking view or show success animation
                
            } catch {
                print("❌ Failed to send pulse: \(error)")
                // TODO: Show error alert to user
            }
        }
    }
}

struct CapturedMedia {
    let type: PulseMediaType
    let data: Data
    let url: URL?
    
    init(type: PulseMediaType, data: Data, url: URL? = nil) {
        self.type = type
        self.data = data
        self.url = url
    }
}

#Preview {
    CameraView()
        .environmentObject(SubscriptionManager())
} 