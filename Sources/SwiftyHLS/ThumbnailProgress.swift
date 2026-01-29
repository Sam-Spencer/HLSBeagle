//
//  ThumbnailProgress.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 nenos, inc. All rights reserved.
//

import Foundation

/// Progress updates during thumbnail generation.
public enum ThumbnailProgress: Sendable {
    
    /// Thumbnail generation has started.
    case started
    
    /// Extracting individual frames from the video.
    /// - Parameters:
    ///   - current: Current frame being extracted (1-indexed).
    ///   - total: Total number of frames to extract.
    case extractingFrames(current: Int, total: Int)
    
    /// Assembling extracted frames into a sprite sheet.
    case assemblingSprite
    
    /// Writing the WebVTT file.
    case writingVTT
    
    /// Thumbnail generation completed successfully.
    /// - Parameters:
    ///   - spritePath: Path to the generated sprite sheet image.
    ///   - vttPath: Path to the generated WebVTT file.
    case completed(spritePath: String, vttPath: String)
    
    /// Thumbnail generation failed.
    case failed(error: Error)
    
}
