//
//  InspectorVideo.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 Sam Spencer. All rights reserved.
//

import SwiftUI
import SwiftyHLS

public struct InspectorVideo: View {
    
    @Bindable var viewModel: ContentViewModel
    
    @AppStorage("encodingFormat") var encodingFormat: HLSVideoEncodingFormat = .h264
    @AppStorage("encodingProcess") var encodingProcess: HLSEncoders = .h265HardwareAccelerated
    @AppStorage("encodingSpeed") var encodingSpeed: HLSEncodingPreset = .slow
    @AppStorage("encodingQuality") var encodingQuality: HLSQualityPreset = .balanced
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Video Options", systemImage: "video")
                    .font(.title2)
                Spacer()
            }
            formatPicker
            processPicker
            speedPicker
            qualityPicker
            resolutionsPicker
        }
        .padding()
    }
    
    private var formatPicker: some View {
        VStack(alignment: .leading) {
            Text("Video Codec")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Picker("Video Codec", selection: $encodingFormat) {
                ForEach(HLSVideoEncodingFormat.allCases) { encoding in
                    Text(encoding.displayName)
                        .tag(encoding)
                        .id(encoding)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
    
    private var processPicker: some View {
        VStack(alignment: .leading) {
            Text("Video Encoder")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Picker("Video Encoder", selection: $encodingProcess) {
                if encodingFormat == .h264 {
                    ForEach(HLSEncoders.h264Cases) { h264Encoding in
                        Text(h264Encoding.displayName)
                            .tag(h264Encoding)
                            .id(h264Encoding)
                    }
                } else {
                    ForEach(HLSEncoders.h265Cases) { encoding in
                        Text(encoding.displayName)
                            .tag(encoding)
                            .id(encoding)
                    }
                }
            }
            .labelsHidden()
            if encodingProcess == .h264HardwareAccelerated || encodingProcess == .h265HardwareAccelerated {
                Text("Hardware accelerated rendering is only supported on Apple Silicon Macs. If you are using a non-Apple Silicon Mac, you may experience performance issues or the encoder may not work at all.")
                    .foregroundStyle(Color.secondary)
                    .font(.caption)
            }
        }
    }
    
    private var speedPicker: some View {
        VStack(alignment: .leading) {
            Text("Encoding Speed")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Picker("Encoding Speed", selection: $encodingSpeed) {
                ForEach(HLSEncodingPreset.allCases) { encoding in
                    Text(encoding.displayName)
                        .tag(encoding)
                        .id(encoding)
                }
            }
            .labelsHidden()
            Text("Faster presets encode quicker but produce larger files. Slower presets take longer but yield better compression and quality.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
    }
    
    private var qualityPicker: some View {
        VStack(alignment: .leading) {
            Text("Encoding Quality")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Picker("Encoding Quality", selection: $encodingQuality) {
                ForEach(HLSQualityPreset.allCases) { encoding in
                    Text(encoding.displayName)
                        .tag(encoding)
                        .id(encoding)
                }
            }
            .labelsHidden()
            Text("Controls the constant rate factor (CRF). Lower quality produces smaller files with visible artifacts. Higher quality preserves detail but increases file size.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
    }
    
    private var resolutionsPicker: some View {
        VStack(alignment: .leading) {
            Text("Resolution")
                .font(.headline)
                .foregroundStyle(Color.primary)
            ForEach($viewModel.resolutions) { $availableRes in
                Toggle(availableRes.resolution.displayName, isOn: $availableRes.isSelected)
                    .toggleStyle(.checkbox)
            }
            Text("Select multiple resolutions to encode multiple streams at different resolutions and create a multi-stream HLS playlist that can adapt to different network / client player conditions.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
    }
    
}

#Preview {
    InspectorVideo(viewModel: ContentViewModel())
}

