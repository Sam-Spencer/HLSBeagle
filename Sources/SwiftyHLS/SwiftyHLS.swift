//
//  SwiftyHLS.swift
//  SwiftyHLS
//
//  Created by Sam Spencer on 03/03/25.
//  Copyright © 2025 nenos, inc. All rights reserved.
//

import Foundation
import OSLog

internal let logger = Logger(subsystem: "SwiftyHLS", category: "SwiftyHLS")

public struct SwiftHLS {
    
    public let installManager: InstallManager
    public let converter: VideoConverter
    
    public init(installManager: InstallManager = InstallManager(), converter: VideoConverter? = nil) {
        self.installManager = installManager
        if let converter = converter {
            self.converter = converter
        } else {
            self.converter = VideoConverter()
        }
    }
    
}
