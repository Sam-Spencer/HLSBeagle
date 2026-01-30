//
//  HLSSubtitleTrack.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 nenos, inc. All rights reserved.
//

import Foundation

/// Represents a subtitle track detected in a video file or configured externally.
///
/// Used to track subtitle streams during processing and to generate
/// the master playlist with proper `#EXT-X-MEDIA:TYPE=SUBTITLES` entries.
public struct HLSSubtitleTrack: Sendable, Equatable, Identifiable {
    
    /// Unique identifier for the track.
    public var id: String {
        "\(source.rawValue)_\(index)_\(language)"
    }
    
    /// Stream index within the source container (for embedded subtitles).
    /// For external files, this is the order in which they were added.
    public var index: Int
    
    /// ISO 639-1 or ISO 639-2 language code (e.g., "en", "es", "fra").
    public var language: String
    
    /// Human-readable name for the track (e.g., "English", "Spanish").
    public var name: String
    
    /// Whether this is the default subtitle track.
    public var isDefault: Bool
    
    /// Whether this is a forced subtitle track.
    /// Forced subtitles are shown even when subtitles are disabled.
    public var isForced: Bool
    
    /// Source of the subtitle track.
    public var source: SubtitleSource
    
    /// Original codec of the subtitle (for embedded tracks).
    /// Examples: "subrip", "ass", "webvtt", "mov_text"
    public var codec: String?
    
    /// Path to the source file (for external subtitles).
    public var sourcePath: String?
    
    /// Generated playlist filename (e.g., "subtitles_en.m3u8").
    public var playlistFilename: String {
        let suffix = isForced ? "_forced" : ""
        return "subtitles_\(language)\(suffix).m3u8"
    }
    
    /// Generated segment filename pattern (e.g., "subtitle_en_%04d.vtt").
    public var segmentPattern: String {
        let suffix = isForced ? "_forced" : ""
        return "subtitle_\(language)\(suffix)_%04d.vtt"
    }
    
    public init(
        index: Int,
        language: String,
        name: String,
        isDefault: Bool = false,
        isForced: Bool = false,
        source: SubtitleSource,
        codec: String? = nil,
        sourcePath: String? = nil
    ) {
        self.index = index
        self.language = language
        self.name = name
        self.isDefault = isDefault
        self.isForced = isForced
        self.source = source
        self.codec = codec
        self.sourcePath = sourcePath
    }
}

// MARK: - Subtitle Source

/// Source of a subtitle track.
public enum SubtitleSource: String, Sendable {
    /// Subtitle embedded in the source video container.
    case embedded
    /// External subtitle file provided by the user.
    case external
}

// MARK: - Language Utilities

extension HLSSubtitleTrack {
    
    /// Common language code to name mappings.
    public static func displayName(for languageCode: String) -> String {
        let commonLanguages: [String: String] = [
            "en": "English",
            "eng": "English",
            "es": "Spanish",
            "spa": "Spanish",
            "fr": "French",
            "fra": "French",
            "de": "German",
            "deu": "German",
            "it": "Italian",
            "ita": "Italian",
            "pt": "Portuguese",
            "por": "Portuguese",
            "ja": "Japanese",
            "jpn": "Japanese",
            "ko": "Korean",
            "kor": "Korean",
            "zh": "Chinese",
            "zho": "Chinese",
            "ru": "Russian",
            "rus": "Russian",
            "ar": "Arabic",
            "ara": "Arabic",
            "hi": "Hindi",
            "hin": "Hindi",
            "und": "Unknown"
        ]
        return commonLanguages[languageCode.lowercased()] ?? languageCode.uppercased()
    }
}
