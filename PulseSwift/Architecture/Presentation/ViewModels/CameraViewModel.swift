import Foundation
import Combine
import SwiftUI
import AVFoundation

// MARK: - Notification Names
extension Notification.Name {
    static let prepareCameraForInstantStartup = Notification.Name("prepareCameraForInstantStartup")
}

// MARK: - Camera ViewModel (High-Performance Reactive State)
@MainActor
final class CameraViewModel: ObservableObject {
    
    // MARK: - Published Properties (UI State)
    @Published var cameraState: CameraEntity = .initial
    @Published var permissionStatus: CameraPermissionStatus = .notDetermined
    @Published var capturedMedia: CapturedMediaEntity?
    @Published var isInitialized: Bool = false
    
    // MARK: - UI State
    @Published var showCaptionEditor: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var errorMessage: String?
    @Published var isProcessing: Bool = false
    
    // MARK: - Performance Metrics
    @Published var sessionLatency: TimeInterval = 0
    @Published var captureLatency: TimeInterval = 0
    
    // MARK: - Dependencies
    @Injected private var cameraUseCases: CameraUseCasesProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Performance Tracking
    private var sessionStartTime: Date?
    private var captureStartTime: Date?
    
    // MARK: - Computed Properties
    var isSessionReady: Bool {
        // Show camera as soon as we have permission and are initialized
        permissionStatus == .authorized && isInitialized
    }
    
    var canCapture: Bool {
        isSessionReady && !isProcessing && !cameraState.isRecording
    }
    
    var canRecord: Bool {
        isSessionReady && !isProcessing
    }
    
    var flashButtonIcon: String {
        cameraState.isFlashEnabled ? "bolt.fill" : "bolt.slash.fill"
    }
    
    var recordingButtonIcon: String {
        cameraState.isRecording ? "stop.circle.fill" : "circle.fill"
    }
    
    init() {
        setupStateBinding()
        setupNotificationObservers()
        // Don't pre-initialize in init - let onAppear handle it explicitly
        print("📷 CameraViewModel: Initialized (waiting for explicit startup)")
    }
    
    // MARK: - Lifecycle Methods
    func onAppear() {
        print("📷 CameraViewModel: onAppear (initialized: \(isInitialized), sessionRunning: \(cameraState.isSessionRunning))")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        permissionStatus = CameraPermissionStatus(status)
        
        print("📷 CameraViewModel: Current permission status: \(permissionStatus)")
        print("📷 CameraViewModel: isSessionReady = \(isSessionReady)")
        
        // Check if camera is already preloaded and running
        if cameraState.isSessionRunning && permissionStatus == .authorized {
            print("✅ CameraViewModel: Camera already preloaded and running - instant display!")
            isInitialized = true
            return
        }
        
        // Always try to initialize if not already done
        if !isInitialized {
            if permissionStatus == .authorized {
                print("📷 CameraViewModel: Initializing camera on appear with authorized permissions")
                initializeCamera()
            } else if permissionStatus == .notDetermined {
                print("📷 CameraViewModel: Permission not determined - requesting and initializing")
                initializeCamera() // This will request permission first
            } else {
                print("❌ CameraViewModel: Permission denied or restricted - cannot initialize")
                showPermissionAlert = true
            }
        } else {
            print("📷 CameraViewModel: Camera already initialized - ready for instant display")
        }
    }
    
    func onDisappear() {
        print("📷 CameraViewModel: onDisappear")
        // Keep session running for instant return
    }
    
    func prepareForBackground() {
        print("📷 CameraViewModel: prepareForBackground")
        cameraUseCases.prepareForBackground()
    }
    
    func prepareForForeground() {
        print("📷 CameraViewModel: prepareForForeground")
        cameraUseCases.prepareForForeground()
    }
    
    // MARK: - Camera Actions
    func initializeCamera() {
        guard !isInitialized else { 
            print("📷 CameraViewModel: Already initialized, skipping")
            return 
        }
        
        print("📷 CameraViewModel: Starting camera initialization...")
        sessionStartTime = Date()
        
        Task {
            do {
                print("📷 CameraViewModel: Calling cameraUseCases.initializeCamera()")
                try await cameraUseCases.initializeCamera()
                await MainActor.run {
                    print("✅ CameraViewModel: Camera initialization completed successfully!")
                    self.isInitialized = true
                    self.calculateSessionLatency()
                    print("✅ CameraViewModel: isSessionReady = \(self.isSessionReady)")
                    print("✅ CameraViewModel: permissionStatus = \(self.permissionStatus)")
                }
            } catch {
                await MainActor.run {
                    print("❌ CameraViewModel: Camera initialization failed with error: \(error)")
                    self.handleError(error, context: "Camera initialization")
                    
                    // Show permission alert if it's a permission issue
                    if let cameraError = error as? CameraError {
                        switch cameraError {
                        case .permissionDenied:
                            self.showPermissionAlert = true
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
    
    func capturePhoto() {
        guard canCapture else { 
            print("⚠️ CameraViewModel: Cannot capture - conditions not met")
            return 
        }
        
        isProcessing = true
        captureStartTime = Date()
        
        // Haptic feedback for instant responsiveness
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        Task {
            do {
                let media = try await cameraUseCases.capturePhoto()
                await MainActor.run {
                    self.capturedMedia = media
                    self.showCaptionEditor = true
                    self.isProcessing = false
                    self.calculateCaptureLatency()
                    print("✅ CameraViewModel: Photo captured successfully")
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.handleError(error, context: "Photo capture")
                }
            }
        }
    }
    
    func startVideoRecording() {
        guard canRecord && !cameraState.isRecording else { return }
        
        isProcessing = true
        
        // Strong haptic feedback for video start
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        Task {
            do {
                try await cameraUseCases.startVideoRecording()
                await MainActor.run {
                    self.isProcessing = false
                    print("✅ CameraViewModel: Video recording started")
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.handleError(error, context: "Video recording start")
                }
            }
        }
    }
    
    func stopVideoRecording() {
        guard cameraState.isRecording else { return }
        
        isProcessing = true
        
        Task {
            do {
                let media = try await cameraUseCases.stopVideoRecording()
                await MainActor.run {
                    self.capturedMedia = media
                    self.showCaptionEditor = true
                    self.isProcessing = false
                    print("✅ CameraViewModel: Video recording stopped")
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.handleError(error, context: "Video recording stop")
                }
            }
        }
    }
    
    func switchCamera() {
        guard canCapture else { return }
        
        // Light haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        
        Task {
            do {
                try await cameraUseCases.switchCamera()
                print("✅ CameraViewModel: Camera switched")
            } catch {
                await MainActor.run {
                    self.handleError(error, context: "Camera switch")
                }
            }
        }
    }
    
    func toggleFlash() {
        Task {
            do {
                try await cameraUseCases.toggleFlash()
                print("✅ CameraViewModel: Flash toggled")
            } catch {
                await MainActor.run {
                    self.handleError(error, context: "Flash toggle")
                }
            }
        }
    }
    
    func retakePhoto() {
        capturedMedia = nil
        showCaptionEditor = false
        errorMessage = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    private func restartSession() {
        Task {
            do {
                try await cameraUseCases.initializeCamera()
                print("✅ CameraViewModel: Session restarted")
            } catch {
                await MainActor.run {
                    self.handleError(error, context: "Session restart")
                }
            }
        }
    }
    

    
    private func setupNotificationObservers() {
        // Listen for camera pre-loading requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCameraPreloadRequest),
            name: .prepareCameraForInstantStartup,
            object: nil
        )
    }
    
    @objc private func handleCameraPreloadRequest() {
        print("🚀 CameraViewModel: Received pre-load request")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized && !isInitialized {
            print("🚀 CameraViewModel: Starting background camera initialization...")
            // For returning users, initialize immediately without delay
            initializeCamera()
        }
    }
    
    private func setupStateBinding() {
        // Subscribe to camera repository state
        cameraUseCases.cameraRepository.cameraStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cameraState in
                self?.cameraState = cameraState
            }
            .store(in: &cancellables)
            
        cameraUseCases.cameraRepository.permissionStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (permissionStatus: CameraPermissionStatus) in
                self?.permissionStatus = permissionStatus
                self?.handlePermissionChange(permissionStatus)
            }
            .store(in: &cancellables)
    }
    
    private func handlePermissionChange(_ status: CameraPermissionStatus) {
        print("📷 CameraViewModel: Permission changed to \(status)")
        switch status {
        case .authorized:
            // Don't auto-initialize here - let onAppear handle it to prevent loops
            print("📷 CameraViewModel: Permission authorized, waiting for explicit initialization")
        case .denied, .restricted:
            showPermissionAlert = true
        case .notDetermined:
            break
        }
    }
    
    private func handleError(_ error: Error, context: String) {
        print("❌ CameraViewModel: \(context) error: \(error)")
        
        if let cameraError = error as? CameraError {
            switch cameraError {
            case .permissionDenied:
                showPermissionAlert = true
                errorMessage = "Camera permission is required to take photos and videos."
            case .sessionNotRunning:
                errorMessage = "Camera session not running. Please try again."
                // Attempt to restart
                restartSession()
            default:
                errorMessage = cameraError.errorDescription
            }
        } else {
            errorMessage = "An unexpected error occurred. Please try again."
        }
        
        // Reset any processing states
        isProcessing = false
    }
    
    private func calculateSessionLatency() {
        guard let startTime = sessionStartTime else { return }
        sessionLatency = Date().timeIntervalSince(startTime)
        sessionStartTime = nil
        
        // Log performance metrics
        if sessionLatency > 1.0 {
            print("⚠️ CameraViewModel: Slow session startup: \(sessionLatency)s")
        } else {
            print("✅ CameraViewModel: Fast session startup: \(sessionLatency)s")
        }
    }
    
    private func calculateCaptureLatency() {
        guard let startTime = captureStartTime else { return }
        captureLatency = Date().timeIntervalSince(startTime)
        captureStartTime = nil
        
        // Log performance metrics
        if captureLatency > 0.5 {
            print("⚠️ CameraViewModel: Slow capture: \(captureLatency)s")
        } else {
            print("✅ CameraViewModel: Fast capture: \(captureLatency)s")
        }
    }
}

// MARK: - Camera State Helpers
extension CameraViewModel {
    var statusText: String {
        switch permissionStatus {
        case .notDetermined:
            return "Camera permission required"
        case .denied:
            return "Camera access denied"
        case .restricted:
            return "Camera access restricted"
        case .authorized:
            if !isSessionReady {
                return "Initializing camera..."
            } else {
                return "Ready"
            }
        }
    }
    
    var shouldShowPermissionButton: Bool {
        permissionStatus == .denied || permissionStatus == .notDetermined
    }
} 

extension CameraPermissionStatus {
    init(_ status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .authorized: self = .authorized
        @unknown default: self = .notDetermined
        }
    }
} 