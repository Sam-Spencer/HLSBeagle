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
    
    @Bindable var viewModel: ContentViewModel
    
    @AppStorage("encodingFormat") var encodingFormat: HLSVideoEncodingFormat = .h264
    @AppStorage("encodingProcess") var encodingProcess: HLSEncoders = .h265HardwareAccelerated
    @AppStorage("encodingSpeed") var encodingSpeed: HLSEncodingPreset = .slow
    
    @AppStorage("audioBitrate") var audioBitrate: HLSAudioBitrate = .bitrate128k
    @AppStorage("audioCodec") var audioCodec: HLSAudioCodec = .aac
    
    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                Label("Video Options", systemImage: "video")
                    .font(.title2)
                formatPicker
                processPicker
                speedPicker
                resolutionsPicker
                Divider()
                    .padding(.vertical, 10)
                Label("Audio Options", systemImage: "waveform")
                    .font(.title2)
                audioBitratePicker
                audioCodecPicker
            }
            .padding()
        }
        .background(Material.thick, in: Rectangle())
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
            Text("The encoding speed controls the quality of the video stream. Higher encoding speeds will result in lower video quality, but faster encoding times. This can be particularly impactful when using software encoding on non-Apple Silicon Macs.")
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
    Inspector(viewModel: ContentViewModel())
}
