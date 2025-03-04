//
//  HLSEncodingPreset.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

import Foundation

public enum HLSEncodingPreset: String, HLSParameterProtocol {
    case ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
    
    public var id: String {
        rawValue
    }
    
    public var ffmpegName: String {
        rawValue
    }
    
    public var displayName: String {
        switch self {
        case .ultrafast:
            return "Ultra Fast"
        case .superfast:
            return "Super Fast"
        case .veryfast:
            return "Very Fast"
        case .faster:
            return "Faster"
        case .fast:
            return "Fast"
        case .medium:
            return "Medium"
        case .slow:
            return "Slow"
        case .slower:
            return "Slower"
        case .veryslow:
            return "Very Slow"
        }
    }
    
}
