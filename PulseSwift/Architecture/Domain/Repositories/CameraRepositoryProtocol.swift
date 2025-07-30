import Foundation
import Combine

// MARK: - Camera Repository Protocol (Domain Interface)
protocol CameraRepositoryProtocol {
    // State Publishers
    var cameraStatePublisher: AnyPublisher<CameraEntity, Never> { get }
    var permissionStatusPublisher: AnyPublisher<CameraPermissionStatus, Never> { get }
    
    // Session Management
    func requestPermission() async throws
    func startSession() async throws
    func stopSession() async throws
    func switchCamera() async throws
    
    // Capture Operations
    func capturePhoto() async throws -> CapturedMediaEntity
    func startVideoRecording() async throws
    func stopVideoRecording() async throws -> CapturedMediaEntity
    
    // Settings
    func toggleFlash() async throws
    func setFlash(enabled: Bool) async throws
    
    // Lifecycle
    func prepareForBackground()
    func prepareForForeground()
}

// MARK: - Camera Permission Status
enum CameraPermissionStatus {
    case notDetermined
    case denied
    case authorized
    case restricted
}
// MARK: - Camera Errors
enum CameraError: LocalizedError {
    case permissionDenied
    case sessionNotRunning
    case captureDeviceNotFound
    case outputNotAvailable
    case recordingFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission denied"
        case .sessionNotRunning:
            return "Camera session not running"
        case .captureDeviceNotFound:
            return "Camera device not found"
        case .outputNotAvailable:
            return "Camera output not available"
        case .recordingFailed:
            return "Video recording failed"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
} 
