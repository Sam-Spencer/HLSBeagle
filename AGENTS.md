# AGENTS.md
Sam owns this. Start: say hi + 1 motivating line. Work style: telegraph; noun-phrases ok; drop grammar; min tokens.

## Agent Protocol
- Contact: Sam Spencer
    - Role: Lead Engineer
    - GitHub: @Sam-Spencer
- "Make a note" => edit AGENTS.md (shortcut; not a blocker)
- Bugs: add regression test when it fits.
- Keep files < ~500 LOC; split/refactor as needed.
- Prefer end-to-end verify; if blocked, say what’s missing.
- New deps: quick health check (recent releases/commits, adoption).
- Web: search early; quote exact errors; prefer 2025–2026 sources
- Style: telegraph. Drop filler/grammar. Min tokens (global AGENTS + replies).

## Git
- Safe by default: `git status`, `git diff`, `git log`, etc.
- Use `git status`, etc. to check for existing changes before starting a task or for additional context about recent changes since the last push or commit.
- Branch changes require user consent.
- Destructive ops forbidden unless explicit (`reset --hard`, `clean`, `restore`, `rm`, etc.).
- Don’t delete/rename unexpected stuff; stop + ask.

## Project Overview

**HLS Beagle** is a Swift Package and Mac app for transcoding video files into adaptive HLS (HTTP Live Streaming) streams using FFmpeg. The project provides:

- A **Swift Package** (`SwiftyHLS`) for programmatic video conversion
- A **Mac app** (GUI) with a drag-and-drop interface for end users

## Repository Structure

```
SwiftyHLS/
├── Sources/SwiftyHLS/      # Swift Package library
├── GUI/                     # Mac app (SwiftUI)
│   ├── SwiftyHLSApp/       # App source files
│   └── SwiftyHLSApp.xcodeproj/
├── Tests/SwiftyHLSTests/   # Unit tests
├── Docs/                    # Documentation assets
└── Archives/                # Release archives
```

## Technical Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 6 |
| Package Manager | Swift Package Manager |
| UI Framework | SwiftUI |
| Minimum Target (Package) | macOS 14.0 |
| Minimum Target (App) | macOS 15.0 |
| Logging | OSLog |
| Concurrency | Swift Concurrency (async/await, AsyncStream) |
| Testing | Swift Testing framework (`@Test`) |

## External Dependencies

- **FFmpeg**: Required at runtime (not bundled). The package checks for FFmpeg at common paths:
  - `/opt/homebrew/bin/ffmpeg` (Apple Silicon)
  - `/usr/local/bin/ffmpeg` (Intel)
  - `/usr/bin/ffmpeg` (manual installs)

## Key Components

### Swift Package (`Sources/SwiftyHLS/`)

| File | Purpose |
|------|---------|
| `SwiftyHLS.swift` | Main entry point; exports `SwiftHLS` struct |
| `VideoConverter.swift` | Core conversion logic using FFmpeg |
| `VideoProcessor.swift` | Video metadata extraction |
| `InstallManager.swift` | FFmpeg installation detection and management |
| `HLSParameters.swift` | Configuration struct for encoding options |
| `HLSResolution.swift` | Resolution definitions and bitrate mappings |
| `HLSEncoders.swift` | Encoder enum (H.264/H.265, hardware/software) |
| `ConversionProgress.swift` | Progress reporting enum |
| `SwiftyHLSError.swift` | Custom error types |

### Mac App (`GUI/SwiftyHLSApp/`)

| File | Purpose |
|------|---------|
| `SwiftyHLSAppApp.swift` | App entry point with AppDelegate |
| `ContentView.swift` | Main view |
| `ContentViewModel.swift` | ViewModel with conversion logic |
| `FileDropComponent.swift` | Drag-and-drop file handling |
| `Inspector.swift` | Settings panel |

## Coding Conventions

### Code Organization
- Use `// MARK: -` comments to organize code sections
- Group related functionality (e.g., `// MARK: - Conversion`, `// MARK: - Encoders`)

### Swift Concurrency
- Types that cross concurrency boundaries must be `Sendable`
- Use `AsyncStream` for progress reporting

### Logging
Use the internal `logger` (OSLog) for debugging:
```swift
logger.trace("Message")
logger.info("Message")
logger.error("Message")
```

### Documentation
- Public APIs should have DocC style documentation comments (`///`)
- Use descriptive parameter and return value documentation

## Building & Testing

### Swift Package
```bash
# Build
swift build

# Run tests
swift test
```

### Mac App
Open `GUI/SwiftyHLSApp.xcodeproj` in Xcode and build/run from there.

## Common Tasks

### Adding a New Resolution
1. Add the resolution to `HLSResolution.swift`
2. Include width, height, and target bitrate

### Adding a New Encoder
1. Add the encoder case to `HLSEncoders.swift`
2. Update `bestAvailableEncoder()` in `VideoConverter.swift`

### Modifying FFmpeg Arguments
Edit `generateResolutionStream()` in `VideoConverter.swift` to adjust FFmpeg command-line arguments.

## Important Notes

1. **FFmpeg is not bundled** - The app requires users to have FFmpeg installed (typically via Homebrew)
2. **No upscaling** - The converter filters out resolutions larger than the input video
3. **Hardware acceleration** - The code detects and prefers hardware encoders when available (VideoToolbox on Apple Silicon, QuickSync on Intel)
4. **Cancellation** - Video conversion supports task cancellation via Swift's cooperative cancellation

You should try to consult the official FFMPEG documentation whenever possible.

## Critical Thinking
- Fix root cause (not band-aid).
- Unsure: read more code; if still stuck, ask w/ short options.
- Conflicts: call out; pick safer path.
- Unrecognized changes: assume other agent; keep going; focus your changes. If it causes issues, stop + ask user.
- Leave breadcrumb notes in thread.
