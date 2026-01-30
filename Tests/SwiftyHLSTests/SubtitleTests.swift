//
//  SubtitleTests.swift
//  SwiftyHLSTests
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 nenos, inc. All rights reserved.
//

import Foundation
import Testing
@testable import SwiftyHLS

// MARK: - Subtitle Track Tests

@Test func subtitleTrackPlaylistFilename() async throws {
    let track = HLSSubtitleTrack(
        index: 0,
        language: "en",
        name: "English",
        isDefault: true,
        isForced: false,
        source: .embedded,
        codec: "subrip"
    )
    
    #expect(track.playlistFilename == "subtitles_en.m3u8")
}

@Test func subtitleTrackPlaylistFilenameForced() async throws {
    let track = HLSSubtitleTrack(
        index: 0,
        language: "en",
        name: "English (Forced)",
        isDefault: false,
        isForced: true,
        source: .embedded,
        codec: "subrip"
    )
    
    #expect(track.playlistFilename == "subtitles_en_forced.m3u8")
}

@Test func subtitleTrackSegmentPattern() async throws {
    let track = HLSSubtitleTrack(
        index: 0,
        language: "es",
        name: "Spanish",
        isDefault: false,
        isForced: false,
        source: .external,
        sourcePath: "/path/to/spanish.srt"
    )
    
    #expect(track.segmentPattern == "subtitle_es_%04d.vtt")
}

@Test func subtitleTrackSegmentPatternForced() async throws {
    let track = HLSSubtitleTrack(
        index: 0,
        language: "ja",
        name: "Japanese (Forced)",
        isDefault: false,
        isForced: true,
        source: .external,
        sourcePath: "/path/to/japanese.srt"
    )
    
    #expect(track.segmentPattern == "subtitle_ja_forced_%04d.vtt")
}

@Test func subtitleTrackId() async throws {
    let embeddedTrack = HLSSubtitleTrack(
        index: 2,
        language: "fr",
        name: "French",
        source: .embedded
    )
    
    let externalTrack = HLSSubtitleTrack(
        index: 0,
        language: "de",
        name: "German",
        source: .external,
        sourcePath: "/path/to/german.srt"
    )
    
    #expect(embeddedTrack.id == "embedded_2_fr")
    #expect(externalTrack.id == "external_0_de")
}

// MARK: - Language Display Name Tests

@Test func languageDisplayNameCommonCodes() async throws {
    #expect(HLSSubtitleTrack.displayName(for: "en") == "English")
    #expect(HLSSubtitleTrack.displayName(for: "eng") == "English")
    #expect(HLSSubtitleTrack.displayName(for: "es") == "Spanish")
    #expect(HLSSubtitleTrack.displayName(for: "spa") == "Spanish")
    #expect(HLSSubtitleTrack.displayName(for: "fr") == "French")
    #expect(HLSSubtitleTrack.displayName(for: "fra") == "French")
    #expect(HLSSubtitleTrack.displayName(for: "de") == "German")
    #expect(HLSSubtitleTrack.displayName(for: "deu") == "German")
    #expect(HLSSubtitleTrack.displayName(for: "ja") == "Japanese")
    #expect(HLSSubtitleTrack.displayName(for: "jpn") == "Japanese")
    #expect(HLSSubtitleTrack.displayName(for: "zh") == "Chinese")
    #expect(HLSSubtitleTrack.displayName(for: "zho") == "Chinese")
    #expect(HLSSubtitleTrack.displayName(for: "und") == "Unknown")
}

@Test func languageDisplayNameUnknownCode() async throws {
    // Unknown codes should return uppercased version
    #expect(HLSSubtitleTrack.displayName(for: "xyz") == "XYZ")
    #expect(HLSSubtitleTrack.displayName(for: "tlh") == "TLH")
}

@Test func languageDisplayNameCaseInsensitive() async throws {
    #expect(HLSSubtitleTrack.displayName(for: "EN") == "English")
    #expect(HLSSubtitleTrack.displayName(for: "Es") == "Spanish")
    #expect(HLSSubtitleTrack.displayName(for: "FRA") == "French")
}

// MARK: - Subtitle Format Tests

@Test func subtitleFormatFromPath() async throws {
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.srt") == .srt)
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.vtt") == .vtt)
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.ass") == .ass)
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.ssa") == .ssa)
}

@Test func subtitleFormatFromPathCaseInsensitive() async throws {
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.SRT") == .srt)
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.VTT") == .vtt)
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.ASS") == .ass)
}

@Test func subtitleFormatFromPathUnsupported() async throws {
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.sub") == nil)
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.txt") == nil)
    #expect(HLSSubtitleFormat.from(path: "/path/to/file.mp4") == nil)
}

@Test func subtitleFormatFileExtension() async throws {
    #expect(HLSSubtitleFormat.srt.fileExtension == "srt")
    #expect(HLSSubtitleFormat.vtt.fileExtension == "vtt")
    #expect(HLSSubtitleFormat.ass.fileExtension == "ass")
    #expect(HLSSubtitleFormat.ssa.fileExtension == "ssa")
}

@Test func subtitleFormatDisplayName() async throws {
    #expect(HLSSubtitleFormat.srt.displayName == "SubRip (SRT)")
    #expect(HLSSubtitleFormat.vtt.displayName == "WebVTT")
    #expect(HLSSubtitleFormat.ass.displayName == "Advanced SubStation Alpha")
    #expect(HLSSubtitleFormat.ssa.displayName == "SubStation Alpha")
}

// MARK: - Subtitle Options Tests

@Test func subtitleOptionsDefaults() async throws {
    let options = HLSSubtitleOptions()
    
    #expect(options.enabled == false)
    #expect(options.extractEmbedded == true)
    #expect(options.externalFiles.isEmpty)
    #expect(options.defaultLanguage == nil)
    #expect(options.concurrent == true)
}

@Test func subtitleOptionsCustomValues() async throws {
    let externalFile = HLSExternalSubtitle(
        path: "/path/to/english.srt",
        language: "en",
        name: "English",
        isForced: false
    )
    
    let options = HLSSubtitleOptions(
        enabled: true,
        extractEmbedded: false,
        externalFiles: [externalFile],
        defaultLanguage: "en",
        concurrent: false
    )
    
    #expect(options.enabled == true)
    #expect(options.extractEmbedded == false)
    #expect(options.externalFiles.count == 1)
    #expect(options.externalFiles.first?.path == "/path/to/english.srt")
    #expect(options.defaultLanguage == "en")
    #expect(options.concurrent == false)
}

// MARK: - External Subtitle Tests

@Test func externalSubtitleProperties() async throws {
    let subtitle = HLSExternalSubtitle(
        path: "/videos/subs/spanish.srt",
        language: "es",
        name: "Spanish",
        isForced: true
    )
    
    #expect(subtitle.path == "/videos/subs/spanish.srt")
    #expect(subtitle.language == "es")
    #expect(subtitle.name == "Spanish")
    #expect(subtitle.isForced == true)
}

@Test func externalSubtitleDefaults() async throws {
    let subtitle = HLSExternalSubtitle(
        path: "/path/to/file.srt",
        language: "en"
    )
    
    #expect(subtitle.name == nil)
    #expect(subtitle.isForced == false)
}

@Test func externalSubtitleEquatable() async throws {
    let subtitle1 = HLSExternalSubtitle(path: "/path/a.srt", language: "en")
    let subtitle2 = HLSExternalSubtitle(path: "/path/a.srt", language: "en")
    let subtitle3 = HLSExternalSubtitle(path: "/path/b.srt", language: "en")
    
    #expect(subtitle1 == subtitle2)
    #expect(subtitle1 != subtitle3)
}

// MARK: - Subtitle Progress Tests

@Test func subtitleProgressCases() async throws {
    let track = HLSSubtitleTrack(
        index: 0,
        language: "en",
        name: "English",
        source: .embedded
    )
    
    // Verify all cases can be created (compile-time check)
    let cases: [SubtitleProgress] = [
        .started,
        .detectingStreams,
        .extracting(track: track, current: 1, total: 2),
        .segmenting(track: track),
        .writingPlaylist(track: track),
        .completed(tracks: [track]),
        .failed(error: SwiftyHLSError.ffmpegNotFound)
    ]
    
    #expect(cases.count == 7)
}
