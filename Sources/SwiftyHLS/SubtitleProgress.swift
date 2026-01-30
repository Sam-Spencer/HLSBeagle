//
//  SubtitleProgress.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 nenos, inc. All rights reserved.
//

import Foundation

/// Progress updates during subtitle processing.
public enum SubtitleProgress: Sendable {
    
    /// Subtitle processing has started.
    case started
    
    /// Detecting embedded subtitle streams in the source container.
    case detectingStreams
    
    /// Extracting and converting a subtitle track.
    /// - Parameters:
    ///   - track: The subtitle track being processed.
    ///   - current: Current track number (1-indexed).
    ///   - total: Total number of tracks to process.
    case extracting(track: HLSSubtitleTrack, current: Int, total: Int)
    
    /// Segmenting a subtitle track for HLS.
    /// - Parameter track: The subtitle track being segmented.
    case segmenting(track: HLSSubtitleTrack)
    
    /// Writing subtitle playlist file.
    /// - Parameter track: The subtitle track whose playlist is being written.
    case writingPlaylist(track: HLSSubtitleTrack)
    
    /// Subtitle processing completed successfully.
    /// - Parameter tracks: All processed subtitle tracks.
    case completed(tracks: [HLSSubtitleTrack])
    
    /// Subtitle processing failed.
    case failed(error: Error)
    
}
