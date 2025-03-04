//
//  HLSVideoEncodingFormat.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//

public enum HLSVideoEncodingFormat: String, HLSParameterProtocol {
    
    case h264
    case h265
    
    public var id: String {
        rawValue
    }
    
    public var ffmpegName: String {
        rawValue
    }
    
    public var displayName: String {
        switch self {
        case .h264:
            return "H.264"
        case .h265:
            return "H.265"
        }
    }
    
}
