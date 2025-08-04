import SwiftUI
import AVFoundation

// MARK: - Camera Screen (High-Performance Clean Architecture)
struct CameraScreen: View {
    @ObservedObject private var cameraViewModel = CameraViewModel.shared
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appFlowViewModel: AppFlowViewModel
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Camera preview
            if cameraViewModel.isSessionReady {
                CameraPreviewLayer(cameraViewModel: cameraViewModel)
                    .ignoresSafeArea()
            } else {
                CameraPlaceholderView(cameraViewModel: cameraViewModel)
            }
            
            // Camera controls overlay
            CameraControlsOverlay(cameraViewModel: cameraViewModel)
            
            // Captured media preview
            if let capturedMedia = cameraViewModel.capturedMedia {
                CapturedMediaPreview(
                    media: capturedMedia,
                    onRetake: cameraViewModel.retakePhoto
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // Permission alert
            if cameraViewModel.showPermissionAlert {
                PermissionAlertOverlay(cameraViewModel: cameraViewModel)
            }
            
            // Error overlay
            if let errorMessage = cameraViewModel.errorMessage {
                ErrorOverlay(
                    message: errorMessage,
                    onDismiss: cameraViewModel.clearError
                )
            }
        }
        .onAppear {
            appFlowViewModel.requestAllPermissionsIfNeeded()
            cameraViewModel.onAppear()
            print("📷 CameraScreen: onAppear - forcing preview reconnection")
            
            // CRITICAL FIX: Force preview layer reconnection on appear
            // This ensures camera works when returning from navigation
            Task { @MainActor in
                // Small delay to ensure session is fully ready
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                cameraViewModel.refreshPreviewConnection()
            }
        }
        .onDisappear {
            print("📷 CameraScreen: onDisappear called - NOT calling cameraViewModel.onDisappear() to keep camera alive")
            // cameraViewModel.onDisappear() // REMOVED - this was causing camera to go black
        }
        .onReceive(NotificationCenter.default.publisher(for: .appBecameActive)) { _ in
            cameraViewModel.prepareForForeground()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appWillResignActive)) { _ in
            cameraViewModel.prepareForBackground()
        }
        .sheet(isPresented: $cameraViewModel.showCaptionEditor) {
            if let media = cameraViewModel.capturedMedia {
                CaptionEditorSheet(media: media, cameraViewModel: cameraViewModel)
            }
        }
    }
}

// MARK: - Industry Standard Camera Preview Layer
struct CameraPreviewLayer: UIViewRepresentable {
    let cameraViewModel: CameraViewModel
    @Injected private var cameraRepository: CameraRepositoryProtocol
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        
        // Industry standard: Connect to session immediately
        if let repository = cameraRepository as? CameraRepository {
            let session = repository.session
            view.setupPreview(with: session)
            print("✅ CameraPreviewLayer: Connected to session")
        }
        
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Industry standard: Preview layer should stay connected
        // Only reconnect if session changed or lost connection
        if let repository = cameraRepository as? CameraRepository {
            let session = repository.session
            if uiView.needsSessionUpdate(session) {
                uiView.setupPreview(with: session)
                print("🔄 CameraPreviewLayer: Updated session connection")
            }
        }
    }
}

// MARK: - Industry Standard Camera Preview UI View
class CameraPreviewUIView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var currentSession: AVCaptureSession?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    func setupPreview(with session: AVCaptureSession) {
        // Industry standard: Only create new layer if needed
        if previewLayer?.session === session {
            return
        }
        
        // Remove existing layer
        previewLayer?.removeFromSuperlayer()
        
        // Create and configure new preview layer
        let newPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        newPreviewLayer.videoGravity = .resizeAspectFill
        newPreviewLayer.frame = bounds
        
        layer.addSublayer(newPreviewLayer)
        previewLayer = newPreviewLayer
        currentSession = session
        
        print("✅ CameraPreviewUIView: Preview layer setup complete")
    }
    
    func needsSessionUpdate(_ session: AVCaptureSession) -> Bool {
        return previewLayer?.session !== session
    }
}

// MARK: - Camera Placeholder View
struct CameraPlaceholderView: View {
    let cameraViewModel: CameraViewModel
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Camera icon
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.3))
                
                // Status text
                Text(cameraViewModel.statusText)
                    .font(.custom("DM Mono", size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                // Permission button if needed
                if cameraViewModel.shouldShowPermissionButton {
                    Button("Enable Camera") {
                        // Open settings on main thread
                        Task { @MainActor in
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                    }
                    .font(.custom("DM Mono", size: 14))
                    .foregroundColor(.black)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(8)
                }
                
                // Loading indicator
                if cameraViewModel.isInitialized && !cameraViewModel.isSessionReady {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                }
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Camera Controls Overlay
struct CameraControlsOverlay: View {
    let cameraViewModel: CameraViewModel
    
    var body: some View {
        VStack {
            // Top controls
            HStack {
                // Flash toggle
                Button(action: cameraViewModel.toggleFlash) {
                    Image(systemName: cameraViewModel.flashButtonIcon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                        )
                }
                .disabled(!cameraViewModel.canCapture)
                
                Spacer()
                
                // Settings/logout button
                Menu {
                    Button("Sign Out") { 
                        authViewModel.signOut()
                    }
                    Button("Settings") {
                        // Open settings (placeholder for future)
                        print("Settings tapped")
                    }
                } label: {
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.3))
                        )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            
            Spacer()
            
            // Bottom controls
            HStack {
                // Gallery button
                Button {
                    cameraViewModel.openPhotoLibrary()
                } label: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.white)
                        )
                }
                
                Spacer()
                
                // Capture button
                CaptureButton(cameraViewModel: cameraViewModel)
                
                Spacer()
                
                // Switch camera button
                Button(action: cameraViewModel.switchCamera) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "camera.rotate")
                                .foregroundColor(.white)
                        )
                }
                .disabled(!cameraViewModel.canCapture)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 50)
        }
    }
}
// MARK: - Capture Button
struct CaptureButton: View {
    let cameraViewModel: CameraViewModel
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .strokeBorder(Color.white, lineWidth: 4)
                .frame(width: 80, height: 80)
                .scaleEffect(isPressed ? 0.95 : 1.0)
            
            // Inner button
            RoundedRectangle(cornerRadius: innerCornerRadius)
                .fill(innerColor)
                .frame(width: innerSize, height: innerSize)
                .scaleEffect(recordingScale)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    handleTap()
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onChanged { _ in
                    if !cameraViewModel.cameraState.isRecording {
                        cameraViewModel.startVideoRecording()
                    }
                }
        )
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.3), value: cameraViewModel.cameraState.isRecording)
        .disabled(!cameraViewModel.canCapture && !cameraViewModel.cameraState.isRecording)
    }
    
    private var innerCornerRadius: CGFloat {
        cameraViewModel.cameraState.isRecording ? 8 : 30
    }
    
    private var innerColor: Color {
        if !cameraViewModel.canCapture && !cameraViewModel.cameraState.isRecording {
            return Color.gray
        } else if cameraViewModel.cameraState.isRecording {
            return Color.red
        } else {
            return Color.white
        }
    }
    
    private var innerSize: CGFloat {
        cameraViewModel.cameraState.isRecording ? 32 : 60
    }
    
    private var recordingScale: CGFloat {
        cameraViewModel.cameraState.isRecording ? 1.1 : 1.0
    }
    
    private func handleTap() {
        if cameraViewModel.cameraState.isRecording {
            cameraViewModel.stopVideoRecording()
        } else {
            cameraViewModel.capturePhoto()
        }
    }
}

// MARK: - Captured Media Preview
struct CapturedMediaPreview: View {
    let media: CapturedMediaEntity
    let onRetake: () -> Void
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            // Media content
            if let uiImage = UIImage(data: media.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .ignoresSafeArea()
            }
            
            // Controls overlay
            VStack {
                HStack {
                    Button("Retake", action: onRetake)
                        .font(.custom("DM Mono", size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.7))
                        )
                    
                    Spacer()
                }
                .padding(.top, 60)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}

// MARK: - Permission Alert Overlay
struct PermissionAlertOverlay: View {
    let cameraViewModel: CameraViewModel
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Camera Permission Required")
                    .font(.custom("Special Gothic Expanded One", size: 20))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("PulseSwift needs camera access to take photos and videos.")
                    .font(.custom("DM Mono", size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                
                Button("Open Settings") {
                    Task { @MainActor in
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(settingsUrl)
                        }
                    }
                }
                .font(.custom("DM Mono", size: 16))
                .foregroundColor(.black)
                .fontWeight(.semibold)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(8)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Error Overlay
struct ErrorOverlay: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Text(message)
                    .font(.custom("DM Mono", size: 14))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("×", action: onDismiss)
                    .font(.custom("DM Mono", size: 18))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.8))
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Caption Editor Sheet
struct CaptionEditorSheet: View {
    let media: CapturedMediaEntity
    let cameraViewModel: CameraViewModel
    @State private var caption = ""
    
    var body: some View {
        VStack {
            Text("Add Caption")
                .font(.custom("Special Gothic Expanded One", size: 20))
                .foregroundColor(.white)
                .padding(.top, 20)
            
            TextField("Write a caption...", text: $caption)
                .font(.custom("DM Mono", size: 16))
                .foregroundColor(.white)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
                .padding(.horizontal, 24)
            
            Spacer()
            
            HStack(spacing: 16) {
                Button("Cancel") {
                    cameraViewModel.retakePhoto()
                }
                .font(.custom("DM Mono", size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
                
                Button("Send Pulse") {
                    // Handle sending pulse
                    cameraViewModel.showCaptionEditor = false
                    cameraViewModel.retakePhoto()
                }
                .font(.custom("DM Mono", size: 16))
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    CameraScreen()
        .environmentObject(AuthViewModel())
} 
