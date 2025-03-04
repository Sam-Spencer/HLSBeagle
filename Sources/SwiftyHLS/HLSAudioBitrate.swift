//
//  HLSAudioBitrate.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

public enum HLSAudioBitrate: String, HLSParameterProtocol {
    
    public var id: String {
        rawValue
    }
    
    case bitrate96k = "96k"
    case bitrate128k = "128k"
    case bitrate192k = "192k"
    case bitrate256k = "256k"
    case bitrate320k = "320k"
    
    public var ffmpegName: String {
        rawValue
    }
    
    public var displayName: String {
        switch self {
        case .bitrate96k: return "96 kbps"
        case .bitrate128k: return "128 kbps"
        case .bitrate192k: return "192 kbps"
        case .bitrate256k: return "256 kbps"
        case .bitrate320k: return "320 kbps"
        }
    }
}
