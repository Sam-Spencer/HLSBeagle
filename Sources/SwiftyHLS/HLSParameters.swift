//
//  HLSParameters.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

public struct HLSParameters: Sendable {
    public var startNumber: Int = 0
    public var targetDuration: Double = 10
    
    public var preferredEncoder: HLSEncoders?
    public var videoEncodingFormat: HLSVideoEncodingFormat = .h264
    public var encodingPreset: HLSEncodingPreset = .slow // Default preset
    public var qualityPreset: HLSQualityPreset = .balanced // Default quality
    
    public var audioCodec: HLSAudioCodec = .aac // Default audio codec
    public var audioBitrate: HLSAudioBitrate = .bitrate128k // Default audio bitrate
    
    public var thumbnailOptions: HLSThumbnailOptions? // Optional thumbnail generation
    public var subtitleOptions: HLSSubtitleOptions? // Optional subtitle processing
    
    public init(
        startNumber: Int = 0,
        targetDuration: Double = 10,
        preferredEncoder: HLSEncoders? = nil,
        videoEncodingFormat: HLSVideoEncodingFormat = .h265,
        encodingPreset: HLSEncodingPreset = .slow,
        qualityPreset: HLSQualityPreset = .balanced,
        audioCodec: HLSAudioCodec = .aac,
        audioBitrate: HLSAudioBitrate = .bitrate128k,
        thumbnailOptions: HLSThumbnailOptions? = nil,
        subtitleOptions: HLSSubtitleOptions? = nil
    ) {
        self.startNumber = startNumber
        self.targetDuration = targetDuration
        self.preferredEncoder = preferredEncoder
        self.videoEncodingFormat = videoEncodingFormat
        self.encodingPreset = encodingPreset
        self.qualityPreset = qualityPreset
        self.audioCodec = audioCodec
        self.audioBitrate = audioBitrate
        self.thumbnailOptions = thumbnailOptions
        self.subtitleOptions = subtitleOptions
    }
}
