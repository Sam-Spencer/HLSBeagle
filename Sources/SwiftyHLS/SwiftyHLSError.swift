//
//  SwiftyHLSError.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

import Foundation

enum SwiftyHLSError: Error, LocalizedError {
    case invalidInput
    case invalidOutput
    case ffmpegNotFound
    case ffmpegExecutionFailed
    case ffmpegExecutionCancelled
    case unableToDetermineResolution
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid input provided to SwiftyHLS."
        case .invalidOutput:
            return "Invalid output provided to SwiftyHLS."
        case .ffmpegNotFound:
            return "ffmpeg executable not found. Please install ffmpeg and ensure it is in your PATH."
        case .ffmpegExecutionFailed:
            return "ffmpeg execution failed."
        case .ffmpegExecutionCancelled:
            return "ffmpeg execution was cancelled."
        case .unableToDetermineResolution:
            return "Unable to determine resolution of input file."
        }
    }
}
