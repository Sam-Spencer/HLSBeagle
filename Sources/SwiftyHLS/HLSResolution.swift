//
//  HLSResolution.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

internal typealias Resolution = (width: Int, height: Int, bitrate: String)

public enum HLSResolution: String, HLSParameterProtocol, Comparable {
    
    case resolution4k
    case resolution2k
    case resolution1080p
    case resolution720p
    case resolution480p
    case resolution240p
    
    public var id: String {
        rawValue
    }
    
    public var ffmpegName: String {
        rawValue
    }
    
    public var displayName: String {
        switch self {
        case .resolution4k:
            return "4K (Ultra HD)"
        case .resolution2k:
            return "2K (QHD)"
        case .resolution1080p:
            return "1080p (Full HD)"
        case .resolution720p:
            return "720p (HD)"
        case .resolution480p:
            return "480p (SD)"
        case .resolution240p:
            return "240p (Low Quality)"
        }
    }
    
    internal var resolution: Resolution {
        switch self {
        case .resolution4k:
            return (3840, 2160, "10000k")
        case .resolution2k:
            return (2560, 1440, "5000k")
        case .resolution1080p:
            return (1920, 1080, "3000k")
        case .resolution720p:
            return (1280, 720, "1500k")
        case .resolution480p:
            return (854, 480, "800k")
        case .resolution240p:
            return (426, 240, "400k")
        }
    }
    
    internal static let resolutions: [Resolution] = {
        return allCases.map(\.resolution)
    }()
    
    internal static func resolution(for width: Int) -> HLSResolution? {
        switch width {
        case 3840: return .resolution4k
        case 2560: return .resolution2k
        case 1920: return .resolution1080p
        case 1280: return .resolution720p
        case 854: return .resolution480p
        case 426: return .resolution240p
        default: return nil
        }
    }
    
    // MARK: - Sorting
    
    /// Sort resolutions from highest to lowest quality
    public static func < (lhs: HLSResolution, rhs: HLSResolution) -> Bool {
        lhs.resolution.width > rhs.resolution.width
    }
    
    /// List all resolutions sorted from highest to lowest quality
    internal static let sortedResolutions: [HLSResolution] = {
        return allCases.sorted()
    }()
    
}
