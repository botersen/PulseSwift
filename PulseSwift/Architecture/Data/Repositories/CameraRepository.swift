import Foundation
import Combine
import AVFoundation

// MARK: - Camera Repository Implementation (Performance Optimized)
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
    
    // MARK: - Camera Components
    private var _captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentInput: AVCaptureDeviceInput?
    
    // Public access to session for preview layer
    var captureSession: AVCaptureSession? {
        return _captureSession
    }
    
    // MARK: - Performance Optimization
    private let cameraQueue = DispatchQueue(label: "com.pulse.camera", qos: .userInitiated)
    private let photoProcessingQueue = DispatchQueue(label: "com.pulse.photo", qos: .userInitiated)
    private var isSessionConfigured = false
    private var currentCameraPosition: CameraPosition = .back
    
    // MARK: - Recording
    private var recordingCompletion: ((Result<CapturedMediaEntity, Error>) -> Void)?
    private let maxRecordingDuration: TimeInterval = 10.0
    
    override init() {
        super.init()
        
        // Immediate permission check
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        updatePermissionStatus(currentStatus)
        
        // Don't pre-configure - wait for explicit initialization to prevent loops
        print("✅ CameraRepository: Initialized (session will be configured on demand)")
    }
    
    // MARK: - Session Management
    func requestPermission() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            updatePermissionStatus(.authorized)
            try await startSession()
            
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            let newStatus: AVAuthorizationStatus = granted ? .authorized : .denied
            updatePermissionStatus(newStatus)
            
            if granted {
                try await startSession()
            } else {
                throw CameraError.permissionDenied
            }
            
        case .denied, .restricted:
            updatePermissionStatus(status == .denied ? .denied : .restricted)
            throw CameraError.permissionDenied
            
        @unknown default:
            throw CameraError.unknown(NSError(domain: "CameraRepository", code: -1))
        }
    }
    
    func startSession() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            cameraQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.unknown(NSError(domain: "CameraRepository", code: -2)))
                    return
                }
                
                do {
                    if !self.isSessionConfigured {
                        try self.configureSession()
                    }
                    
                    self._captureSession?.startRunning()
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.updateCameraState(isSessionRunning: true)
                        continuation.resume()
                    }
                    
                    print("✅ CameraRepository: Session started successfully")
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func stopSession() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            cameraQueue.async { [weak self] in
                self?._captureSession?.stopRunning()
                
                DispatchQueue.main.async { [weak self] in
                    self?.updateCameraState(isSessionRunning: false)
                    continuation.resume()
                }
                
                print("✅ CameraRepository: Session stopped")
            }
        }
    }
    
    func switchCamera() async throws {
        let newPosition: CameraPosition = currentCameraPosition == .back ? .front : .back
        
        return try await withCheckedThrowingContinuation { continuation in
            cameraQueue.async { [weak self] in
                guard let self = self,
                      let session = self._captureSession else {
                    continuation.resume(throwing: CameraError.sessionNotRunning)
                    return
                }
                
                session.beginConfiguration()
                
                // Remove current input
                if let currentInput = self.currentInput {
                    session.removeInput(currentInput)
                }
                
                // Add new input
                do {
                    let newInput = try self.createCameraInput(for: newPosition)
                    if session.canAddInput(newInput) {
                        session.addInput(newInput)
                        self.currentInput = newInput
                        self.currentCameraPosition = newPosition
                    } else {
                        throw CameraError.captureDeviceNotFound
                    }
                } catch {
                    session.commitConfiguration()
                    continuation.resume(throwing: error)
                    return
                }
                
                session.commitConfiguration()
                
                DispatchQueue.main.async { [weak self] in
                    self?.updateCameraState(cameraPosition: newPosition)
                    continuation.resume()
                }
                
                print("✅ CameraRepository: Camera switched to \(newPosition)")
            }
        }
    }
    
    // MARK: - Capture Operations
    func capturePhoto() async throws -> CapturedMediaEntity {
        guard let photoOutput = photoOutput else {
            throw CameraError.outputNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            photoProcessingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.unknown(NSError(domain: "CameraRepository", code: -3)))
                    return
                }
                
                let settings = AVCapturePhotoSettings()
                
                // Configure settings based on current state
                let currentState = self.cameraStateSubject.value
                settings.flashMode = currentState.isFlashEnabled ? .on : .off
                
                let delegate = PhotoCaptureDelegate { result in
                    continuation.resume(with: result)
                }
                
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }
    
    func startVideoRecording() async throws {
        guard let movieOutput = movieOutput else {
            throw CameraError.outputNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            cameraQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CameraError.unknown(NSError(domain: "CameraRepository", code: -4)))
                    return
                }
                
                let outputURL = self.getTemporaryVideoURL()
                
                movieOutput.maxRecordedDuration = CMTime(seconds: self.maxRecordingDuration, preferredTimescale: 30)
                
                let delegate = MovieRecordingDelegate { [weak self] result in
                    DispatchQueue.main.async { [weak self] in
                        self?.updateCameraState(isRecording: false)
                        self?.recordingCompletion?(result)
                        self?.recordingCompletion = nil
                    }
                }
                
                movieOutput.startRecording(to: outputURL, recordingDelegate: delegate)
                
                DispatchQueue.main.async { [weak self] in
                    self?.updateCameraState(isRecording: true)
                    continuation.resume()
                }
            }
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
        let currentState = cameraStateSubject.value
        try await setFlash(enabled: !currentState.isFlashEnabled)
    }
    
    func setFlash(enabled: Bool) async throws {
        await MainActor.run {
            updateCameraState(isFlashEnabled: enabled)
        }
    }
    
    // MARK: - Lifecycle
    func prepareForBackground() {
        cameraQueue.async { [weak self] in
            self?._captureSession?.stopRunning()
        }
        
        updateCameraState(isSessionRunning: false)
        print("✅ CameraRepository: Prepared for background")
    }
    
    func prepareForForeground() {
        cameraQueue.async { [weak self] in
            if self?.permissionStatusSubject.value == .authorized {
                self?._captureSession?.startRunning()
                
                DispatchQueue.main.async { [weak self] in
                    self?.updateCameraState(isSessionRunning: true)
                }
            }
        }
        
        print("✅ CameraRepository: Prepared for foreground")
    }
    
    // MARK: - Private Methods
    private func preConfigureSession() {
        cameraQueue.async { [weak self] in
            do {
                try self?.configureSession()
                print("✅ CameraRepository: Session pre-configured")
            } catch {
                print("❌ CameraRepository: Failed to pre-configure session: \(error)")
            }
        }
    }
    
    private func configureSession() throws {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        // Add camera input
        let cameraInput = try createCameraInput(for: currentCameraPosition)
        if session.canAddInput(cameraInput) {
            session.addInput(cameraInput)
            currentInput = cameraInput
        } else {
            throw CameraError.captureDeviceNotFound
        }
        
        // Add photo output
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            self.photoOutput = photoOutput
        } else {
            throw CameraError.outputNotAvailable
        }
        
        // Add movie output
        let movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
            self.movieOutput = movieOutput
        } else {
            throw CameraError.outputNotAvailable
        }
        
        self._captureSession = session
        self.isSessionConfigured = true
        
        print("✅ CameraRepository: Session configured successfully")
    }
    
    private func createCameraInput(for position: CameraPosition) throws -> AVCaptureDeviceInput {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition) else {
            throw CameraError.captureDeviceNotFound
        }
        
        return try AVCaptureDeviceInput(device: device)
    }
    
    private func getTemporaryVideoURL() -> URL {
        let documentsPath = FileManager.default.temporaryDirectory
        let fileName = "video_\(UUID().uuidString).mov"
        return documentsPath.appendingPathComponent(fileName)
    }
    
    private func updatePermissionStatus(_ status: AVAuthorizationStatus) {
        let permissionStatus: CameraPermissionStatus
        
        switch status {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .denied:
            permissionStatus = .denied
        case .authorized:
            permissionStatus = .authorized
        case .restricted:
            permissionStatus = .restricted
        @unknown default:
            permissionStatus = .denied
        }
        
        permissionStatusSubject.send(permissionStatus)
    }
    
    private func updateCameraState(
        isAuthorized: Bool? = nil,
        isSessionRunning: Bool? = nil,
        isFlashEnabled: Bool? = nil,
        isRecording: Bool? = nil,
        cameraPosition: CameraPosition? = nil
    ) {
        let current = cameraStateSubject.value
        
        let newState = CameraEntity(
            isAuthorized: isAuthorized ?? (permissionStatusSubject.value == .authorized),
            isSessionRunning: isSessionRunning ?? current.isSessionRunning,
            isFlashEnabled: isFlashEnabled ?? current.isFlashEnabled,
            isRecording: isRecording ?? current.isRecording,
            cameraPosition: cameraPosition ?? current.cameraPosition
        )
        
        cameraStateSubject.send(newState)
    }
}

// MARK: - Photo Capture Delegate
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<CapturedMediaEntity, Error>) -> Void
    
    init(completion: @escaping (Result<CapturedMediaEntity, Error>) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(.failure(CameraError.unknown(error)))
            return
        }
        
        guard let photoData = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.outputNotAvailable))
            return
        }
        
        let capturedMedia = CapturedMediaEntity(type: .photo, data: photoData)
        completion(.success(capturedMedia))
    }
}

// MARK: - Movie Recording Delegate
private class MovieRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let completion: (Result<CapturedMediaEntity, Error>) -> Void
    
    init(completion: @escaping (Result<CapturedMediaEntity, Error>) -> Void) {
        self.completion = completion
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            completion(.failure(CameraError.recordingFailed))
            return
        }
        
        do {
            let videoData = try Data(contentsOf: outputFileURL)
            let capturedMedia = CapturedMediaEntity(type: .video, data: videoData, url: outputFileURL)
            completion(.success(capturedMedia))
        } catch {
            completion(.failure(CameraError.recordingFailed))
        }
    }
} 