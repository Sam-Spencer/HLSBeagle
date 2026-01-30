//
//  InstallManager.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

import Foundation

public class InstallManager {
    
    public init() { }
    
    /// Checks if `ffmpeg` is installed by running `which ffmpeg`
    ///
    public func isFFmpegInstalled() -> Bool {
        let potentialPaths = [
            "/opt/homebrew/bin/ffmpeg", // Apple Silicon (M1, M2)
            "/usr/local/bin/ffmpeg",    // Intel Macs
            "/usr/bin/ffmpeg"           // Some manual installs
        ]
        
        for path in potentialPaths {
            if FileManager.default.fileExists(atPath: path) {
                logger.info("FFmpeg found at: \(path)")
                return true
            }
        }
        
        logger.error("FFmpeg not found in known locations.")
        return false
    }
    
    /// Installs FFmpeg via Homebrew (if missing)
    ///
    public func installFFmpeg() {
        logger.trace("FFmpeg is not installed. Attempting to install via Homebrew...")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["brew", "install", "ffmpeg"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: outputData, encoding: .utf8) {
                print(output)
            }
        } catch {
            logger.error("Failed to install FFmpeg: \(error)")
        }
    }
    
    /// Finds the correct ffmpeg path dynamically
    internal func ffmpegPath() -> String {
        let potentialPaths = [
            "/opt/homebrew/bin/ffmpeg", // Apple Silicon (M1, M2)
            "/usr/local/bin/ffmpeg",    // Intel Macs
            "/usr/bin/ffmpeg"           // Manual installs
        ]
        
        for path in potentialPaths {
            if FileManager.default.fileExists(atPath: path) {
                logger.trace("FFmpeg found at: \(path)")
                return path
            }
        }
        
        logger.error("FFmpeg not found in known locations.")
        return ""
    }
    
    /// Finds the correct ffprobe path dynamically
    internal func ffprobePath() -> String {
        let potentialPaths = [
            "/opt/homebrew/bin/ffprobe", // Apple Silicon (M1, M2)
            "/usr/local/bin/ffprobe",    // Intel Macs
            "/usr/bin/ffprobe"           // Manual installs
        ]
        
        for path in potentialPaths {
            if FileManager.default.fileExists(atPath: path) {
                logger.trace("FFprobe found at: \(path)")
                return path
            }
        }
        
        logger.error("FFprobe not found in known locations.")
        return ""
    }
    
}
