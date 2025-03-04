//
//  OutputComponent.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 Sam Spencer. All rights reserved.
//

import SwiftUI

public struct OutputComponent: View {
    
    var viewModel: ContentViewModel
    
    public var body: some View {
        FileDropComponent(
            selectedPath: viewModel.outputVideoPath,
            selectedName: viewModel.outputFolderName,
            instructions: "Drag and drop a folder here.\nAlternatively, click to select a folder from your Mac."
        ) {
            viewModel.selectOutputFolder()
        } onDrop: { providers in
            viewModel.handleFolderDrop(providers: providers)
        }
    }
    
}
