import Foundation
import Combine

// MARK: - Camera Use Cases (Business Logic)
protocol CameraUseCasesProtocol {
    var cameraRepository: CameraRepositoryProtocol { get } // Expose repository for state binding
    func initializeCamera() async throws
    func capturePhoto() async throws -> CapturedMediaEntity
    func startVideoRecording() async throws
    func stopVideoRecording() async throws -> CapturedMediaEntity
    func switchCamera() async throws
    func toggleFlash() async throws
    func prepareForBackground()
    func prepareForForeground()
}

final class CameraUseCases: CameraUseCasesProtocol {
    let cameraRepository: CameraRepositoryProtocol // Make public for state binding
    private var isInitialized = false
    
    init(cameraRepository: CameraRepositoryProtocol) {
        self.cameraRepository = cameraRepository
    }
    
    func initializeCamera() async throws {
        guard !isInitialized else { return }
        
        // Business rule: Request permission (which also starts session if authorized)
        try await cameraRepository.requestPermission()
        // No need to call startSession again - requestPermission already starts it
        
        isInitialized = true
        logCameraEvent("initialized", success: true)
    }
    
    func capturePhoto() async throws -> CapturedMediaEntity {
        // Business rule: Ensure camera is ready
        guard isInitialized else {
            throw CameraError.sessionNotRunning
        }
        
        do {
            let media = try await cameraRepository.capturePhoto()
            logCameraEvent("photo_captured", success: true)
            
            // Business rule: Validate photo data
            guard media.data.count > 0 else {
                throw CameraError.outputNotAvailable
            }
            
            return media
        } catch {
            logCameraEvent("photo_capture_failed", success: false)
            throw error
        }
    }
    
    func startVideoRecording() async throws {
        // Business rule: Ensure camera is ready and not already recording
        guard isInitialized else {
            throw CameraError.sessionNotRunning
        }
        
        try await cameraRepository.startVideoRecording()
        logCameraEvent("video_recording_started", success: true)
    }
    
    func stopVideoRecording() async throws -> CapturedMediaEntity {
        do {
            let media = try await cameraRepository.stopVideoRecording()
            logCameraEvent("video_recording_stopped", success: true)
            
            // Business rule: Validate video data
            guard media.data.count > 0 else {
                throw CameraError.recordingFailed
            }
            
            return media
        } catch {
            logCameraEvent("video_recording_failed", success: false)
            throw error
        }
    }
    
    func switchCamera() async throws {
        guard isInitialized else {
            throw CameraError.sessionNotRunning
        }
        
        try await cameraRepository.switchCamera()
        logCameraEvent("camera_switched", success: true)
    }
    
    func toggleFlash() async throws {
        try await cameraRepository.toggleFlash()
        logCameraEvent("flash_toggled", success: true)
    }
    
    func prepareForBackground() {
        // Business rule: Properly handle app backgrounding
        cameraRepository.prepareForBackground()
        logCameraEvent("prepared_for_background", success: true)
    }
    
    func prepareForForeground() {
        // Business rule: Resume camera when app becomes active
        cameraRepository.prepareForForeground()
        logCameraEvent("prepared_for_foreground", success: true)
    }
    
    // MARK: - Private Helpers
    private func logCameraEvent(_ event: String, success: Bool) {
        print("📷 Camera event: \(event) - success: \(success)")
    }
} 