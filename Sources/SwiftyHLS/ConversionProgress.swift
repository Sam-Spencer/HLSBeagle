//
//  ConversionProgress.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

import Foundation

public enum ConversionProgress {
    
    case started
    
    /// Message from FFmpeg output
    case encoding(output: String)
    
    /// Percentage completion (if estimable)
    case progress(progress: Double, resolution: HLSResolution)
    
    case completedSuccessfully
    
    case failed(error: Error)
    
}
