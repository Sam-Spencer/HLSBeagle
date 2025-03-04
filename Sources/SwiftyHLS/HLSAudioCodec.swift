//
//  HLSAudioCodec.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

import Foundation

public enum HLSAudioCodec: String, HLSParameterProtocol {
    
    case aac = "aac"
    case opus = "libopus"
    case mp3 = "libmp3lame"
    
    public var id: String {
        rawValue
    }
    
    public var ffmpegName: String {
        rawValue
    }
    
    public var displayName: String {
        switch self {
        case .aac:
            return "AAC"
        case .opus:
            return "Opus"
        case .mp3:
            return "MP3"
        }
    }
}
