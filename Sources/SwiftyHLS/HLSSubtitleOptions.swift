//
//  HLSSubtitleOptions.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 nenos, inc. All rights reserved.
//

import Foundation

/// Configuration options for subtitle processing during HLS conversion.
///
/// Subtitles are extracted from the source video or provided externally,
/// converted to WebVTT format, segmented, and included in the master playlist.
public struct HLSSubtitleOptions: Sendable {
    
    /// Whether subtitle processing is enabled.
    public var enabled: Bool
    
    /// Whether to extract embedded subtitles from the source container.
    /// When true, the converter will detect and extract subtitle streams
    /// from containers like MKV, MP4, etc.
    public var extractEmbedded: Bool
    
    /// External subtitle files to include.
    /// Each entry maps a file path to its language code.
    public var externalFiles: [HLSExternalSubtitle]
    
    /// Language code for the default subtitle track.
    /// Uses ISO 639-1 (2-letter) or ISO 639-2 (3-letter) codes.
    /// If nil, no track is marked as default.
    public var defaultLanguage: String?
    
    /// Whether to process subtitles concurrently with video encoding.
    /// When true, subtitle extraction runs in parallel with video encoding.
    /// Set to false on lower-end machines to reduce resource contention.
    /// Default is true.
    public var concurrent: Bool
    
    public init(
        enabled: Bool = false,
        extractEmbedded: Bool = true,
        externalFiles: [HLSExternalSubtitle] = [],
        defaultLanguage: String? = nil,
        concurrent: Bool = true
    ) {
        self.enabled = enabled
        self.extractEmbedded = extractEmbedded
        self.externalFiles = externalFiles
        self.defaultLanguage = defaultLanguage
        self.concurrent = concurrent
    }
}

// MARK: - External Subtitle File

/// Represents an external subtitle file to be included in the HLS output.
public struct HLSExternalSubtitle: Sendable, Equatable {
    
    /// Path to the subtitle file.
    public var path: String
    
    /// ISO 639-1 or ISO 639-2 language code (e.g., "en", "es", "fra").
    public var language: String
    
    /// Human-readable name for the track (e.g., "English", "Spanish").
    /// If nil, derived from the language code.
    public var name: String?
    
    /// Whether this is a forced subtitle track.
    /// Forced subtitles are shown even when subtitles are disabled
    /// (e.g., for foreign language dialogue in an English film).
    public var isForced: Bool
    
    public init(
        path: String,
        language: String,
        name: String? = nil,
        isForced: Bool = false
    ) {
        self.path = path
        self.language = language
        self.name = name
        self.isForced = isForced
    }
}

// MARK: - Subtitle Format

/// Supported subtitle input formats.
public enum HLSSubtitleFormat: String, CaseIterable, Sendable, Identifiable {
    case srt
    case vtt
    case ass
    case ssa
    
    public var id: String { rawValue }
    
    /// File extension for the format.
    public var fileExtension: String {
        rawValue
    }
    
    /// Display name for UI.
    public var displayName: String {
        switch self {
        case .srt:
            return "SubRip (SRT)"
        case .vtt:
            return "WebVTT"
        case .ass:
            return "Advanced SubStation Alpha"
        case .ssa:
            return "SubStation Alpha"
        }
    }
    
    /// Detects format from file extension.
    public static func from(path: String) -> HLSSubtitleFormat? {
        let ext = (path as NSString).pathExtension.lowercased()
        return HLSSubtitleFormat(rawValue: ext)
    }
}
