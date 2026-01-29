//
//  ConversionProgress.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

import Foundation

public enum ConversionProgress: Sendable {
    
    case started
    
    /// Message from FFmpeg output
    case encoding(output: String)
    
    /// Percentage completion (if estimable)
    case progress(progress: Double, resolution: HLSResolution)
    
    /// Thumbnail generation progress
    case thumbnails(ThumbnailProgress)
    
    case completedSuccessfully
    
    case failed(error: Error)
    
}
