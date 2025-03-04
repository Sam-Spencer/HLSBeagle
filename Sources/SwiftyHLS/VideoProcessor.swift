//
//  VideoProcessor.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//

import Foundation

public struct VideoProcessor {
    
    public static func getVideoResolution(inputPath: String) throws -> (width: Int, height: Int, duration: Double) {
        let process = try VideoConverter.ffmpegProcess()
        process.arguments = ["-i", inputPath]
        
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            throw SwiftyHLSError.ffmpegExecutionFailed
        }
        
        let resolutionPattern = #"(\d{2,4})x(\d{2,4})"#
        let durationPattern = #"Duration: (\d+):(\d+):(\d+\.\d+)"#
        
        var width = 0, height = 0, duration: Double = 0.0
        
        let resolutionRegex = try NSRegularExpression(pattern: resolutionPattern)
        if let match = resolutionRegex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
           let widthRange = Range(match.range(at: 1), in: output),
           let heightRange = Range(match.range(at: 2), in: output) {
            width = Int(output[widthRange]) ?? 0
            height = Int(output[heightRange]) ?? 0
        }
        
        if let match = try? NSRegularExpression(pattern: durationPattern).firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let hRange = Range(match.range(at: 1), in: output),
               let mRange = Range(match.range(at: 2), in: output),
               let sRange = Range(match.range(at: 3), in: output) {
                let hours = Double(output[hRange]) ?? 0
                let minutes = Double(output[mRange]) ?? 0
                let seconds = Double(output[sRange]) ?? 0
                duration = (hours * 3600) + (minutes * 60) + seconds
            }

        return (width, height, duration)
    }
    
    public static func getStandardResolution(for inputPath: String) -> HLSResolution? {
        guard let payload = try? VideoProcessor.getVideoResolution(inputPath: inputPath) else { return nil }
        return HLSResolution.resolution(for: payload.width)
    }
    
    public static func getDuration(for inputPath: String) -> Double {
        guard let payload = try? VideoProcessor.getVideoResolution(inputPath: inputPath) else { return 0 }
        return payload.duration
    }
    
    public static func resolutionOptions(at resolution: HLSResolution) -> [HLSResolution] {
        HLSResolution.resolutions.filter {
            $0.width <= resolution.resolution.width && $0.height <= resolution.resolution.height
        }
        .compactMap {
            HLSResolution.resolution(for: $0.width)
        }
    }
    
}
