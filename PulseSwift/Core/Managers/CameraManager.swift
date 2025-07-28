//
//  CameraManager.swift
//  PulseSwift
//
//  Created by Brennen Otersen on 7/24/25.
//

import Foundation
import AVFoundation
import UIKit

@MainActor 
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isFlashOn = false
    @Published var permissionStatus: AVAuthorizationStatus = .notDetermined
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var recordingCompletion: ((Result<URL, Error>) -> Void)?
    
    // Camera operations queue
    private let cameraQueue = DispatchQueue(label: "com.brennen.PulseSwift.camera", qos: .userInitiated)
    
    // Video recording limit (10 seconds)
    private let maxRecordingDuration: TimeInterval = 10.0
    
    // Public getter for capture session
    var session: AVCaptureSession? {
        return captureSession
    }
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            Task { @MainActor in
                self?.permissionStatus = granted ? .authorized : .denied
                
                if granted {
                    self?.startSession()
                }
            }
        }
    }
    
    nonisolated func startSession() {
        Task { @MainActor in
            guard self.permissionStatus == .authorized else { return }
            let session = self.captureSession
            
            // Always perform camera session operations on the dedicated camera queue
            self.cameraQueue.async {
                session?.startRunning()
            }
        }
    }
    
    nonisolated func stopSession() {
        Task { @MainActor in
            let session = self.captureSession
            
            // Always perform camera session operations on the dedicated camera queue
            self.cameraQueue.async {
                session?.stopRunning()
            }
        }
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    nonisolated func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        Task { @MainActor in
            let flashOn = self.isFlashOn
            let photoOutput = self.photoOutput
            
            Task.detached {
                guard let photoOutput = photoOutput else {
                    await MainActor.run {
                        completion(.failure(CameraError.photoOutputNotAvailable))
                    }
                    return
                }
                
                let settings = AVCapturePhotoSettings()
                
                // Configure flash
                if flashOn {
                    settings.flashMode = .on
                } else {
                    settings.flashMode = .off
                }
                
                photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate(completion: completion))
            }
        }
    }
    
    nonisolated func startRecording() {
        Task { @MainActor in
            guard !self.isRecording else { return }
            
            // Get the URL and movieOutput on main actor before going to background
            let outputURL = self.getTemporaryVideoURL()
            let movieOutput = self.movieOutput
            let maxDuration = self.maxRecordingDuration
            
            Task.detached { [weak self] in
                guard let movieOutput = movieOutput,
                      let self = self else { return }
                
                movieOutput.startRecording(to: outputURL, recordingDelegate: self)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isRecording = true
                    self.recordingStartTime = Date()
                    
                    // Start timer to stop recording at 10 seconds
                    self.recordingTimer = Timer.scheduledTimer(withTimeInterval: maxDuration, repeats: false) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            self?.stopRecording { _ in }
                        }
                    }
                }
            }
        }
    }
    
    nonisolated func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        Task { @MainActor in
            guard self.isRecording else { 
                completion(.failure(CameraError.notRecording))
                return 
            }
            
            self.recordingCompletion = completion
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            
            let movieOutput = self.movieOutput
            
            Task.detached {
                movieOutput?.stopRecording()
                // Completion will be called in delegate method
            }
        }
    }
    
    nonisolated func switchCamera() {
        Task { @MainActor in
            guard let captureSession = self.captureSession else { return }
            let currentPosition = self.currentCameraPosition
            let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
            
            // Perform camera configuration on the dedicated camera queue
            self.cameraQueue.async { [weak self] in
                captureSession.beginConfiguration()
                
                // Remove current input
                if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
                    captureSession.removeInput(currentInput)
                }
                
                // Add new input
                if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                   let newInput = try? AVCaptureDeviceInput(device: newDevice) {
                    captureSession.addInput(newInput)
                }
                
                captureSession.commitConfiguration()
                
                // Update UI state on main actor
                Task { @MainActor in
                    self?.currentCameraPosition = newPosition
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        guard let captureSession = captureSession else { return }
        
        captureSession.sessionPreset = .high
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }
        
        // Add photo output
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        // Add movie output
        movieOutput = AVCaptureMovieFileOutput()
        if let movieOutput = movieOutput, captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
            
            // Set max recording duration
            movieOutput.maxRecordedDuration = CMTime(seconds: maxRecordingDuration, preferredTimescale: 30)
        }
    }
    
    private func getTemporaryVideoURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoPath = documentsPath.appendingPathComponent("pulse_video_\(UUID().uuidString).mov")
        return videoPath
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        Task { @MainActor in
            self.isRecording = false
            self.recordingStartTime = nil
            
            if let completion = self.recordingCompletion {
                self.recordingCompletion = nil
                if let error = error {
                    print("Recording failed: \(error)")
                    completion(.failure(error))
                } else {
                    print("Recording completed: \(outputFileURL)")
                    completion(.success(outputFileURL))
                }
            }
        }
    }
}

// MARK: - Photo Capture Delegate

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<Data, Error>) -> Void
    
    init(completion: @escaping (Result<Data, Error>) -> Void) {
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(.failure(error))
        } else if let photoData = photo.fileDataRepresentation() {
            completion(.success(photoData))
        } else {
            completion(.failure(CameraError.photoDataNotAvailable))
        }
    }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case photoOutputNotAvailable
    case photoDataNotAvailable
    case recordingFailed
    case notRecording
    
    var errorDescription: String? {
        switch self {
        case .photoOutputNotAvailable:
            return "Photo output not available"
        case .photoDataNotAvailable:
            return "Photo data not available"
        case .recordingFailed:
            return "Recording failed"
        case .notRecording:
            return "Not currently recording"
        }
    }
} 