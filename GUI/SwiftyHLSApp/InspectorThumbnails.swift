//
//  InspectorThumbnails.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 Sam Spencer. All rights reserved.
//

import SwiftUI
import SwiftyHLS

public struct InspectorThumbnails: View {
    
    @Bindable var viewModel: ContentViewModel
    
    @AppStorage("thumbnailsEnabled") var thumbnailsEnabled: Bool = false
    @AppStorage("thumbnailInterval") var thumbnailInterval: HLSThumbnailIntervalPreset = .standard
    @AppStorage("thumbnailSize") var thumbnailSize: HLSThumbnailSizePreset = .medium
    @AppStorage("thumbnailFormat") var thumbnailFormat: HLSThumbnailFormat = .jpeg
    @AppStorage("thumbnailConcurrent") var thumbnailConcurrent: Bool = true
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Thumbnail Options", systemImage: "photo.on.rectangle")
                    .font(.title2)
                Spacer()
            }
            enableToggle
            if thumbnailsEnabled {
                intervalPicker
                sizePicker
                formatPicker
                concurrentToggle
            }
        }
        .padding()
        .animation(.smooth, value: thumbnailsEnabled)
    }
    
    private var enableToggle: some View {
        VStack(alignment: .leading) {
            Toggle("Generate Seek Thumbnails", isOn: $thumbnailsEnabled)
                .toggleStyle(.checkbox)
            Text("Creates a sprite sheet and WebVTT file for video player seek previews.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
    }
    
    private var intervalPicker: some View {
        VStack(alignment: .leading) {
            Text("Thumbnail Interval")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Picker("Thumbnail Interval", selection: $thumbnailInterval) {
                ForEach(HLSThumbnailIntervalPreset.allCases) { interval in
                    Text(interval.displayName)
                        .tag(interval)
                        .id(interval)
                }
            }
            .labelsHidden()
            Text("How often to capture a thumbnail frame. Shorter intervals create more thumbnails but larger sprite sheets.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
        .transition(.blurReplace)
    }
    
    private var sizePicker: some View {
        VStack(alignment: .leading) {
            Text("Thumbnail Size")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Picker("Thumbnail Size", selection: $thumbnailSize) {
                ForEach(HLSThumbnailSizePreset.allCases) { size in
                    Text(size.displayName)
                        .tag(size)
                        .id(size)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .transition(.blurReplace)
    }
    
    private var formatPicker: some View {
        VStack(alignment: .leading) {
            Text("Image Format")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Picker("Image Format", selection: $thumbnailFormat) {
                ForEach(HLSThumbnailFormat.allCases) { format in
                    Text(format.displayName)
                        .tag(format)
                        .id(format)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("WebP offers smaller file sizes but may have less browser support than JPEG.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
        .transition(.blurReplace)
    }
    
    private var concurrentToggle: some View {
        VStack(alignment: .leading) {
            Toggle("Generate Concurrently", isOn: $thumbnailConcurrent)
                .toggleStyle(.checkbox)
            Text("Run thumbnail generation alongside video encoding. Disable if you experience performance issues.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
        .transition(.blurReplace)
    }
    
}

#Preview {
    InspectorThumbnails(viewModel: ContentViewModel())
}
