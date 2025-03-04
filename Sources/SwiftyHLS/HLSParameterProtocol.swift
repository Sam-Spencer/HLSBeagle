//
//  HLSParameterProtocol.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 3/3/25.
//

public protocol HLSParameterProtocol: CaseIterable, Codable, Sendable, Identifiable {
    
    /// Returns the valid FFmpeg parameter value
    var ffmpegName: String { get }
    
    /// Returns a user-readable value
    var displayName: String { get }
    
}
