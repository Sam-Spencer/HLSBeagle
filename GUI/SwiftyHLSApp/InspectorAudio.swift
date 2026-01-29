//
//  InspectorAudio.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 Sam Spencer. All rights reserved.
//

import SwiftUI
import SwiftyHLS

public struct InspectorAudio: View {
    
    @Bindable var viewModel: ContentViewModel
    
    @AppStorage("audioBitrate") var audioBitrate: HLSAudioBitrate = .bitrate128k
    @AppStorage("audioCodec") var audioCodec: HLSAudioCodec = .aac
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Audio Options", systemImage: "waveform")
                    .font(.title2)
                Spacer()
            }
            audioBitratePicker
            audioCodecPicker
        }
        .padding()
    }

    private var audioBitratePicker: some View {
        VStack(alignment: .leading) {
            Text("Audio Bitrate")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Picker("Audio Bitrate", selection: $audioBitrate) {
                ForEach(HLSAudioBitrate.allCases) { encoding in
                    Text(encoding.displayName)
                        .tag(encoding)
                        .id(encoding)
                }
            }
            .labelsHidden()
        }
    }
    
    private var audioCodecPicker: some View {
        VStack(alignment: .leading) {
            Text("Audio Codec")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Picker("Audio Codec", selection: $audioCodec) {
                ForEach(HLSAudioCodec.allCases) { encoding in
                    Text(encoding.displayName)
                        .tag(encoding)
                        .id(encoding)
                }
            }
            .labelsHidden()
            Text("AAC is the most widely supported audio codec for HLS and is recommended for most users.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
    }
    
}

#Preview {
    InspectorAudio(viewModel: ContentViewModel())
}
