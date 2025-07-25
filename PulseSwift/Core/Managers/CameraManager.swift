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
    
    var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    
    // Video recording limit (10 seconds)
    private let maxRecordingDuration: TimeInterval = 10.0
    
    override init() {
        super.init()
        setupCaptureSession()
    }
    
    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.permissionStatus = granted ? .authorized : .denied
                if granted {
                    self?.startSession()
                }
            }
        }
    }
    
    func startSession() {
        guard permissionStatus == .authorized else { return }
        captureSession?.startRunning()
    }
    
    func stopSession() {
        captureSession?.stopRunning()
    }
    
    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let photoOutput = photoOutput else {
            completion(.failure(CameraError.photoOutputNotAvailable))
            return
        }
        
        let settings = AVCapturePhotoSettings()
        
        // Configure flash
        if isFlashOn {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }
        
        photoOutput.capturePhoto(with: settings, delegate: PhotoCaptureDelegate(completion: completion))
    }
    
    func startRecording() {
        guard let movieOutput = movieOutput,
              !isRecording else { return }
        
        let outputURL = getTemporaryVideoURL()
        
        movieOutput.startRecording(to: outputURL, recordingDelegate: self)
        isRecording = true
        recordingStartTime = Date()
        
        // Start timer to stop recording at 10 seconds
        recordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stopRecording { _ in }
            }
        }
    }
    
    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording else { return }
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        movieOutput?.stopRecording()
        // Completion will be called in delegate method
    }
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    func switchCamera() {
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        // Remove current input
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(currentInput)
        }
        
        // Switch camera position
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        // Add new input
        if let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition),
           let newInput = try? AVCaptureDeviceInput(device: newDevice) {
            captureSession.addInput(newInput)
        }
        
        captureSession.commitConfiguration()
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
            isRecording = false
            recordingStartTime = nil
        }
        
        if let error = error {
            print("Recording failed: \(error)")
        } else {
            print("Recording completed: \(outputFileURL)")
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
    
    var errorDescription: String? {
        switch self {
        case .photoOutputNotAvailable:
            return "Photo output not available"
        case .photoDataNotAvailable:
            return "Photo data not available"
        case .recordingFailed:
            return "Recording failed"
        }
    }
} 