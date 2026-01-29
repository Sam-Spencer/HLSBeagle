//
//  HLSThumbnailOptions.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 nenos, inc. All rights reserved.
//

import Foundation

/// Configuration options for generating seek preview thumbnails.
///
/// Thumbnails are generated as a sprite sheet (single image containing all frames)
/// with an accompanying WebVTT file for player integration.
public struct HLSThumbnailOptions: Sendable {
    
    /// Whether thumbnail generation is enabled.
    public var enabled: Bool
    
    /// Interval between thumbnails in seconds.
    /// Default is 10 seconds.
    public var interval: TimeInterval
    
    /// Width of each thumbnail in pixels.
    /// Height is calculated automatically to preserve aspect ratio.
    /// Default is 320 pixels.
    public var width: Int
    
    /// Output format for thumbnails.
    /// Default is JPEG for best compatibility and file size.
    public var format: HLSThumbnailFormat
    
    /// Number of columns in the sprite sheet grid.
    /// Rows are calculated based on total frame count.
    /// Default is 10 columns.
    public var spriteColumns: Int
    
    /// Whether to generate thumbnails concurrently with HLS encoding.
    /// When true, thumbnail extraction runs in parallel with video encoding.
    /// Set to false on lower-end machines to reduce resource contention.
    /// Default is true.
    public var concurrent: Bool
    
    public init(
        enabled: Bool = false,
        interval: TimeInterval = 10,
        width: Int = 320,
        format: HLSThumbnailFormat = .jpeg,
        spriteColumns: Int = 10,
        concurrent: Bool = true
    ) {
        self.enabled = enabled
        self.interval = interval
        self.width = width
        self.format = format
        self.spriteColumns = spriteColumns
        self.concurrent = concurrent
    }
}

// MARK: - Thumbnail Format

/// Output format for thumbnail images.
public enum HLSThumbnailFormat: String, CaseIterable, Sendable, Identifiable {
    case jpeg
    case webp
    
    public var id: String { rawValue }
    
    /// File extension for the format.
    public var fileExtension: String {
        switch self {
        case .jpeg:
            return "jpg"
        case .webp:
            return "webp"
        }
    }
    
    /// Display name for UI.
    public var displayName: String {
        switch self {
        case .jpeg:
            return "JPEG"
        case .webp:
            return "WebP"
        }
    }
}

// MARK: - Size Presets

/// Preset sizes for thumbnail generation.
public enum HLSThumbnailSizePreset: String, CaseIterable, Sendable, Identifiable {
    case small   // 160px width
    case medium  // 320px width
    case large   // 480px width
    
    public var id: String { rawValue }
    
    /// Width in pixels for this preset.
    public var width: Int {
        switch self {
        case .small:
            return 160
        case .medium:
            return 320
        case .large:
            return 480
        }
    }
    
    /// Display name for UI.
    public var displayName: String {
        switch self {
        case .small:
            return "Small (160px)"
        case .medium:
            return "Medium (320px)"
        case .large:
            return "Large (480px)"
        }
    }
}

// MARK: - Interval Presets

/// Preset intervals for thumbnail generation.
public enum HLSThumbnailIntervalPreset: String, CaseIterable, Sendable, Identifiable {
    case frequent   // Every 5 seconds
    case standard   // Every 10 seconds
    case sparse     // Every 30 seconds
    
    public var id: String { rawValue }
    
    /// Interval in seconds.
    public var interval: TimeInterval {
        switch self {
        case .frequent:
            return 5
        case .standard:
            return 10
        case .sparse:
            return 30
        }
    }
    
    /// Display name for UI.
    public var displayName: String {
        switch self {
        case .frequent:
            return "5 seconds"
        case .standard:
            return "10 seconds"
        case .sparse:
            return "30 seconds"
        }
    }
}
