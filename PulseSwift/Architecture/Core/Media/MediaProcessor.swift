import Foundation
import UIKit
import AVFoundation
import Combine

// MARK: - Media Processor (Production-Ready)
protocol MediaProcessorProtocol {
    func processImage(_ imageData: Data, for purpose: MediaPurpose) async throws -> ProcessedMedia
    func processVideo(_ videoURL: URL, for purpose: MediaPurpose) async throws -> ProcessedMedia
    func generateThumbnail(from videoURL: URL) async throws -> UIImage
    func compressImage(_ image: UIImage, quality: MediaQuality) async throws -> Data
    func optimizeVideo(_ videoURL: URL, quality: MediaQuality) async throws -> URL
}

final class MediaProcessor: MediaProcessorProtocol {
    
    // MARK: - Configuration
    private let processingQueue = DispatchQueue(label: "com.pulse.media.processing", qos: .userInitiated)
    private let thumbnailQueue = DispatchQueue(label: "com.pulse.media.thumbnail", qos: .utility)
    
    // MARK: - Cache
    private let cache = MediaCache()
    
    // MARK: - Quality Settings
    private let qualitySettings: [MediaQuality: QualityConfiguration] = [
        .thumbnail: QualityConfiguration(
            imageCompression: 0.3,
            maxImageSize: CGSize(width: 150, height: 150),
            videoPreset: AVAssetExportPresetLowQuality,
            maxVideoDuration: 10.0
        ),
        .low: QualityConfiguration(
            imageCompression: 0.5,
            maxImageSize: CGSize(width: 480, height: 640),
            videoPreset: AVAssetExportPresetLowQuality,
            maxVideoDuration: 30.0
        ),
        .medium: QualityConfiguration(
            imageCompression: 0.7,
            maxImageSize: CGSize(width: 720, height: 1280),
            videoPreset: AVAssetExportPresetMediumQuality,
            maxVideoDuration: 30.0
        ),
        .high: QualityConfiguration(
            imageCompression: 0.85,
            maxImageSize: CGSize(width: 1080, height: 1920),
            videoPreset: AVAssetExportPreset1920x1080,
            maxVideoDuration: 30.0
        ),
        .original: QualityConfiguration(
            imageCompression: 0.95,
            maxImageSize: CGSize(width: 4000, height: 6000),
            videoPreset: AVAssetExportPresetHEVCHighestQuality,
            maxVideoDuration: 60.0
        )
    ]
    
    init() {
        print("✅ MediaProcessor: Initialized with quality settings")
    }
    
    // MARK: - Public Methods
    func processImage(_ imageData: Data, for purpose: MediaPurpose) async throws -> ProcessedMedia {
        let cacheKey = generateCacheKey(data: imageData, purpose: purpose)
        
        // Check cache first
        if let cachedMedia = await cache.get(for: cacheKey) {
            print("✅ MediaProcessor: Using cached image for \(purpose)")
            return cachedMedia
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let result = try self.performImageProcessing(imageData, for: purpose)
                    
                    // Cache the result
                    Task {
                        await self.cache.set(result, for: cacheKey)
                    }
                    
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func processVideo(_ videoURL: URL, for purpose: MediaPurpose) async throws -> ProcessedMedia {
        let cacheKey = generateCacheKey(url: videoURL, purpose: purpose)
        
        // Check cache first
        if let cachedMedia = await cache.get(for: cacheKey) {
            print("✅ MediaProcessor: Using cached video for \(purpose)")
            return cachedMedia
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                Task {
                    do {
                        let result = try await self.performVideoProcessing(videoURL, for: purpose)
                        
                        // Cache the result
                        await self.cache.set(result, for: cacheKey)
                        
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    func generateThumbnail(from videoURL: URL) async throws -> UIImage {
        return try await createVideoThumbnail(from: videoURL)
    }
    
    func compressImage(_ image: UIImage, quality: MediaQuality) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let compressedData = try self.performImageCompression(image, quality: quality)
                    continuation.resume(returning: compressedData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func optimizeVideo(_ videoURL: URL, quality: MediaQuality) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                do {
                    let optimizedURL = try await self.performVideoOptimization(videoURL, quality: quality)
                    continuation.resume(returning: optimizedURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Image Processing
    private func performImageProcessing(_ imageData: Data, for purpose: MediaPurpose) throws -> ProcessedMedia {
        guard let image = UIImage(data: imageData) else {
            throw MediaError.invalidImageData
        }
        
        let quality = purpose.recommendedQuality
        let config = qualitySettings[quality]!
        
        // Resize image if needed
        let resizedImage = try resizeImage(image, to: config.maxImageSize)
        
        // Compress image
        let compressedData = try performImageCompression(resizedImage, quality: quality)
        
        // Generate metadata
        let metadata = MediaMetadata(
            originalSize: image.size,
            processedSize: resizedImage.size,
            compressionRatio: Double(imageData.count) / Double(compressedData.count),
            duration: nil,
            format: .jpeg
        )
        
        print("✅ MediaProcessor: Image processed - \(imageData.count) bytes → \(compressedData.count) bytes")
        
        return ProcessedMedia(
            data: compressedData,
            url: nil,
            type: .image,
            quality: quality,
            metadata: metadata
        )
    }
    
    private func performImageCompression(_ image: UIImage, quality: MediaQuality) throws -> Data {
        let config = qualitySettings[quality]!
        
        guard let compressedData = image.jpegData(compressionQuality: config.imageCompression) else {
            throw MediaError.compressionFailed
        }
        
        return compressedData
    }
    
    private func resizeImage(_ image: UIImage, to maxSize: CGSize) throws -> UIImage {
        let currentSize = image.size
        
        // Calculate new size maintaining aspect ratio
        let widthRatio = maxSize.width / currentSize.width
        let heightRatio = maxSize.height / currentSize.height
        let ratio = min(widthRatio, heightRatio)
        
        // Don't upscale
        if ratio >= 1.0 {
            return image
        }
        
        let newSize = CGSize(
            width: currentSize.width * ratio,
            height: currentSize.height * ratio
        )
        
        // Create resized image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    // MARK: - Private Video Processing
    private func performVideoProcessing(_ videoURL: URL, for purpose: MediaPurpose) async throws -> ProcessedMedia {
        let quality = purpose.recommendedQuality
        let config = qualitySettings[quality]!
        
        let asset = AVURLAsset(url: videoURL)
        
        // Get video duration
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        // Trim video if too long
        let trimmedAsset = try await trimVideoIfNeeded(asset, maxDuration: config.maxVideoDuration)
        
        // Compress video
        let compressedURL = try await compressVideo(trimmedAsset, preset: config.videoPreset)
        
        // Get file sizes
        let originalSize = try getFileSize(at: videoURL)
        let compressedSize = try getFileSize(at: compressedURL)
        
        // Generate metadata
        let metadata = MediaMetadata(
            originalSize: nil,
            processedSize: nil,
            compressionRatio: Double(originalSize) / Double(compressedSize),
            duration: min(durationInSeconds, config.maxVideoDuration),
            format: .mp4
        )
        
        print("✅ MediaProcessor: Video processed - \(originalSize) bytes → \(compressedSize) bytes")
        
        // Get compressed data
        let compressedData = try Data(contentsOf: compressedURL)
        
        return ProcessedMedia(
            data: compressedData,
            url: compressedURL,
            type: .video,
            quality: quality,
            metadata: metadata
        )
    }
    
    private func trimVideoIfNeeded(_ asset: AVAsset, maxDuration: TimeInterval) async throws -> AVAsset {
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        if durationInSeconds <= maxDuration {
            return asset
        }
        
        // Create trimmed asset
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first
        let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first
        
        let timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: maxDuration, preferredTimescale: 600))
        
        if let assetVideoTrack = assetVideoTrack {
            try videoTrack?.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)
        }
        
        if let assetAudioTrack = assetAudioTrack {
            try audioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
        }
        
        return composition
    }
    
    private func compressVideo(_ asset: AVAsset, preset: String) async throws -> URL {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw MediaError.exportSessionCreationFailed
        }
        
        let outputURL = generateTemporaryURL(with: "mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        // iOS 18+ modern async API
        if #available(iOS 18.0, *) {
            do {
                try await exportSession.export(to: outputURL, as: .mp4)
                return outputURL
            } catch {
                throw MediaError.exportFailed
            }
        } else {
            // Fallback for iOS 17 and earlier
            return try await withCheckedThrowingContinuation { continuation in
                // Use a weak reference to exportSession to avoid capturing it strongly in the closure
                exportSession.exportAsynchronously { [outputURL] in
                    DispatchQueue.main.async {
                        let status = exportSession.status
                        let error = exportSession.error
                        switch status {
                        case .completed:
                            continuation.resume(returning: outputURL)
                        case .failed:
                            continuation.resume(throwing: error ?? MediaError.exportFailed)
                        case .cancelled:
                            continuation.resume(throwing: MediaError.exportCancelled)
                        default:
                            continuation.resume(throwing: MediaError.exportFailed)
                        }
                    }
                }
            }
        }
    }
    
    private func createVideoThumbnail(from videoURL: URL) async throws -> UIImage {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        
        do {
            let cgImage: CGImage
            if #available(iOS 16.0, *) {
                // iOS 16+ async API
                let (cgImageResult, _) = try await imageGenerator.image(at: time)
                cgImage = cgImageResult
            } else {
                // Fallback for iOS 15 and earlier
                cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            }
            return UIImage(cgImage: cgImage)
        } catch {
            throw MediaError.thumbnailGenerationFailed
        }
    }
    
    private func performVideoOptimization(_ videoURL: URL, quality: MediaQuality) async throws -> URL {
        let config = qualitySettings[quality]!
        let asset = AVURLAsset(url: videoURL)
        
        return try await compressVideo(asset, preset: config.videoPreset)
    }
    
    // MARK: - Utility Methods
    private func generateCacheKey(data: Data, purpose: MediaPurpose) -> String {
        let dataHash = data.sha256
        return "\(purpose.rawValue)_\(dataHash)"
    }
    
    private func generateCacheKey(url: URL, purpose: MediaPurpose) -> String {
        let urlHash = url.absoluteString.sha256
        return "\(purpose.rawValue)_\(urlHash)"
    }
    
    private func generateTemporaryURL(with fileExtension: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = UUID().uuidString + "." + fileExtension
        return tempDir.appendingPathComponent(fileName)
    }
    
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
}

// MARK: - Media Cache
private actor MediaCache {
    private var cache: [String: ProcessedMedia] = [:]
    private let maxCacheSize = 100 * 1024 * 1024 // 100MB
    private var currentCacheSize = 0
    
    func get(for key: String) -> ProcessedMedia? {
        return cache[key]
    }
    
    func set(_ media: ProcessedMedia, for key: String) {
        // Remove if already exists
        if let existing = cache[key] {
            currentCacheSize -= existing.data.count
        }
        
        // Add new media
        cache[key] = media
        currentCacheSize += media.data.count
        
        // Clean cache if needed
        cleanCacheIfNeeded()
    }
    
    private func cleanCacheIfNeeded() {
        guard currentCacheSize > maxCacheSize else { return }
        
        // Simple LRU-like cleanup - remove random items
        let keysToRemove = Array(cache.keys).prefix(cache.count / 4)
        
        for key in keysToRemove {
            if let media = cache.removeValue(forKey: key) {
                currentCacheSize -= media.data.count
            }
        }
        
        print("🧹 MediaCache: Cleaned cache, new size: \(currentCacheSize) bytes")
    }
}

// MARK: - Supporting Types
enum MediaPurpose: String, CaseIterable {
    case profile = "profile"
    case story = "story"
    case message = "message"
    case thumbnail = "thumbnail"
    case export = "export"
    
    var recommendedQuality: MediaQuality {
        switch self {
        case .profile:
            return .medium
        case .story:
            return .high
        case .message:
            return .medium
        case .thumbnail:
            return .thumbnail
        case .export:
            return .original
        }
    }
}

enum MediaQuality: CaseIterable {
    case thumbnail
    case low
    case medium
    case high
    case original
}

struct QualityConfiguration {
    let imageCompression: CGFloat
    let maxImageSize: CGSize
    let videoPreset: String
    let maxVideoDuration: TimeInterval
}

struct ProcessedMedia {
    let data: Data
    let url: URL?
    let type: MediaType
    let quality: MediaQuality
    let metadata: MediaMetadata
    
    enum MediaType {
        case image
        case video
    }
}

struct MediaMetadata {
    let originalSize: CGSize?
    let processedSize: CGSize?
    let compressionRatio: Double
    let duration: TimeInterval?
    let format: MediaFormat
    
    enum MediaFormat {
        case jpeg
        case png
        case mp4
        case mov
    }
}

enum MediaError: LocalizedError {
    case invalidImageData
    case compressionFailed
    case exportSessionCreationFailed
    case exportFailed
    case exportCancelled
    case thumbnailGenerationFailed
    case unsupportedFormat
    case fileSizeExceeded
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data provided."
        case .compressionFailed:
            return "Failed to compress media."
        case .exportSessionCreationFailed:
            return "Failed to create video export session."
        case .exportFailed:
            return "Video export failed."
        case .exportCancelled:
            return "Video export was cancelled."
        case .thumbnailGenerationFailed:
            return "Failed to generate video thumbnail."
        case .unsupportedFormat:
            return "Unsupported media format."
        case .fileSizeExceeded:
            return "File size exceeds maximum allowed size."
        }
    }
}

// MARK: - String Extension for Hashing
private extension String {
    var sha256: String {
        let data = self.data(using: .utf8)!
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Data Extension for Hashing
private extension Data {
    var sha256: String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

import CommonCrypto 