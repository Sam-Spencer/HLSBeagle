import Foundation
import Testing
@testable import SwiftyHLS

// MARK: - VTT Generation Tests

@Test func vttTimecodeFormattingIsCorrect() async throws {
    // Test timecode formatting for VTT
    let testCases: [(TimeInterval, String)] = [
        (0, "00:00:00.000"),
        (10, "00:00:10.000"),
        (65, "00:01:05.000"),
        (3661.5, "01:01:01.500"),
        (7200, "02:00:00.000")
    ]
    
    for (seconds, expected) in testCases {
        let formatted = formatVTTTimecode(seconds)
        #expect(formatted == expected, "Expected \(expected) for \(seconds) seconds, got \(formatted)")
    }
}

@Test func spriteCoordinatesCalculation() async throws {
    // Test sprite coordinate calculation
    let thumbWidth = 160
    let thumbHeight = 90
    let columns = 10
    
    // Frame 0 should be at (0, 0)
    let coords0 = calculateSpriteCoordinates(frameIndex: 0, thumbWidth: thumbWidth, thumbHeight: thumbHeight, columns: columns)
    #expect(coords0.x == 0)
    #expect(coords0.y == 0)
    
    // Frame 5 should be at (800, 0)
    let coords5 = calculateSpriteCoordinates(frameIndex: 5, thumbWidth: thumbWidth, thumbHeight: thumbHeight, columns: columns)
    #expect(coords5.x == 800)
    #expect(coords5.y == 0)
    
    // Frame 10 should be at (0, 90) - first frame of second row
    let coords10 = calculateSpriteCoordinates(frameIndex: 10, thumbWidth: thumbWidth, thumbHeight: thumbHeight, columns: columns)
    #expect(coords10.x == 0)
    #expect(coords10.y == 90)
    
    // Frame 15 should be at (800, 90)
    let coords15 = calculateSpriteCoordinates(frameIndex: 15, thumbWidth: thumbWidth, thumbHeight: thumbHeight, columns: columns)
    #expect(coords15.x == 800)
    #expect(coords15.y == 90)
}

@Test func vttContentGeneration() async throws {
    // Test VTT content generation for a simple case
    let options = HLSThumbnailOptions(
        enabled: true,
        interval: 10,
        width: 160,
        spriteColumns: 5
    )
    let thumbHeight = 90
    let frameCount = 6  // 60 second video at 10s intervals
    
    let vttContent = generateVTTContent(
        frameCount: frameCount,
        interval: options.interval,
        thumbWidth: options.width,
        thumbHeight: thumbHeight,
        spriteColumns: options.spriteColumns,
        spriteFilename: "thumbnails.jpg"
    )
    
    #expect(vttContent.hasPrefix("WEBVTT"))
    #expect(vttContent.contains("00:00:00.000 --> 00:00:10.000"))
    #expect(vttContent.contains("thumbnails.jpg#xywh=0,0,160,90"))
    #expect(vttContent.contains("00:00:50.000 --> 00:01:00.000"))
    // Frame 5 is at column 0 of row 1 (5 columns per row)
    #expect(vttContent.contains("thumbnails.jpg#xywh=0,90,160,90"))
}

@Test func frameCountCalculation() async throws {
    // Test frame count calculation from video duration and interval
    let testCases: [(TimeInterval, TimeInterval, Int)] = [
        (60, 10, 6),    // 60s video, 10s interval = 6 frames
        (100, 10, 10),  // 100s video, 10s interval = 10 frames
        (30, 5, 6),     // 30s video, 5s interval = 6 frames
        (120, 30, 4),   // 120s video, 30s interval = 4 frames
        (5, 10, 0),     // 5s video, 10s interval = 0 frames (video too short)
    ]
    
    for (duration, interval, expectedFrames) in testCases {
        let frameCount = Int(duration / interval)
        #expect(frameCount == expectedFrames, "Expected \(expectedFrames) frames for \(duration)s at \(interval)s interval")
    }
}

@Test func thumbnailOptionsDefaults() async throws {
    // Test default values
    let options = HLSThumbnailOptions()
    
    #expect(options.enabled == false)
    #expect(options.interval == 10)
    #expect(options.width == 320)
    #expect(options.format == .jpeg)
    #expect(options.spriteColumns == 10)
    #expect(options.concurrent == true)
}

@Test func thumbnailSizePresetValues() async throws {
    #expect(HLSThumbnailSizePreset.small.width == 160)
    #expect(HLSThumbnailSizePreset.medium.width == 320)
    #expect(HLSThumbnailSizePreset.large.width == 480)
}

@Test func thumbnailIntervalPresetValues() async throws {
    #expect(HLSThumbnailIntervalPreset.frequent.interval == 5)
    #expect(HLSThumbnailIntervalPreset.standard.interval == 10)
    #expect(HLSThumbnailIntervalPreset.sparse.interval == 30)
}

@Test func thumbnailFormatExtensions() async throws {
    #expect(HLSThumbnailFormat.jpeg.fileExtension == "jpg")
    #expect(HLSThumbnailFormat.webp.fileExtension == "webp")
}

// MARK: - Helper Functions

private func formatVTTTimecode(_ seconds: TimeInterval) -> String {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60
    let millis = Int((seconds.truncatingRemainder(dividingBy: 1)) * 1000)
    return String(format: "%02d:%02d:%02d.%03d", hours, minutes, secs, millis)
}

private func calculateSpriteCoordinates(
    frameIndex: Int,
    thumbWidth: Int,
    thumbHeight: Int,
    columns: Int
) -> (x: Int, y: Int) {
    let col = frameIndex % columns
    let row = frameIndex / columns
    return (x: col * thumbWidth, y: row * thumbHeight)
}

private func generateVTTContent(
    frameCount: Int,
    interval: TimeInterval,
    thumbWidth: Int,
    thumbHeight: Int,
    spriteColumns: Int,
    spriteFilename: String
) -> String {
    var content = "WEBVTT\n\n"
    
    for i in 0..<frameCount {
        let startTime = Double(i) * interval
        let endTime = startTime + interval
        
        let col = i % spriteColumns
        let row = i / spriteColumns
        let x = col * thumbWidth
        let y = row * thumbHeight
        
        content += "\(formatVTTTimecode(startTime)) --> \(formatVTTTimecode(endTime))\n"
        content += "\(spriteFilename)#xywh=\(x),\(y),\(thumbWidth),\(thumbHeight)\n\n"
    }
    
    return content
}
