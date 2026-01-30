//
//  InspectorSubtitles.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 1/29/26.
//  Copyright © 2026 Sam Spencer. All rights reserved.
//

import SwiftUI
import SwiftyHLS
import UniformTypeIdentifiers

/// Model for an external subtitle file added by the user.
struct ExternalSubtitleFile: Identifiable, Equatable {
    let id = UUID()
    var path: String
    var language: String
    var name: String
    var isForced: Bool = false
    
    var filename: String {
        (path as NSString).lastPathComponent
    }
}

public struct InspectorSubtitles: View {
    
    @Bindable var viewModel: ContentViewModel
    
    @AppStorage("subtitlesEnabled") var subtitlesEnabled: Bool = false
    @AppStorage("extractEmbedded") var extractEmbedded: Bool = true
    @AppStorage("subtitlesConcurrent") var subtitlesConcurrent: Bool = true
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Subtitle Options", systemImage: "captions.bubble")
                    .font(.title2)
                Spacer()
            }
            enableToggle
            if subtitlesEnabled {
                embeddedToggle
                Divider()
                externalFilesSection
                Divider()
                concurrentToggle
                infoSection
            }
        }
        .padding()
        .animation(.smooth, value: subtitlesEnabled)
    }
    
    private var enableToggle: some View {
        VStack(alignment: .leading) {
            Toggle("Include Subtitles", isOn: $subtitlesEnabled)
                .toggleStyle(.checkbox)
            Text("Extract and include subtitle tracks in the HLS output as WebVTT segments.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
    }
    
    private var embeddedToggle: some View {
        VStack(alignment: .leading) {
            Toggle("Extract Embedded Subtitles", isOn: $extractEmbedded)
                .toggleStyle(.checkbox)
            Text("Automatically detect and extract subtitle streams embedded in the source video (MKV, MP4, etc.).")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
        .transition(.blurReplace)
    }
    
    private var externalFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("External Subtitle Files")
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Spacer()
                Button {
                    addExternalSubtitleFile()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Add external subtitle file")
            }
            
            if viewModel.externalSubtitleFiles.isEmpty {
                Text("No external subtitle files added. Click + to add SRT, VTT, ASS, or SSA files.")
                    .foregroundStyle(Color.secondary)
                    .font(.caption)
            } else {
                ForEach($viewModel.externalSubtitleFiles) { $file in
                    externalFileRow(file: $file)
                }
            }
        }
        .transition(.blurReplace)
    }
    
    private func externalFileRow(file: Binding<ExternalSubtitleFile>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(Color.secondary)
                Text(file.wrappedValue.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button {
                    viewModel.externalSubtitleFiles.removeAll { $0.id == file.wrappedValue.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.borderless)
                .help("Remove subtitle file")
            }
            HStack(spacing: 12) {
                TextField("Language code", text: file.language)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .help("ISO 639-1 code (e.g., en, es, fr)")
                TextField("Display name", text: file.name)
                    .textFieldStyle(.roundedBorder)
                    .help("e.g., English, Spanish")
                Toggle("Forced", isOn: file.isForced)
                    .toggleStyle(.checkbox)
                    .help("Forced subtitles show even when disabled")
            }
            .font(.caption)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }
    
    private func addExternalSubtitleFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "srt")!,
            UTType(filenameExtension: "vtt")!,
            UTType(filenameExtension: "ass")!,
            UTType(filenameExtension: "ssa")!
        ]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add Subtitle File"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                let newFile = ExternalSubtitleFile(
                    path: url.path,
                    language: "en",
                    name: "English"
                )
                viewModel.externalSubtitleFiles.append(newFile)
            }
        }
    }
    
    private var concurrentToggle: some View {
        VStack(alignment: .leading) {
            Toggle("Process Concurrently", isOn: $subtitlesConcurrent)
                .toggleStyle(.checkbox)
            Text("Run subtitle processing alongside video encoding. Disable if you experience performance issues.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
        .transition(.blurReplace)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supported Formats")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Text("Embedded: SRT, ASS/SSA, MOV Text, WebVTT")
                .foregroundStyle(Color.secondary)
                .font(.caption)
            Text("All subtitle formats are converted to WebVTT for HLS compatibility. The master playlist will include subtitle track references with language metadata.")
                .foregroundStyle(Color.secondary)
                .font(.caption)
        }
        .transition(.blurReplace)
    }
    
}

#Preview {
    InspectorSubtitles(viewModel: ContentViewModel())
}
