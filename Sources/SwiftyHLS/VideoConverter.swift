//
//  VideoConverter.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

import Foundation

public class VideoConverter {
    
    // MARK: - Conversion
    
    /// Converts an input video to a given output format using FFmpeg.
    ///
    public func convertVideo(
        inputPath: String,
        outputPath: String,
        options: HLSParameters,
        excludeResolutions: [HLSResolution] = []
    ) -> AsyncStream<ConversionProgress> {
        return AsyncStream { continuation in
            Task {
                do {
                    let installManager = InstallManager()
                    guard installManager.isFFmpegInstalled() else {
                        installManager.installFFmpeg()
                        continuation.yield(.failed(error: SwiftyHLSError.ffmpegNotFound))
                        continuation.finish()
                        return
                    }
                    
                    let ffmpegExecutable = installManager.ffmpegPath()
                    if ffmpegExecutable.isEmpty || !FileManager.default.fileExists(atPath: ffmpegExecutable) {
                        continuation.yield(.failed(error: SwiftyHLSError.ffmpegNotFound))
                        continuation.finish()
                        return
                    }
                    
                    // Ensure the output path includes a valid filename
                    let outputDirectory = URL(fileURLWithPath: outputPath)
                    var variantPlaylists: [String] = []
                    
                    // Get input resolution
                    let (inputWidth, inputHeight, inputDuration) = try VideoProcessor.getVideoResolution(
                        inputPath: inputPath
                    )
                    
                    // Filter available resolutions to avoid upscaling
                    let excludedResolutionValues = excludeResolutions.map(\.resolution)
                    let availableResolutions = HLSResolution.resolutions
                        .filter {
                            $0.width <= inputWidth && $0.height <= inputHeight
                        }
                        .filter { availableResolution in
                            !excludedResolutionValues.contains { excludedResolution in
                                excludedResolution.width == availableResolution.width
                                && excludedResolution.height == availableResolution.height
                            }
                        }
                    logger.trace("Generating HLS streams for \(availableResolutions.count) resolutions: \(availableResolutions.map(\.width))")
                    
                    // Setup encoder
                    let encoder = VideoConverter.bestAvailableEncoder(
                        preferredEncoder: options.preferredEncoder,
                        encodeFormat: options.videoEncodingFormat
                    )
                    logger.trace("Using FFmpeg encoder: \(encoder.ffmpegName)")
                    
                    continuation.yield(.started)
                    
                    // Generate streams for each HLS resolution
                    for resolution in availableResolutions {
                        await VideoConverter.generateResolutionStream(
                            from: resolution,
                            inputPath: inputPath,
                            outputDirectory: outputDirectory,
                            encoder: encoder,
                            options: options,
                            totalDuration: inputDuration,
                            continuation: continuation
                        )
                        
                        let variantStream = "variant_\(resolution.height)p.m3u8"
                        logger.trace("Generated variant stream: \(variantStream)")
                        variantPlaylists.append(variantStream)
                    }
                    
                    // Create the master playlist (.m3u8)
                    try await VideoConverter.createMasterPlaylist(
                        outputDirectory: outputDirectory,
                        variantPlaylists: variantPlaylists
                    )
                    continuation.yield(.completedSuccessfully)
                    continuation.finish()
                } catch {
                    continuation.yield(.failed(error: error))
                    continuation.finish()
                }
            }
        }
    }
    
    private static func generateResolutionStream(
        from resolution: Resolution,
        inputPath: String,
        outputDirectory: URL,
        encoder: HLSEncoders,
        options: HLSParameters,
        totalDuration: TimeInterval,
        continuation: AsyncStream<ConversionProgress>.Continuation
    ) async {
        do {
            let variantFileName = "variant_\(resolution.height)p.m3u8"
            let variantOutputFile = outputDirectory.appendingPathComponent(variantFileName).path
            
            let process = try VideoConverter.ffmpegProcess()
            var processArguments: [String] = []
            
            // Input file
            processArguments.append(contentsOf: ["-i", inputPath])
            
            // Encode video with H.264 or H.265
            processArguments.append(contentsOf: ["-c:v", encoder.ffmpegName])
            
            // Use a slower but more efficient preset
            processArguments.append(contentsOf: ["-preset", options.encodingPreset.ffmpegName])
            
            // Keyframe alignment for ABR streaming
            // GOP size of 48 frames (~2s at 24fps) ensures segments align across resolutions
            processArguments.append(contentsOf: ["-g", "48"])
            processArguments.append(contentsOf: ["-keyint_min", "48"])
            processArguments.append(contentsOf: ["-sc_threshold", "0"])
            
            // VBV rate control: maxrate caps bitrate, bufsize controls variability
            processArguments.append(contentsOf: ["-maxrate", "\(resolution.bitrateKbps)k"])
            processArguments.append(contentsOf: ["-bufsize", "\(resolution.bitrateKbps * 2)k"])
            
            // Size the video
            processArguments.append(contentsOf: [
                "-vf",
                "scale=w=\(resolution.width):h=\(resolution.height):force_original_aspect_ratio=decrease"
            ])
            
            // CRF value based on quality preset and encoding format
            let crf = options.videoEncodingFormat == .h265 ? options.qualityPreset.crfH265 : options.qualityPreset.crfH264
            processArguments.append(contentsOf: ["-crf", "\(crf)"])
            
            // Audio codec
            processArguments.append(contentsOf: ["-c:a", options.audioCodec.ffmpegName])
            
            // Audio bitrate
            processArguments.append(contentsOf: ["-b:a", options.audioBitrate.ffmpegName])
            
            // Force HLS format
            processArguments.append(contentsOf: ["-f", "hls"])
            
            // Mark playlists as VOD and ensure segments start with keyframes
            processArguments.append(contentsOf: ["-hls_playlist_type", "vod"])
            processArguments.append(contentsOf: ["-hls_flags", "independent_segments"])

            // Segment duration in seconds
            processArguments.append(contentsOf: ["-hls_time", "\(options.targetDuration)"])

            // Start segment numbering at the configured value
            processArguments.append(contentsOf: ["-start_number", "\(options.startNumber)"])
            
            // Keep all segments
            processArguments.append(contentsOf: ["-hls_list_size", "0"])

            // Optimize for progressive playback when muxing
            processArguments.append(contentsOf: ["-movflags", "+faststart"])
            
            // Segments naming pattern
            processArguments.append(contentsOf: [
                "-hls_segment_filename",
                outputDirectory.appendingPathComponent("segment_\(resolution.height)p_%03d.ts").path
            ])
            
            // Output .m3u8 playlist
            processArguments.append(contentsOf: [variantOutputFile])
            
            // Finalize the process arguments and create the pipe
            process.arguments = processArguments
            let pipe = try VideoConverter.ffmpegPipe(using: process)
            
            // Process FFmpeg logs asynchronously and report updates
            let outputTask = Task.detached(priority: .utility) {
                for try await line in pipe.fileHandleForReading.bytes.lines {
                    if let progress = await VideoConverter.parseFFmpegProgress(line: line, totalDuration: totalDuration) {
                        logger.trace("FFmpeg progress for \(resolution.width)px video (\(totalDuration)s): \(progress)")
                        continuation.yield(.progress(
                            progress: progress,
                            resolution: HLSResolution.resolution(for: resolution.width) ?? .resolution1080p
                        ))
                    }
                    continuation.yield(.encoding(output: line))
                }
            }
            
            try process.run()
            
            // Check for task cancellation
            await withTaskCancellationHandler {
                process.waitUntilExit() // Block and wait for process to exit
            } onCancel: {
                logger.info("Terminating task due to cancellation...")
                process.terminate() // Terminate process if task is cancelled
                continuation.yield(.failed(error: SwiftyHLSError.ffmpegExecutionCancelled))
                continuation.finish()
            }
            
            try await outputTask.value
        } catch {
            continuation.yield(.failed(error: error))
            continuation.finish()
        }
        
    }
    
    private static func parseFFmpegProgress(line: String, totalDuration: Double) async -> Double? {
        let timePattern = #"time=(\d+):(\d+):(\d+\.\d+)"#
        
        guard let match = try? NSRegularExpression(pattern: timePattern)
            .firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let hRange = Range(match.range(at: 1), in: line),
              let mRange = Range(match.range(at: 2), in: line),
              let sRange = Range(match.range(at: 3), in: line) else {
            return nil
        }
        
        let hours = Double(line[hRange]) ?? 0
        let minutes = Double(line[mRange]) ?? 0
        let seconds = Double(line[sRange]) ?? 0
        let currentTime = (hours * 3600) + (minutes * 60) + seconds
        
        return (currentTime / totalDuration) * 100
    }
    
    private static func createMasterPlaylist(outputDirectory: URL, variantPlaylists: [String]) async throws {
        let masterPlaylistPath = outputDirectory.appendingPathComponent("master.m3u8").path
        var masterContent = "#EXTM3U\n"
        
        for variant in variantPlaylists {
            let resolution = variant.replacingOccurrences(of: "variant_", with: "").replacingOccurrences(of: ".m3u8", with: "")
            let height = resolution.replacingOccurrences(of: "p", with: "")
            
            if let res = HLSResolution.resolutions.first(where: { "\($0.height)" == height }) {
                masterContent += """
                #EXT-X-STREAM-INF:BANDWIDTH=\(res.bitrateKbps * 1000),RESOLUTION=\(res.width)x\(res.height)
                \(variant)\n
                """
            }
        }
        
        try masterContent.write(toFile: masterPlaylistPath, atomically: true, encoding: .utf8)
        logger.trace("Created master playlist: \(masterPlaylistPath)")
    }
    
    // MARK: - Shell Configuration
    
    internal static func ffmpegProcess() throws -> Process {
        let ffmpegExecutable = InstallManager().ffmpegPath()
        if ffmpegExecutable.isEmpty || !FileManager.default.fileExists(atPath: ffmpegExecutable) {
            throw SwiftyHLSError.ffmpegNotFound
        }
        
        logger.trace("Using FFmpeg at \(ffmpegExecutable)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegExecutable)
        
        return process
    }
    
    private static func ffmpegPipe(using process: Process) throws -> Pipe {
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        return pipe
    }
    
    // MARK: - Encoders
    
    /// Checks if an FFmpeg encoder is available on the system.
    ///
    private static func isFFmpegEncoderAvailable(_ encoder: HLSEncoders) -> Bool {
        guard let process = try? VideoConverter.ffmpegProcess() else { return false }
        process.arguments = ["-encoders"]
        
        guard let pipe = try? VideoConverter.ffmpegPipe(using: process) else { return false }
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8) {
                return output.contains(encoder.ffmpegName)
            }
        } catch {
            return false
        }
        
        return false
    }

    /// Validates that an encoder can actually encode a tiny test frame.
    private static func isFFmpegEncoderFunctional(_ encoder: HLSEncoders) -> Bool {
        guard let process = try? VideoConverter.ffmpegProcess() else { return false }
        process.arguments = [
            "-hide_banner",
            "-loglevel",
            "error",
            "-f",
            "lavfi",
            "-i",
            "color=c=black:s=16x16:d=0.1",
            "-frames:v",
            "1",
            "-c:v",
            encoder.ffmpegName,
            "-f",
            "null",
            "-"
        ]

        guard let _ = try? VideoConverter.ffmpegPipe(using: process) else { return false }
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private static func isFFmpegEncoderSupported(_ encoder: HLSEncoders) -> Bool {
        guard isFFmpegEncoderAvailable(encoder) else { return false }
        return isFFmpegEncoderFunctional(encoder)
    }
    
    /// Determines the best available encoder for the system.
    ///
    private static func bestAvailableEncoder(
        preferredEncoder: HLSEncoders?,
        encodeFormat: HLSVideoEncodingFormat
    ) -> HLSEncoders {
        if let userPreferred = preferredEncoder {
            return userPreferred // Use the user-defined encoder if set
        }
        
        // Check for HEVC (H.265) Encoders first if preferred
        if encodeFormat == .h265 {
#if arch(arm64) // Apple Silicon (M1, M2, etc.)
            if isFFmpegEncoderSupported(.h265HardwareAccelerated) {
                return .h265HardwareAccelerated
            }
#elseif arch(x86_64) // Intel Macs
            if isFFmpegEncoderSupported(.h265QuickSync) {
                return .h265QuickSync
            }
#endif
            if isFFmpegEncoderSupported(.h265SoftwareRenderer) {
                return .h265SoftwareRenderer
            }
        }
        
        // Fallback to H.264 if HEVC isn't available or not preferred
#if arch(arm64) // Apple Silicon (M1, M2, etc.)
        if isFFmpegEncoderSupported(.h264HardwareAccelerated) {
            return .h264HardwareAccelerated
        }
#elseif arch(x86_64) // Intel Macs
        if isFFmpegEncoderSupported(.h264QuickSync) {
            return .h264QuickSync
        }
#endif
        
        return .h264SoftwareRenderer // Fallback to software encoding
    }
    
    // MARK: - Cleanup
    
    public static func cleanup(outputDirectory: String, finished: @escaping () -> Void) {
        let fileManager = FileManager.default
        let outputURL = URL(fileURLWithPath: outputDirectory)
        
        do {
            let filePaths = try fileManager.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: nil)
            
            for filePath in filePaths {
                try fileManager.removeItem(at: filePath)
            }
            
            logger.trace("Successfully cleaned up output directory: \(outputDirectory)")
            finished()
        } catch {
            logger.error("Failed to clean up output directory: \(error.localizedDescription)")
            finished()
        }
    }
    
}
