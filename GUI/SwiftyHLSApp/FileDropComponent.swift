//
//  FileDropComponent.swift
//  SwiftyHLSApp
//
//  Created by Sam Spencer on 3/3/25.
//  Copyright © 2025 Sam Spencer. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

public struct FileDropComponent: View {
    
    var selectedPath: String?
    var selectedName: String?
    let instructions: String
    var defaultIcon: String = "questionmark.folder"
    var onSelect: (() -> Void)?
    var onDrop: (([NSItemProvider]) -> Bool)?
    
    @State private var isDraggingOver = false
    @State private var dashPhase: CGFloat = 0.0
    
    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                selectionIcon
                selectionLabel
                Spacer()
            }
            .padding(.all, 12)
        }
        .background(Material.regular)
        .overlay {
            borderOverlay
        }
        .cornerRadius(8)
        .onTapGesture {
            onSelect?()
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDraggingOver) { providers in
            return onDrop?(providers) ?? false
        }
        .onChange(of: isDraggingOver) {
            if isDraggingOver {
                startMarchingAntsAnimation()
            }
        }
        .animation(.bouncy, value: isDraggingOver)
        .animation(.smooth, value: selectedPath)
        .contextMenu {
            if let selectedPath {
                Button {
                    NSWorkspace.shared.selectFile(
                        selectedPath, 
                        inFileViewerRootedAtPath: ""
                    )
                } label: {
                    Text("Show in Finder")
                }
            }
        }
    }
    
    @ViewBuilder
    private var selectionIcon: some View {
        if let selectedPath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: selectedPath))
                .resizable()
                .frame(width: 32, height: 32)
                .cornerRadius(6)
        } else {
            Image(systemName: defaultIcon)
                .resizable()
                .fontWeight(.light)
                .aspectRatio(contentMode: .fit)
                .frame(width: 32)
                .foregroundStyle(Color.secondary)
                .padding(.trailing, 8)
        }
    }
    
    private var selectionLabel: some View {
        VStack(alignment: .leading) {
            if let selectedPath, let selectedName {
                Text(selectedName)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Text(selectedPath)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Text(instructions)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(
                borderColor,
                style: StrokeStyle(
                    lineWidth: 2,
                    dash: selectedPath == nil
                        ? [5, 5]
                        : [],
                    dashPhase: isDraggingOver ? dashPhase : 0 // Animate when dragging
                )
            )
    }
    
    private var borderColor: Color {
        if selectedPath != nil {
            return Color.blue
        } else {
            if isDraggingOver {
                return Color.teal
            } else {
                return Color.gray.opacity(0.5)
            }
        }
    }
    
    private func startMarchingAntsAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            dashPhase -= 3 // Move the dashes
            if !isDraggingOver {
                timer.invalidate() // Stop the animation when dragging ends
            }
        }
    }
    
}

#Preview("File Drop: No Selection") {
    @Previewable @State var selectedPath: String? = nil
    @Previewable @State var selectedName: String? = nil
    FileDropComponent(selectedPath: selectedPath, selectedName: selectedName, instructions: "Drag & Drop a Video File Here\nor Click to Select") {
        
    } onDrop: { providers in
        return true
    }
}
