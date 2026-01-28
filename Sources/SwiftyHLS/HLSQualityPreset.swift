//
//  HLSQualityPreset.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 1/27/26.
//  Copyright © 2026 nenos, inc. All rights reserved.
//

import Foundation

/// Quality preset that controls the CRF (Constant Rate Factor) value.
/// Lower CRF = higher quality, larger files. Higher CRF = lower quality, smaller files.
public enum HLSQualityPreset: String, HLSParameterProtocol, CaseIterable {
    case high       // Best quality, larger files
    case balanced   // Default, good tradeoff
    case efficient  // Smaller files, lower quality
    
    public var id: String {
        rawValue
    }

    public var ffmpegName: String {
        rawValue
    }
    
    public var displayName: String {
        switch self {
        case .high:
            return "High Quality"
        case .balanced:
            return "Balanced"
        case .efficient:
            return "Efficient"
        }
    }
    
    /// Returns the CRF value for H.264 encoding.
    public var crfH264: Int {
        switch self {
        case .high:
            return 18
        case .balanced:
            return 23
        case .efficient:
            return 28
        }
    }
    
    /// Returns the CRF value for H.265/HEVC encoding.
    public var crfH265: Int {
        switch self {
        case .high:
            return 24
        case .balanced:
            return 28
        case .efficient:
            return 32
        }
    }
}
