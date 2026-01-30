//
//  SubtitleProcessor.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 nenos, inc. All rights reserved.
//

import Foundation

/// Processes subtitles for HLS output: extraction, WebVTT conversion, and segmentation.
public final class SubtitleProcessor: Sendable {
    
    // MARK: - Public API
    
    /// Processes subtitle tracks for HLS output.
    ///
    /// Extracts embedded subtitles and/or processes external subtitle files,
    /// converts them to WebVTT format, and segments them for HLS playback.
    ///
    /// - Parameters:
    ///   - inputPath: Path to the source video file (for embedded subtitles).
    ///   - outputDirectory: Directory to write subtitle segments and playlists.
    ///   - options: Subtitle processing options.
    ///   - targetDuration: Target segment duration in seconds (should match video segments).
    /// - Returns: An async stream of progress updates.
    public func processSubtitles(
        inputPath: String,
        outputDirectory: URL,
        options: HLSSubtitleOptions,
        targetDuration: Double
    ) -> AsyncStream<SubtitleProgress> {
        return AsyncStream { (continuation: AsyncStream<SubtitleProgress>.Continuation) in
            Task { @Sendable in
                do {
                    continuation.yield(.started)
                    
                    var tracks: [HLSSubtitleTrack] = []
                    
                    // Detect embedded subtitles if enabled
                    if options.extractEmbedded {
                        continuation.yield(.detectingStreams)
                        let embeddedTracks = try VideoProcessor.getSubtitleStreams(inputPath: inputPath)
                        tracks.append(contentsOf: embeddedTracks)
                        logger.trace("Found \(embeddedTracks.count) embedded subtitle tracks")
                    }
                    
                    // Add external subtitle files
                    let externalTracks = Self.createTracksFromExternalFiles(
                        options.externalFiles,
                        startingIndex: tracks.count
                    )
                    tracks.append(contentsOf: externalTracks)
                    
                    // Apply default language setting
                    if let defaultLang = options.defaultLanguage {
                        tracks = tracks.map { track in
                            var modified = track
                            modified.isDefault = track.language == defaultLang
                            return modified
                        }
                    }
                    
                    guard !tracks.isEmpty else {
                        logger.trace("No subtitle tracks to process")
                        continuation.yield(.completed(tracks: []))
                        continuation.finish()
                        return
                    }
                    
                    // Process each track
                    for (index, track) in tracks.enumerated() {
                        try Task.checkCancellation()
                        
                        continuation.yield(.extracting(track: track, current: index + 1, total: tracks.count))
                        
                        // Extract/convert and segment the subtitle
                        try await Self.processTrack(
                            track: track,
                            inputPath: inputPath,
                            outputDirectory: outputDirectory,
                            targetDuration: targetDuration,
                            continuation: continuation
                        )
                    }
                    
                    continuation.yield(.completed(tracks: tracks))
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
    
    // MARK: - Track Processing
    
    /// Creates HLSSubtitleTrack objects from external subtitle file configurations.
    private static func createTracksFromExternalFiles(
        _ files: [HLSExternalSubtitle],
        startingIndex: Int
    ) -> [HLSSubtitleTrack] {
        return files.enumerated().map { (index, file) in
            let name = file.name ?? HLSSubtitleTrack.displayName(for: file.language)
            let format = HLSSubtitleFormat.from(path: file.path)
            
            return HLSSubtitleTrack(
                index: startingIndex + index,
                language: file.language,
                name: name,
                isDefault: false,
                isForced: file.isForced,
                source: .external,
                codec: format?.rawValue,
                sourcePath: file.path
            )
        }
    }
    
    /// Processes a single subtitle track: extracts, converts to WebVTT, and segments.
    private static func processTrack(
        track: HLSSubtitleTrack,
        inputPath: String,
        outputDirectory: URL,
        targetDuration: Double,
        continuation: AsyncStream<SubtitleProgress>.Continuation
    ) async throws {
        continuation.yield(.segmenting(track: track))
        
        let process = try VideoConverter.ffmpegProcess()
        var arguments: [String] = []
        
        // Input source
        if track.source == .embedded {
            // Extract from video container
            arguments.append(contentsOf: ["-i", inputPath])
            arguments.append(contentsOf: ["-map", "0:\(track.index)"])
        } else if let sourcePath = track.sourcePath {
            // Use external file
            arguments.append(contentsOf: ["-i", sourcePath])
            arguments.append(contentsOf: ["-map", "0:s:0"])
        } else {
            throw SwiftyHLSError.invalidVideoMetadata
        }
        
        // Disable video and audio
        arguments.append("-vn")
        arguments.append("-an")
        
        // Convert to WebVTT
        arguments.append(contentsOf: ["-c:s", "webvtt"])
        
        // Use segment muxer for HLS-compatible output
        arguments.append(contentsOf: ["-f", "segment"])
        arguments.append(contentsOf: ["-segment_time", String(format: "%.0f", targetDuration)])
        arguments.append(contentsOf: ["-segment_list", outputDirectory.appendingPathComponent(track.playlistFilename).path])
        arguments.append(contentsOf: ["-segment_list_type", "m3u8"])
        
        // Output segment pattern
        let segmentPath = outputDirectory.appendingPathComponent(track.segmentPattern).path
        arguments.append(segmentPath)
        
        process.arguments = arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        logger.trace("Processing subtitle track: \(track.language) with args: \(arguments.joined(separator: " "))")
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            logger.error("Subtitle processing failed for \(track.language): \(errorMessage)")
            throw SwiftyHLSError.ffmpegExecutionFailed
        }
        
        // Post-process the playlist to add required HLS tags
        try await Self.postProcessPlaylist(
            track: track,
            outputDirectory: outputDirectory,
            targetDuration: targetDuration
        )
        
        continuation.yield(.writingPlaylist(track: track))
        logger.trace("Completed subtitle track: \(track.language)")
    }
    
    /// Post-processes the segment muxer playlist to add HLS-required tags.
    private static func postProcessPlaylist(
        track: HLSSubtitleTrack,
        outputDirectory: URL,
        targetDuration: Double
    ) async throws {
        let playlistPath = outputDirectory.appendingPathComponent(track.playlistFilename)
        
        guard let content = try? String(contentsOf: playlistPath, encoding: .utf8) else {
            logger.error("Could not read subtitle playlist: \(playlistPath.path)")
            return
        }
        
        // Add VOD playlist type and ensure proper format
        var lines = content.components(separatedBy: .newlines)
        
        // Insert playlist type after EXTM3U if not present
        if !content.contains("#EXT-X-PLAYLIST-TYPE:VOD") {
            if let extm3uIndex = lines.firstIndex(where: { $0.hasPrefix("#EXTM3U") }) {
                lines.insert("#EXT-X-PLAYLIST-TYPE:VOD", at: extm3uIndex + 1)
            }
        }
        
        // Ensure ENDLIST tag is present
        if !content.contains("#EXT-X-ENDLIST") {
            lines.append("#EXT-X-ENDLIST")
        }
        
        let updatedContent = lines.joined(separator: "\n")
        try updatedContent.write(to: playlistPath, atomically: true, encoding: .utf8)
    }
    
}
