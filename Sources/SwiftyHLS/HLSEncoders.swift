//
//  HLSEncoders.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

public enum HLSEncoders: String, HLSParameterProtocol {
    case h264SoftwareRenderer = "libx264"
    case h264HardwareAccelerated = "h264_videotoolbox"
    case h264QuickSync = "h264_qsv"
    
    case h265SoftwareRenderer = "libx265"
    case h265HardwareAccelerated = "hevc_videotoolbox"
    case h265QuickSync = "hevc_qsv"
    
    public var id: String {
        rawValue
    }
    
    public var displayName: String {
        switch self {
        case .h264SoftwareRenderer:
            return "H.264 Software Renderer"
        case .h264HardwareAccelerated:
            return "H.264 Hardware Accelerated"
        case .h264QuickSync:
            return "H.264 QuickSync"
        case .h265SoftwareRenderer:
            return "H.265 Software Renderer"
        case .h265HardwareAccelerated:
            return "H.265 Hardware Accelerated"
        case .h265QuickSync:
            return "H.265 QuickSync"
        }
    }
    
    public var ffmpegName: String {
        return rawValue
    }
    
    internal var isHevc: Bool {
        self == .h265SoftwareRenderer || self == .h265HardwareAccelerated || self == .h265QuickSync
    }
    
    public static let h264Cases: [HLSEncoders] = [
        .h264HardwareAccelerated,
        .h264QuickSync,
        .h264SoftwareRenderer
    ]
    
    public static let h265Cases: [HLSEncoders] = [
        .h265HardwareAccelerated,
        .h265QuickSync,
        .h265SoftwareRenderer
    ]
    
}
