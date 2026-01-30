//
//  ContentViewModel.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 Sam Spencer. All rights reserved.
//

import AppKit
import Foundation
import Observation
import SwiftyHLS
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct ConversionStatus: Identifiable {
    enum StatusType {
        case info
        case success
        case warning
        case error
    }
    
    var id: String
    var timestamp: Date = .now
    var message: String
    var statusType: StatusType
}

struct ResolutionOption: Identifiable, Equatable, Hashable {
    
    var id: String {
        resolution.id
    }
    var resolution: HLSResolution
    var isSelected: Bool = true
    
}

@Observable
final class ContentViewModel {
    
    var ffmpegInstalled: Bool = false
    
    var inputVideoPath: String? = nil
    var inputVideoName: String? = nil
    var inputVideoType: String? = nil
    var inputVideoResolution: String? = nil
    var inputVideoDuration: String? = nil
    
    var outputVideoPath: String? = nil
    var outputFolderName: String? = nil
    
    var resolutions: [ResolutionOption] = []
    
    var readyToConvert: Bool = false
    var conversionInProgress: Bool = false
    var conversionProgress: [HLSResolution: Double] = [:]
    var thumbnailProgress: Double = 0
    var totalVideoDuration: Double = 0
    var showConversionProgress: Bool = false
    var conversionStatus: [ConversionStatus] = []
    
    var showCleanupPrompt: Bool = false
    var showBadFileFormatAlert: Bool = false
    var showCompletedMessage: Bool = false
    
    var externalSubtitleFiles: [ExternalSubtitleFile] = []
    
    init() {
        checkInstallStatus()
        loadFromUserDefaults()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func checkInstallStatus() {
        Task {
            ffmpegInstalled = SwiftHLS().installManager.isFFmpegInstalled()
        }
    }
    
    func checkReadyToConvert() {
        readyToConvert = inputVideoPath != nil && outputFolderName != nil
    }
    
    private func loadFromUserDefaults() {
        inputVideoPath = UserDefaults.standard.string(forKey: "inputVideoPath")
        inputVideoName = UserDefaults.standard.string(forKey: "inputVideoName")
        inputVideoType = UserDefaults.standard.string(forKey: "inputVideoType")
        outputVideoPath = UserDefaults.standard.string(forKey: "outputVideoPath")
        outputFolderName = UserDefaults.standard.string(forKey: "outputFolderName")
        checkInputVideoFile()
        refreshOutputDetails(shouldUpdateDefaults: false)
    }
    
    // MARK: - State Reset
    
    /// Resets conversion-related state for a fresh start.
    ///
    func resetConversionState() {
        conversionProgress = [:]
        thumbnailProgress = 0
        conversionStatus = []
        showCompletedMessage = false
        showCleanupPrompt = false
    }
    
    // MARK: - File Selection
    
    func handleFileSelection(url: URL) {
        let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
        
        if resourceValues?.isDirectory == true {
            handleOutputDirectoryChange(url)
            return
        }
        
        if let fileType = resourceValues?.contentType, fileType.conforms(to: .movie) {
            handleInputVideoChange(url)
            return
        }
        
        showBadFileFormatAlert = true
        print("Unsupported file type: \(url.path)")
    }
    
    private func handleInputVideoChange(_ videoPath: URL) {
        guard conversionInProgress == false else { return }
        
        resetConversionState()
        inputVideoName = videoPath.lastPathComponent
        inputVideoType = videoPath.pathExtension
        inputVideoPath = videoPath.path
        checkInputVideoFile()
    }
    
    private func handleOutputDirectoryChange(_ directoryPath: URL) {
        guard conversionInProgress == false else { return }
        
        outputVideoPath = directoryPath.path
        outputFolderName = directoryPath.lastPathComponent
        refreshOutputDetails()
    }
    
    /// Opens a file picker dialog for selecting a video file.
    ///
    func selectVideoFile() {
        guard conversionInProgress == false else { return }
        
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType.mpeg4Movie,
            UTType.movie,
            UTType.quickTimeMovie,
            UTType.avi,
            UTType.mpeg2Video
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK {
            resetConversionState()
            inputVideoName = panel.url?.lastPathComponent
            inputVideoType = panel.url?.pathExtension
            inputVideoPath = panel.url?.path
            checkInputVideoFile()
        }
    }
    
    /// Handle drag and drop of video files.
    ///
    func handleFileDrop(providers: [NSItemProvider]) -> Bool {
        guard conversionInProgress == false else { return false }
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.resetConversionState()
                self.inputVideoName = url.lastPathComponent
                self.inputVideoType = url.pathExtension
                self.inputVideoPath = url.path
                self.checkInputVideoFile()
            }
        }
        
        return true
    }
    
    func checkInputVideoFile() {
        Task {
            guard let path = inputVideoPath else { return }
            
            if let resolution = VideoProcessor.getStandardResolution(for: path) {
                inputVideoResolution = resolution.displayName
                let availableResolutions = VideoProcessor.resolutionOptions(at: resolution)
                resolutions = availableResolutions.map({ ResolutionOption(resolution: $0) })
                for resolution in availableResolutions {
                    conversionProgress[resolution] = 0
                }
            } else {
                resolutions = []
                inputVideoResolution = "Unknown Video Resolution"
            }
            
            totalVideoDuration = VideoProcessor.getDuration(for: path) as TimeInterval
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.unitsStyle = .short
            formatter.zeroFormattingBehavior = .dropLeading
            inputVideoDuration = formatter.string(from: totalVideoDuration)
            
            checkReadyToConvert()
            UserDefaults.standard.set(inputVideoName, forKey: "inputVideoName")
            UserDefaults.standard.set(inputVideoType, forKey: "inputVideoType")
            UserDefaults.standard.set(inputVideoPath, forKey: "inputVideoPath")
        }
    }
    
    /// Opens a folder picker dialog for selecting an output directory.
    ///
    func selectOutputFolder() {
        guard conversionInProgress == false else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Output Folder"
        
        if panel.runModal() == .OK, let selectedURL = panel.url {
            outputVideoPath = selectedURL.path
            outputFolderName = selectedURL.lastPathComponent
            refreshOutputDetails()
        }
    }
    
    func handleFolderDrop(providers: [NSItemProvider]) -> Bool {
        guard conversionInProgress == false else { return false }
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.hasDirectoryPath else { return } // Ensure it's a directory
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.outputVideoPath = url.path
                self.outputFolderName = url.lastPathComponent
                self.refreshOutputDetails()
            }
        }
        return true
    }
    
    private func refreshOutputDetails(shouldUpdateDefaults: Bool = true) {
        if shouldUpdateDefaults {
            UserDefaults.standard.set(outputVideoPath, forKey: "outputVideoPath")
            UserDefaults.standard.set(outputFolderName, forKey: "outputFolderName")
        }
        NotificationCenter.default.post(
            name: Notification.Name.OutputDirectoryChanged,
            object: outputVideoPath
        )
        checkReadyToConvert()
    }
    
    // MARK: - Conversion
    
    func convertVideo() {
        guard ffmpegInstalled else {
            conversionStatus = [.init(id: "error", message: "FFmpeg is not installed. Please install it first.", statusType: .error)]
            return
        }
        
        guard let inputPath = inputVideoPath else {
            conversionStatus = [.init(id: "warn", message: "Please select an input file.", statusType: .warning)]
            return
        }
        
        guard let outputPath = outputVideoPath else {
            conversionStatus = [.init(id: "warn", message: "Please select an output folder.", statusType: .warning)]
            return
        }
        
        readyToConvert = true
        showCompletedMessage = false
        updateConversionStatus(to: true)
        conversionStatus = [.init(id: "processing", message: "Processing...", statusType: .info)]
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            let defaults = UserDefaults.standard
            let preferredEncoder = HLSVideoEncodingFormat(rawValue: defaults.string(forKey: "encodingFormat") ?? "h264") ?? HLSVideoEncodingFormat.h264
            let encodingProcess = HLSEncoders(rawValue: defaults.string(forKey: "encodingProcess") ?? "h264_videotoolbox") ?? HLSEncoders.h264HardwareAccelerated
            let encodingSpeed = HLSEncodingPreset(rawValue: defaults.string(forKey: "encodingSpeed") ?? "slow") ?? HLSEncodingPreset.slow
            let encodingQuality = HLSQualityPreset(rawValue: defaults.string(forKey: "encodingQuality") ?? "balanced") ?? HLSQualityPreset.balanced
            let audioCodec = HLSAudioCodec(rawValue: defaults.string(forKey: "audioCodec") ?? "aac") ?? HLSAudioCodec.aac
            let audioBitrate = HLSAudioBitrate(rawValue: defaults.string(forKey: "audioBitrate") ?? "128k") ?? HLSAudioBitrate.bitrate128k
            
            // Thumbnail options
            let thumbnailsEnabled = defaults.bool(forKey: "thumbnailsEnabled")
            let thumbnailOptions: HLSThumbnailOptions? = thumbnailsEnabled ? HLSThumbnailOptions(
                enabled: true,
                interval: HLSThumbnailIntervalPreset(rawValue: defaults.string(forKey: "thumbnailInterval") ?? "standard")?.interval ?? 10,
                width: HLSThumbnailSizePreset(rawValue: defaults.string(forKey: "thumbnailSize") ?? "medium")?.width ?? 320,
                format: HLSThumbnailFormat(rawValue: defaults.string(forKey: "thumbnailFormat") ?? "jpeg") ?? .jpeg,
                concurrent: defaults.object(forKey: "thumbnailConcurrent") as? Bool ?? true
            ) : nil
            
            // Subtitle options
            let subtitlesEnabled = defaults.bool(forKey: "subtitlesEnabled")
            let externalFiles = await MainActor.run {
                self.externalSubtitleFiles.map { file in
                    HLSExternalSubtitle(
                        path: file.path,
                        language: file.language,
                        name: file.name,
                        isForced: file.isForced
                    )
                }
            }
            let subtitleOptions: HLSSubtitleOptions? = subtitlesEnabled ? HLSSubtitleOptions(
                enabled: true,
                extractEmbedded: defaults.object(forKey: "extractEmbedded") as? Bool ?? true,
                externalFiles: externalFiles,
                defaultLanguage: nil,
                concurrent: defaults.object(forKey: "subtitlesConcurrent") as? Bool ?? true
            ) : nil
            
            let options = HLSParameters(
                preferredEncoder: encodingProcess,
                videoEncodingFormat: preferredEncoder,
                encodingPreset: encodingSpeed,
                qualityPreset: encodingQuality,
                audioCodec: audioCodec,
                audioBitrate: audioBitrate,
                thumbnailOptions: thumbnailOptions,
                subtitleOptions: subtitleOptions
            )
            
            let excludedResolutions = resolutions
                .filter { $0.isSelected == false }
                .map { $0.resolution }
            
            let conversionStream = SwiftHLS().converter.convertVideo(
                inputPath: inputPath,
                outputPath: outputPath,
                options: options,
                excludeResolutions: excludedResolutions
            )
            
            for await update in conversionStream {
                switch update {
                case .started:
                    await MainActor.run {
                        self.conversionStatus.insert(.init(id: "starting", message: "Starting...", statusType: .success), at: 0)
                    }
                case .encoding(let message):
                    await MainActor.run {
                        self.conversionStatus.insert(
                            .init(id: UUID().uuidString, message: message, statusType: .info),
                            at: 0
                        )
                    }
                case .progress(let progress, let resolution):
                    await MainActor.run {
                        self.conversionProgress[resolution] = min(progress / 100.0, 1.0)
                    }
                case .completedSuccessfully:
                    await MainActor.run {
                        for resolution in self.conversionProgress.keys {
                            self.conversionProgress[resolution] = 1.0
                        }
                        self.showCompletedMessage = true
                        self.conversionStatus.insert(
                            .init(id: "complete", message: "Conversion complete!", statusType: .success),
                            at: 0
                        )
                        self.updateConversionStatus(to: false)
                        self.sendNotification(
                            title: "HLS Conversion Complete",
                            message: "\(self.inputVideoName ?? "Your video") has been successfully converted."
                        )
                    }
                case .failed(let error):
                    await MainActor.run {
                        self.conversionStatus.insert(
                            .init(id: "failed", message: "Error: \(error.localizedDescription)", statusType: .error),
                            at: 0
                        )
                        self.updateConversionStatus(to: false)
                        self.sendNotification(
                            title: "HLS Conversion Failed",
                            message: "An error occurred while converting \(self.inputVideoName ?? "Your video"). \(error.localizedDescription)"
                        )
                        self.showCleanupPrompt = true
                    }
                case .thumbnails(let thumbnailUpdate):
                    await MainActor.run {
                        switch thumbnailUpdate {
                        case .started:
                            self.conversionStatus.insert(
                                .init(id: "thumbnails-started", message: "Generating thumbnails...", statusType: .info),
                                at: 0
                            )
                        case .extractingFrames(let current, let total):
                            self.thumbnailProgress = Double(current) / Double(total)
                        case .assemblingSprite:
                            self.conversionStatus.insert(
                                .init(id: "thumbnails-sprite", message: "Assembling sprite sheet...", statusType: .info),
                                at: 0
                            )
                        case .writingVTT:
                            self.conversionStatus.insert(
                                .init(id: "thumbnails-vtt", message: "Writing VTT file...", statusType: .info),
                                at: 0
                            )
                        case .completed:
                            self.thumbnailProgress = 1.0
                            self.conversionStatus.insert(
                                .init(id: "thumbnails-complete", message: "Thumbnails generated!", statusType: .success),
                                at: 0
                            )
                        case .failed(let error):
                            self.conversionStatus.insert(
                                .init(id: "thumbnails-failed", message: "Thumbnail error: \(error.localizedDescription)", statusType: .error),
                                at: 0
                            )
                        }
                    }
                case .subtitles(let subtitleUpdate):
                    await MainActor.run {
                        switch subtitleUpdate {
                        case .started:
                            self.conversionStatus.insert(
                                .init(id: "subtitles-started", message: "Processing subtitles...", statusType: .info),
                                at: 0
                            )
                        case .detectingStreams:
                            self.conversionStatus.insert(
                                .init(id: "subtitles-detecting", message: "Detecting subtitle streams...", statusType: .info),
                                at: 0
                            )
                        case .extracting(let track, let current, let total):
                            self.conversionStatus.insert(
                                .init(id: "subtitles-extracting-\(track.language)", message: "Extracting subtitles (\(current)/\(total)): \(track.name)...", statusType: .info),
                                at: 0
                            )
                        case .segmenting(let track):
                            self.conversionStatus.insert(
                                .init(id: "subtitles-segmenting-\(track.language)", message: "Segmenting: \(track.name)...", statusType: .info),
                                at: 0
                            )
                        case .writingPlaylist(let track):
                            self.conversionStatus.insert(
                                .init(id: "subtitles-playlist-\(track.language)", message: "Writing playlist: \(track.name)...", statusType: .info),
                                at: 0
                            )
                        case .completed(let tracks):
                            let message = tracks.isEmpty ? "No subtitles found" : "Subtitles processed: \(tracks.count) track(s)"
                            self.conversionStatus.insert(
                                .init(id: "subtitles-complete", message: message, statusType: .success),
                                at: 0
                            )
                        case .failed(let error):
                            self.conversionStatus.insert(
                                .init(id: "subtitles-failed", message: "Subtitle error: \(error.localizedDescription)", statusType: .error),
                                at: 0
                            )
                        }
                    }
                }
            }
        }
    }
    
    func cleanup() {
        guard let outputVideoPath = outputVideoPath else { return }
        VideoConverter.cleanup(outputDirectory: outputVideoPath) {
            self.showCleanupPrompt = false
        }
    }
    
    private func updateConversionStatus(to isInProgress: Bool) {
        self.conversionInProgress = isInProgress
        NotificationCenter.default.post(
            name: Notification.Name.ConversionStatusChanged,
            object: conversionInProgress
        )
    }
    
    private func sendNotification(title: String, message: String) {
        let notificationCenter = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
    
}
