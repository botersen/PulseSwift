import Foundation
import AVFoundation

// MARK: - Camera Domain Entity
struct CameraEntity {
    let isAuthorized: Bool
    let isSessionRunning: Bool
    let isFlashEnabled: Bool
    let isRecording: Bool
    let cameraPosition: CameraPosition
    
    static let initial = CameraEntity(
        isAuthorized: false,
        isSessionRunning: false,
        isFlashEnabled: false,
        isRecording: false,
        cameraPosition: .back
    )
}

enum CameraPosition {
    case front
    case back
    
    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }
}

struct CapturedMediaEntity {
    let id: UUID
    let type: MediaType
    let data: Data
    let url: URL?
    let timestamp: Date
    
    enum MediaType {
        case photo
        case video
    }
    
    init(type: MediaType, data: Data, url: URL? = nil) {
        self.id = UUID()
        self.type = type
        self.data = data
        self.url = url
        self.timestamp = Date()
    }
} 