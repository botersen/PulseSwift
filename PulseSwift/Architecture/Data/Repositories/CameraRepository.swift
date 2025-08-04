import Foundation
import Combine
import AVFoundation

// MARK: - Industry Standard Camera Repository
final class CameraRepository: NSObject, CameraRepositoryProtocol {
    
    // MARK: - Publishers
    private let cameraStateSubject = CurrentValueSubject<CameraEntity, Never>(.initial)
    private let permissionStatusSubject = CurrentValueSubject<CameraPermissionStatus, Never>(.notDetermined)
    
    var cameraStatePublisher: AnyPublisher<CameraEntity, Never> {
        cameraStateSubject.eraseToAnyPublisher()
    }
    
    var permissionStatusPublisher: AnyPublisher<CameraPermissionStatus, Never> {
        permissionStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Core Components (Industry Standard)
    private let _session = AVCaptureSession()
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentInput: AVCaptureDeviceInput?
    private var currentCameraPosition: CameraPosition = .back
    
    // Protocol compatibility
    var captureSession: AVCaptureSession? {
        return _session
    }
    
    // Direct session access
    var session: AVCaptureSession {
        return _session
    }
    
    // MARK: - State
    private var isConfigured = false
    private var recordingCompletion: ((Result<CapturedMediaEntity, Error>) -> Void)?
    private let maxRecordingDuration: TimeInterval = 30.0
    
    override init() {
        super.init()
        
        // Industry standard: Set up session immediately
        setupSession()
        
        // Check permissions and start if authorized
        checkPermissions()
        
        print("✅ CameraRepository: Industry standard setup complete")
    }
    
    // MARK: - Industry Standard Session Management
    private func setupSession() {
        // Configure session quality
        _session.sessionPreset = .high
        
        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        if _session.canAddOutput(photoOutput) {
            _session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        }
        
        // Add video output  
        let movieOutput = AVCaptureMovieFileOutput()
        if _session.canAddOutput(movieOutput) {
            _session.addOutput(movieOutput)
            self.movieOutput = movieOutput
        }
        
        print("✅ CameraRepository: Session outputs configured")
    }
    
    private func checkPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        updatePermissionStatus(status)
        
        if status == .authorized {
            setupCameraInput()
            startSessionIfNeeded()
        }
    }
    
    private func setupCameraInput() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition.avPosition) else {
            print("❌ CameraRepository: No camera device found")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            
            _session.beginConfiguration()
            
            // Remove existing inputs
            _session.inputs.forEach { _session.removeInput($0) }
            
            if _session.canAddInput(input) {
                _session.addInput(input)
                currentInput = input
                isConfigured = true
                print("✅ CameraRepository: Camera input configured for \(currentCameraPosition)")
            }
            
            _session.commitConfiguration()
            
        } catch {
            print("❌ CameraRepository: Failed to setup camera input: \(error)")
        }
    }
    
    private func startSessionIfNeeded() {
        guard !_session.isRunning, isConfigured else { return }
        
        Task {
            _session.startRunning()
            
            await MainActor.run {
                updateCameraState(isSessionRunning: true)
                print("✅ CameraRepository: Session started and running")
            }
        }
    }
    
    // MARK: - Protocol Implementation
    func requestPermission() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        if status == .authorized {
            return
        }
        
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        
        await MainActor.run {
            if granted {
                updatePermissionStatus(.authorized)
                setupCameraInput()
                startSessionIfNeeded()
            } else {
                updatePermissionStatus(.denied)
            }
        }
        
        if !granted {
            throw CameraError.permissionDenied
        }
    }
    
    func startSession() async throws {
        // Session should already be running - this is for compatibility
        if !_session.isRunning {
            await MainActor.run {
                startSessionIfNeeded()
            }
        }
    }
    
    func stopSession() async throws {
        _session.stopRunning()
        await MainActor.run {
            updateCameraState(isSessionRunning: false)
        }
    }
    
    func switchCamera() async throws {
        let newPosition: CameraPosition = currentCameraPosition == .back ? .front : .back
        currentCameraPosition = newPosition
        
        await MainActor.run {
            setupCameraInput()
        }
    }
    
    // MARK: - Capture Operations
    func capturePhoto() async throws -> CapturedMediaEntity {
        guard let photoOutput = photoOutput else {
            throw CameraError.outputNotAvailable
        }
        
        guard _session.isRunning else {
            throw CameraError.sessionNotRunning
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            settings.flashMode = cameraStateSubject.value.isFlashEnabled ? .on : .off
            
            let delegate = PhotoCaptureDelegate { result in
                continuation.resume(with: result)
            }
            
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
    
    func startVideoRecording() async throws {
        guard let movieOutput = movieOutput else {
            throw CameraError.outputNotAvailable
        }
        
        guard _session.isRunning else {
            throw CameraError.sessionNotRunning
        }
        
        let outputURL = getTemporaryVideoURL()
        movieOutput.maxRecordedDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 30)
        
        let delegate = MovieRecordingDelegate { [weak self] result in
            Task { @MainActor in
                self?.updateCameraState(isRecording: false)
                self?.recordingCompletion?(result)
                self?.recordingCompletion = nil
            }
        }
        
        movieOutput.startRecording(to: outputURL, recordingDelegate: delegate)
        
        await MainActor.run {
            updateCameraState(isRecording: true)
        }
    }
    
    func stopVideoRecording() async throws -> CapturedMediaEntity {
        guard let movieOutput = movieOutput else {
            throw CameraError.outputNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            recordingCompletion = { result in
                continuation.resume(with: result)
            }
            
            movieOutput.stopRecording()
        }
    }
    
    // MARK: - Settings
    func toggleFlash() async throws {
        let newState = !cameraStateSubject.value.isFlashEnabled
        try await setFlash(enabled: newState)
    }
    
    func setFlash(enabled: Bool) async throws {
        await MainActor.run {
            updateCameraState(isFlashEnabled: enabled)
        }
    }
    
    // MARK: - Lifecycle
    func prepareForBackground() {
        // Industry standard: Keep session running for instant return
        print("📷 CameraRepository: Prepared for background (keeping session)")
    }
    
    func prepareForForeground() {
        // Industry standard: Session should still be running
        if !_session.isRunning {
            startSessionIfNeeded()
        }
        print("📷 CameraRepository: Prepared for foreground")
    }
    
    // MARK: - Helpers
    private func getTemporaryVideoURL() -> URL {
        let documentsPath = FileManager.default.temporaryDirectory
        let fileName = "video_\(UUID().uuidString).mov"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    private func updatePermissionStatus(_ status: AVAuthorizationStatus) {
        let permissionStatus: CameraPermissionStatus
        switch status {
        case .authorized: permissionStatus = .authorized
        case .denied: permissionStatus = .denied
        case .restricted: permissionStatus = .restricted
        case .notDetermined: permissionStatus = .notDetermined
        @unknown default: permissionStatus = .notDetermined
        }
        
        permissionStatusSubject.send(permissionStatus)
    }
    
    private func updateCameraState(
        isSessionRunning: Bool? = nil,
        isFlashEnabled: Bool? = nil,
        isRecording: Bool? = nil,
        cameraPosition: CameraPosition? = nil
    ) {
        let currentState = cameraStateSubject.value
        
        let newState = CameraEntity(
            isAuthorized: permissionStatusSubject.value == .authorized,
            isSessionRunning: isSessionRunning ?? currentState.isSessionRunning,
            isFlashEnabled: isFlashEnabled ?? currentState.isFlashEnabled,
            isRecording: isRecording ?? currentState.isRecording,
            cameraPosition: cameraPosition ?? currentState.cameraPosition
        )
        
        cameraStateSubject.send(newState)
    }
}

// MARK: - Photo Capture Delegate
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<CapturedMediaEntity, Error>) -> Void
    
    init(completion: @escaping (Result<CapturedMediaEntity, Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let data = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.outputNotAvailable))
            return
        }
        
        let media = CapturedMediaEntity(type: .photo, data: data)
        completion(.success(media))
    }
}

// MARK: - Movie Recording Delegate
private class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let completion: (Result<CapturedMediaEntity, Error>) -> Void
    
    init(completion: @escaping (Result<CapturedMediaEntity, Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            completion(.failure(error))
            return
        }
        
        do {
            let data = try Data(contentsOf: outputFileURL)
            let media = CapturedMediaEntity(type: .video, data: data, url: outputFileURL)
            completion(.success(media))
        } catch {
            completion(.failure(error))
        }
    }
}