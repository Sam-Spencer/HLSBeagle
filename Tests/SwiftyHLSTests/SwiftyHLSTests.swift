import Foundation
import Testing
@testable import SwiftyHLS

private func containsPair(_ args: [String], _ key: String, _ value: String) -> Bool {
    guard let index = args.firstIndex(of: key), index + 1 < args.count else {
        return false
    }
    return args[index + 1] == value
}

private func value(after key: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: key), index + 1 < args.count else {
        return nil
    }
    return args[index + 1]
}

@Test func ffmpegArgumentsIncludeHlsFlags() async throws {
    let options = HLSParameters(
        startNumber: 7,
        targetDuration: 6,
        preferredEncoder: nil,
        videoEncodingFormat: .h264,
        encodingPreset: .slow,
        qualityPreset: .balanced,
        audioCodec: .aac,
        audioBitrate: .bitrate128k
    )
    let resolution = HLSResolution.resolution720p.resolution
    let outputDirectory = URL(fileURLWithPath: "/tmp")
    let args = VideoConverter.buildFFmpegArguments(
        inputPath: "/tmp/input.mp4",
        outputDirectory: outputDirectory,
        resolution: resolution,
        encoder: .h264SoftwareRenderer,
        options: options
    )

    #expect(containsPair(args, "-hls_playlist_type", "vod"))
    #expect(containsPair(args, "-hls_flags", "independent_segments"))
    #expect(containsPair(args, "-start_number", "7"))
    #expect(containsPair(args, "-hls_time", "6.0"))
    #expect(containsPair(args, "-movflags", "+faststart"))
    #expect(containsPair(args, "-maxrate", "1500k"))
    #expect(containsPair(args, "-bufsize", "3000k"))
    #expect(!args.contains("-b:v"))
}

@Test func rateControlArgumentsHaveExpectedSuffixesAndRatio() async throws {
    let options = HLSParameters(
        startNumber: 0,
        targetDuration: 10,
        preferredEncoder: nil,
        videoEncodingFormat: .h264,
        encodingPreset: .slow,
        qualityPreset: .balanced,
        audioCodec: .aac,
        audioBitrate: .bitrate128k
    )
    let resolution = HLSResolution.resolution1080p.resolution
    let args = VideoConverter.buildFFmpegArguments(
        inputPath: "/tmp/input.mp4",
        outputDirectory: URL(fileURLWithPath: "/tmp"),
        resolution: resolution,
        encoder: .h264SoftwareRenderer,
        options: options
    )

    let maxrate = value(after: "-maxrate", in: args)
    let bufsize = value(after: "-bufsize", in: args)

    #expect(maxrate?.hasSuffix("k") == true)
    #expect(bufsize?.hasSuffix("k") == true)

    let maxrateValue = Int(maxrate?.dropLast() ?? "")
    let bufsizeValue = Int(bufsize?.dropLast() ?? "")
    #expect(maxrateValue == 3000)
    #expect(bufsizeValue == 6000)
    #expect(bufsizeValue == maxrateValue.map { $0 * 2 })
}

@Test func hardwareEncoderSelectionPrefersSupportedEncoder() async throws {
    let encoder = VideoConverter.bestAvailableEncoderForTesting(
        preferredEncoder: nil,
        encodeFormat: .h265,
        encoderSupported: { candidate in
            candidate == .h265HardwareAccelerated
        }
    )
    #expect(encoder == .h265HardwareAccelerated)
}

@Test func hardwareEncoderArgumentsIncludeCrf() async throws {
    let options = HLSParameters(
        startNumber: 0,
        targetDuration: 10,
        preferredEncoder: nil,
        videoEncodingFormat: .h265,
        encodingPreset: .slow,
        qualityPreset: .high,
        audioCodec: .aac,
        audioBitrate: .bitrate128k
    )
    let resolution = HLSResolution.resolution720p.resolution
    let args = VideoConverter.buildFFmpegArguments(
        inputPath: "/tmp/input.mp4",
        outputDirectory: URL(fileURLWithPath: "/tmp"),
        resolution: resolution,
        encoder: .h265HardwareAccelerated,
        options: options
    )

    #expect(containsPair(args, "-crf", "24"))
    #expect(containsPair(args, "-maxrate", "1500k"))
    #expect(containsPair(args, "-bufsize", "3000k"))
    #expect(!args.contains("-b:v"))
}

@Test func encoderDetectionReturnsValidEncoder() async throws {
    let encoder = VideoConverter.bestAvailableEncoderForTesting(
        preferredEncoder: nil,
        encodeFormat: .h264,
        encoderSupported: { encoder in
            encoder == .h264SoftwareRenderer
        }
    )
    #expect(encoder == .h264SoftwareRenderer)
}
