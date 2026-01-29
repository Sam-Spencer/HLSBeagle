//
//  ContentView.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 Sam Spencer. All rights reserved.
//

import SwiftUI
import SwiftyHLS

struct ContentView: View {
    
    @Environment(ContentViewModel.self) var viewModel
    @AppStorage("showInspector") private var showInspector: Bool = false
    @State private var showFileAlert = false
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 20) {
                statusZone
                inputZone
                outputZone
                conversionZone
                cleanupZone
                progressZone
            }
            .padding()
        }
        .navigationTitle(Text("HLS Beagle"))
        .toolbar {
            Button {
                showInspector.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
        }
        .inspector(isPresented: $showInspector) {
            Inspector(viewModel: viewModel)
        }
        .toolbarTitleDisplayMode(.inlineLarge)
        .presentedWindowToolbarStyle(.unified(showsTitle: true))
        .onAppear {
            viewModel.checkInstallStatus()
        }
        .alert(
            "Unsupported File Format",
            isPresented: $showFileAlert
        ) {
            Button("Okay") {
                viewModel.showBadFileFormatAlert = false
            }
        } message: {
            Text("HLS Beagle only supports transcoding movie files including MP4, MOV, MKV, M4V, and AVI. The file you selected is not supported.")
        }
        .onChange(of: viewModel.showBadFileFormatAlert) {
            showFileAlert = viewModel.showBadFileFormatAlert
        }
    }
    
    private var statusZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FFMPEG Status")
                .font(.headline)
                .foregroundStyle(Color.primary)
            Group {
                if viewModel.ffmpegInstalled {
                    Label("FFMPEG is installed & ready to use", systemImage: "checkmark.circle")
                        .foregroundStyle(Color.primary)
                } else {
                    Label("FFMPEG Not Installed", systemImage: "xmark.circle")
                        .foregroundStyle(Color.primary)
                }
            }
            .font(.subheadline)
            .padding(.all, 8)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(viewModel.ffmpegInstalled ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            }
        }
    }
    
    private var inputZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video Input")
                .font(.headline)
                .foregroundStyle(Color.primary)
            InputComponent(viewModel: viewModel)
            if let resolution = viewModel.inputVideoResolution {
                Text("Resolution: \(resolution)")
                    .foregroundStyle(Color.secondary)
            }
            if let duration = viewModel.inputVideoDuration {
                Text("Duration: \(duration)")
                    .foregroundStyle(Color.secondary)
            }
        }
    }
    
    private var outputZone: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Folder Output")
                .font(.headline)
                .foregroundStyle(Color.primary)
            OutputComponent(viewModel: viewModel)
        }
    }
    
    @ViewBuilder
    private var conversionZone: some View {
        if viewModel.conversionInProgress {
            VStack(alignment: .leading) {
                Text("Converting \(viewModel.inputVideoName ?? "Video") to HLS...")
                ForEach(viewModel.conversionProgress.sorted(by: { $0.key < $1.key }), id: \.key) { progressPayload in
                    HStack {
                        if progressPayload.value > 0.99 {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(Color.green)
                                .font(.caption)
                        }
                        Text(progressPayload.key.displayName)
                            .foregroundStyle(Color.secondary)
                            .font(.caption)
                        ProgressView(value: progressPayload.value > 0.99 ? 1 : progressPayload.value, total: 1)
                    }
                }
                if viewModel.thumbnailProgress > 0 {
                    HStack {
                        if viewModel.thumbnailProgress > 0.99 {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(Color.green)
                                .font(.caption)
                        }
                        Text("Thumbnails")
                            .foregroundStyle(Color.secondary)
                            .font(.caption)
                        ProgressView(value: viewModel.thumbnailProgress > 0.99 ? 1 : viewModel.thumbnailProgress, total: 1)
                    }
                }
            }
        } else {
            Button("Convert \(viewModel.inputVideoName ?? "Video") to HLS") {
                guard viewModel.readyToConvert else { return }
                viewModel.convertVideo()
            }
            .tint(viewModel.readyToConvert ? Color.blue : Color.clear)
            .disabled(viewModel.readyToConvert == false)
            .buttonStyle(.bordered)
            successZone
        }
    }
    
    @ViewBuilder
    private var cleanupZone: some View {
        if viewModel.showCleanupPrompt {
            VStack(alignment: .leading, spacing: 16) {
                Text("Conversion of \(viewModel.inputVideoName ?? "your video") failed.")
                    .font(.headline)
                Text("Would you like to cleanup any incomplete HLS data that was generated before retrying?")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                HStack {
                    Button("Cleanup") {
                        viewModel.cleanup()
                    }
                    Spacer()
                }
            }
            .padding(.all, 16)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Button {
                    viewModel.showCleanupPrompt = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .padding(16)
            }
        }
    }
    
    @ViewBuilder
    private var successZone: some View {
        if viewModel.showCompletedMessage {
            VStack(alignment: .leading, spacing: 16) {
                Text("🎉 Conversion of \(viewModel.inputVideoName ?? "your video") completed successfully!")
                    .font(.headline)
                Text("You can now play your HLS stream in a player.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(viewModel.outputVideoPath, inFileViewerRootedAtPath: "")
                    }
                    Button("Play in Default Player") {
                        guard let outputUrl = viewModel.outputVideoPath else { return }
                        let fileURL = URL(fileURLWithPath: outputUrl).appendingPathComponent("master.m3u8")
                        NSWorkspace.shared.open(fileURL)
                    }
                    Spacer()
                }
            }
            .padding(.all, 16)
            .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Button {
                    viewModel.showCompletedMessage = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .padding(16)
            }
        }
    }
    
    @ViewBuilder
    private var progressZone: some View {
        if viewModel.conversionStatus.isEmpty {
            EmptyView()
        } else {
            List(viewModel.conversionStatus) { statusUpdate in
                Text(statusUpdate.message)
                    .foregroundStyle(
                        statusColor(for: statusUpdate.statusType)
                    )
                    .contextMenu {
                        Button {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(statusUpdate.message, forType: .string)
                        } label: {
                            Text("Copy to clipboard")
                        }
                    }
            }
            .listRowSeparator(.visible)
            .defaultScrollAnchor(.bottom)
            .frame(maxWidth: .infinity, idealHeight: 220, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func statusColor(for status: ConversionStatus.StatusType) -> Color {
        switch status {
        case .info:
            Color.secondary
        case .success:
            Color.green
        case .warning:
            Color.yellow
        case .error:
            Color.red
        }
    }
}

#Preview {
    ContentView()
        .environment(ContentViewModel())
}
