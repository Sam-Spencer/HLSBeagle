//
//  SwiftyHLSAppApp.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 3/3/25.
//

import SwiftUI
import SwiftyHLS
import UniformTypeIdentifiers

public extension Notification.Name {
    static let ConversionStatusChanged = Notification.Name("conversionStatusChanged")
    static let OutputDirectoryChanged = Notification.Name("outputDirectoryChanged")
}

@main
struct SwiftyHLSAppApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = ContentViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .onOpenURL { fileUrl in
                    viewModel.handleFileSelection(url: fileUrl)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem, addition: {
                Button {
                    viewModel.selectVideoFile()
                } label: {
                    Text("Open Video...")
                }
                .keyboardShortcut(KeyEquivalent("o"), modifiers: .command)
                .disabled(viewModel.conversionInProgress)
                Button {
                    viewModel.selectOutputFolder()
                } label: {
                    Text("Open Folder...")
                }
                .keyboardShortcut(KeyEquivalent("o"), modifiers: [.command, .shift])
                .disabled(viewModel.conversionInProgress)
            })
        }
        .handlesExternalEvents(matching: ["*"])
        .restorationBehavior(.automatic)
        .defaultLaunchBehavior(.presented)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var conversionInProgress = false
    private var outputDirectory: String?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConversionStatus(_:)),
            name: Notification.Name.ConversionStatusChanged,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOutputDirectoryChanged(_:)),
            name: Notification.Name.OutputDirectoryChanged,
            object: nil
        )
    }
    
    @objc private func handleConversionStatus(_ notification: Notification) {
        if let isConverting = notification.object as? Bool {
            conversionInProgress = isConverting
        }
    }
    
    @objc private func handleOutputDirectoryChanged(_ notification: Notification) {
        if let outputDir = notification.object as? String {
            outputDirectory = outputDir
        }
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if conversionInProgress {
            let alert = NSAlert()
            alert.messageText = "You have a video conversion currently in progress."
            alert.informativeText = "Are you sure you want to quit? The conversion will stop and cannot be resumed. If you want to quit and cleanup any generated output files, click \"Quit and Cleanup Output\"."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Cancel") // 1000
            alert.addButton(withTitle: "Quit") // 1001
            alert.addButton(withTitle: "Quit and Cleanup Output") // 1002
            
            let response = alert.runModal()
            if response.rawValue == 1000 {
                return .terminateCancel
            } else if response.rawValue == 1001 {
                return .terminateNow
            } else if response.rawValue == 1002 {
                if let outputDirectory = outputDirectory {
                    VideoConverter.cleanup(outputDirectory: outputDirectory) {
                        NSApplication.shared.reply(toApplicationShouldTerminate: true)
                    }
                }
                return .terminateLater
            }
        }
        return .terminateNow
    }
    
}
