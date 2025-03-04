//
//  InputComponent.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 Sam Spencer. All rights reserved.
//

import SwiftUI

public struct InputComponent: View {
    
    var viewModel: ContentViewModel
    
    public var body: some View {
        FileDropComponent(
            selectedPath: viewModel.inputVideoPath,
            selectedName: viewModel.inputVideoName,
            instructions: "Drag and drop a video file here.\nAlternatively, click to select a file from your Mac.",
            defaultIcon: "questionmark.video"
        ) {
            viewModel.selectVideoFile()
        } onDrop: { providers in
            viewModel.handleFileDrop(providers: providers)
        }
    }
    
}
