//
//  Inspector.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 Sam Spencer. All rights reserved.
//

import SwiftUI
import SwiftyHLS

public struct Inspector: View {
    
    enum OptionPanel: Int, Hashable, CaseIterable {
        case video
        case audio
        case subtitles
        case thumbnails
        
        var displayName: String {
            switch self {
            case .video: "Video"
            case .audio: "Audio"
            case .subtitles: "Subtitles"
            case .thumbnails: "Thumbnails"
            }
        }
    }
    
    @Bindable var viewModel: ContentViewModel
    
    @AppStorage("selectedOptionPanel") var optionPanel: OptionPanel = .video
    
    public var body: some View {
        ScrollView(.vertical) {
            switch optionPanel {
            case .video: InspectorVideo(viewModel: viewModel)
            case .audio: InspectorAudio(viewModel: viewModel)
            case .subtitles: InspectorSubtitles(viewModel: viewModel)
            case .thumbnails: InspectorThumbnails(viewModel: viewModel)
            }
        }
        .safeAreaBar(edge: .top) {
            Picker(selection: $optionPanel) {
                ForEach(OptionPanel.allCases, id: \.self) { option in
                    Text(option.displayName)
                        .tag(option)
                        .id(option)
                }
            } label: {
                Text("Options")
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding()
        }
        .glassEffect(.regular, in: Rectangle())
        .frame(minWidth: 200, idealWidth: 300, maxWidth: 500)
        .inspectorColumnWidth(min: 200, ideal: 300, max: 500)
    }
    
}

#Preview {
    Inspector(viewModel: ContentViewModel())
}
