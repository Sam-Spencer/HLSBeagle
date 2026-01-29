//
//  ThumbnailGenerator.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 nenos, inc. All rights reserved.
//

import Foundation

/// Generates seek preview thumbnails as a sprite sheet with WebVTT metadata.
public final class ThumbnailGenerator: Sendable {
    
    // MARK: - Public API
    
    /// Generates thumbnails for a video file.
    ///
    /// Extracts frames at the configured interval, assembles them into a sprite sheet,
    /// and generates a WebVTT file for player integration.
    ///
    /// - Parameters:
    ///   - inputPath: Path to the source video file.
    ///   - outputDirectory: Directory to write the sprite sheet and VTT file.
    ///   - options: Thumbnail generation options.
    ///   - videoDuration: Total duration of the video in seconds.
    ///   - videoWidth: Width of the source video in pixels.
    ///   - videoHeight: Height of the source video in pixels.
    /// - Returns: An async stream of progress updates.
    public func generateThumbnails(
        inputPath: String,
        outputDirectory: URL,
        options: HLSThumbnailOptions,
        videoDuration: TimeInterval,
        videoWidth: Int,
        videoHeight: Int
    ) -> AsyncStream<ThumbnailProgress> {
        return AsyncStream { (continuation: AsyncStream<ThumbnailProgress>.Continuation) in
            Task { @Sendable in
                do {
                    continuation.yield(.started)
                    
                    // Calculate thumbnail dimensions preserving aspect ratio
                    let aspectRatio = Double(videoHeight) / Double(videoWidth)
                    let thumbWidth = options.width
                    let thumbHeight = Int(Double(thumbWidth) * aspectRatio)
                    
                    // Calculate total frames to extract
                    let frameCount = Int(videoDuration / options.interval)
                    guard frameCount > 0 else {
                        continuation.yield(.failed(error: SwiftyHLSError.invalidVideoMetadata))
                        continuation.finish()
                        return
                    }
                    
                    // Create temp directory for individual frames
                    let tempDirectory = FileManager.default.temporaryDirectory
                        .appendingPathComponent("SwiftyHLS_thumbs_\(UUID().uuidString)")
                    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                    
                    defer {
                        try? FileManager.default.removeItem(at: tempDirectory)
                    }
                    
                    // Extract frames
                    try await extractFrames(
                        inputPath: inputPath,
                        outputDirectory: tempDirectory,
                        options: options,
                        videoDuration: videoDuration,
                        thumbWidth: thumbWidth,
                        thumbHeight: thumbHeight,
                        frameCount: frameCount,
                        continuation: continuation
                    )
                    
                    // Check for cancellation
                    try Task.checkCancellation()
                    
                    // Assemble sprite sheet
                    continuation.yield(.assemblingSprite)
                    let spritePath = outputDirectory.appendingPathComponent("thumbnails.\(options.format.fileExtension)")
                    try await assembleSpriteSheet(
                        framesDirectory: tempDirectory,
                        outputPath: spritePath,
                        options: options,
                        frameCount: frameCount,
                        thumbWidth: thumbWidth,
                        thumbHeight: thumbHeight
                    )
                    
                    // Check for cancellation
                    try Task.checkCancellation()
                    
                    // Generate VTT file
                    continuation.yield(.writingVTT)
                    let vttPath = outputDirectory.appendingPathComponent("thumbnails.vtt")
                    try generateVTTFile(
                        outputPath: vttPath,
                        spriteFilename: "thumbnails.\(options.format.fileExtension)",
                        options: options,
                        frameCount: frameCount,
                        thumbWidth: thumbWidth,
                        thumbHeight: thumbHeight,
                        videoDuration: videoDuration
                    )
                    
                    continuation.yield(.completed(spritePath: spritePath.path, vttPath: vttPath.path))
                    continuation.finish()
                    
                } catch is CancellationError {
                    continuation.yield(.failed(error: SwiftyHLSError.ffmpegExecutionCancelled))
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(error: error))
                    continuation.finish()
                }
            }
        }
    }
    
    // MARK: - Frame Extraction
    
    private func extractFrames(
        inputPath: String,
        outputDirectory: URL,
        options: HLSThumbnailOptions,
        videoDuration: TimeInterval,
        thumbWidth: Int,
        thumbHeight: Int,
        frameCount: Int,
        continuation: AsyncStream<ThumbnailProgress>.Continuation
    ) async throws {
        // Extract frames at each interval using seek-before-input for speed
        for frameIndex in 0..<frameCount {
            try Task.checkCancellation()
            
            let timestamp = Double(frameIndex) * options.interval
            let outputPath = outputDirectory.appendingPathComponent(
                String(format: "thumb_%04d.\(options.format.fileExtension)", frameIndex)
            )
            
            continuation.yield(.extractingFrames(current: frameIndex + 1, total: frameCount))
            
            try await extractSingleFrame(
                inputPath: inputPath,
                outputPath: outputPath,
                timestamp: timestamp,
                width: thumbWidth,
                height: thumbHeight,
                format: options.format
            )
        }
    }
    
    private func extractSingleFrame(
        inputPath: String,
        outputPath: URL,
        timestamp: TimeInterval,
        width: Int,
        height: Int,
        format: HLSThumbnailFormat
    ) async throws {
        let process = try VideoConverter.ffmpegProcess()
        
        var arguments: [String] = []
        
        // Seek before input for fast keyframe-based seeking
        arguments.append(contentsOf: ["-ss", String(format: "%.3f", timestamp)])
        arguments.append(contentsOf: ["-i", inputPath])
        
        // Extract single frame
        arguments.append(contentsOf: ["-frames:v", "1"])
        
        // Scale to thumbnail size
        arguments.append(contentsOf: ["-vf", "scale=\(width):\(height)"])
        
        // Format-specific options
        if format == .jpeg {
            arguments.append(contentsOf: ["-q:v", "2"]) // High quality JPEG
        } else if format == .webp {
            arguments.append(contentsOf: ["-quality", "80"])
        }
        
        // Overwrite output
        arguments.append("-y")
        arguments.append(outputPath.path)
        
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("Frame extraction failed: \(errorMessage)")
            throw SwiftyHLSError.ffmpegExecutionFailed
        }
    }
    
    // MARK: - Sprite Sheet Assembly
    
    private func assembleSpriteSheet(
        framesDirectory: URL,
        outputPath: URL,
        options: HLSThumbnailOptions,
        frameCount: Int,
        thumbWidth: Int,
        thumbHeight: Int
    ) async throws {
        let process = try VideoConverter.ffmpegProcess()
        
        // Calculate grid dimensions
        let columns = options.spriteColumns
        let rows = Int(ceil(Double(frameCount) / Double(columns)))
        
        // Build input pattern
        let inputPattern = framesDirectory.appendingPathComponent(
            "thumb_%04d.\(options.format.fileExtension)"
        ).path
        
        var arguments: [String] = []
        arguments.append(contentsOf: ["-i", inputPattern])
        
        // Tile filter to create sprite grid
        arguments.append(contentsOf: ["-filter_complex", "tile=\(columns)x\(rows)"])
        
        // Format-specific quality settings
        if options.format == .jpeg {
            arguments.append(contentsOf: ["-q:v", "2"])
        } else if options.format == .webp {
            arguments.append(contentsOf: ["-quality", "80"])
        }
        
        // Overwrite output
        arguments.append("-y")
        arguments.append(outputPath.path)
        
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("Sprite assembly failed: \(errorMessage)")
            throw SwiftyHLSError.ffmpegExecutionFailed
        }
        
        logger.trace("Created sprite sheet: \(outputPath.path)")
    }
    
    // MARK: - VTT Generation
    
    private func generateVTTFile(
        outputPath: URL,
        spriteFilename: String,
        options: HLSThumbnailOptions,
        frameCount: Int,
        thumbWidth: Int,
        thumbHeight: Int,
        videoDuration: TimeInterval
    ) throws {
        var vttContent = "WEBVTT\n\n"
        
        let columns = options.spriteColumns
        
        for frameIndex in 0..<frameCount {
            // Calculate time range for this thumbnail
            let startTime = Double(frameIndex) * options.interval
            let endTime = min(startTime + options.interval, videoDuration)
            
            // Calculate position in sprite grid
            let column = frameIndex % columns
            let row = frameIndex / columns
            let x = column * thumbWidth
            let y = row * thumbHeight
            
            // Format timestamps as HH:MM:SS.mmm
            let startFormatted = formatVTTTimestamp(startTime)
            let endFormatted = formatVTTTimestamp(endTime)
            
            // Write cue
            vttContent += "\(startFormatted) --> \(endFormatted)\n"
            vttContent += "\(spriteFilename)#xywh=\(x),\(y),\(thumbWidth),\(thumbHeight)\n\n"
        }
        
        try vttContent.write(to: outputPath, atomically: true, encoding: .utf8)
        logger.trace("Created VTT file: \(outputPath.path)")
    }
    
    private func formatVTTTimestamp(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
    }
    
}
