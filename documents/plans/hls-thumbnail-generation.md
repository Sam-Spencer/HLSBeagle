# HLS Thumbnail Generation

**Created**: 2026-01-29  
**Status**: Planning  
**Contact**: Sam Spencer (@Sam-Spencer)

## Overview

Add thumbnail generation alongside HLS stream encoding. Thumbnails enable seek preview (scrubbing) in video players—a common UX pattern where users see preview images while dragging the seek bar.

## Scope

**In Scope:**
- Individual thumbnail extraction at configurable intervals
- Sprite sheet generation (combined image + WebVTT file)
- Integration with existing `VideoConverter` pipeline
- Optional generation (off by default to preserve current behavior)

**Out of Scope (Future):**
- I-frame only playlist (`#EXT-X-I-FRAMES-ONLY`) for trick mode
- Animated thumbnail GIFs
- Player-specific integrations

---

## Current Understanding

### Key Files
- `Sources/SwiftyHLS/VideoConverter.swift` — main conversion logic
- `Sources/SwiftyHLS/HLSParameters.swift` — encoding options
- `Sources/SwiftyHLS/VideoProcessor.swift` — video metadata extraction

### Thumbnail Approaches

| Approach | Pros | Cons |
|----------|------|------|
| **Individual JPEGs** | Simple, direct file access | Many small files, more HTTP requests |
| **Sprite Sheet + VTT** | Single image, standard format | Requires VTT parsing, larger initial download |
| **FFmpeg tile filter** | Single-pass, efficient | Fixed grid, less flexible |

**Decision:** Use **Sprite Sheet + VTT** approach. This is the industry standard for seek preview (YouTube, Netflix, JW Player). Individual thumbnails add HTTP overhead and file clutter.

### Concurrency Analysis

**Thumbnail generation can run concurrently with HLS encoding.** Key findings:

| Factor | HLS Encoding | Thumbnail Extraction | Conflict? |
|--------|-------------|---------------------|-----------|
| Input file | Read-only | Read-only | ✅ None |
| CPU usage | High (video encoder) | Low (decode + scale) | ✅ Minimal |
| Hardware encoder | VideoToolbox | Not used | ✅ None |
| Output files | `.ts` segments | `.jpg` + `.vtt` | ✅ Separate |

**Why it works:**
- Thumbnail extraction is **I/O bound** (keyframe seeking), not CPU bound
- No video encoding—just decode single frames, scale, JPEG compress
- Multiple FFmpeg processes can read the same input file safely
- Swift `TaskGroup` enables parallel execution

**Implementation approach:**
```swift
await withTaskGroup(of: Void.self) { group in
    // HLS encoding task
    group.addTask {
        await self.generateHLSStreams(...)
    }
    
    // Thumbnail generation task (concurrent)
    if options.thumbnailOptions?.enabled == true {
        group.addTask {
            await self.generateThumbnails(...)
        }
    }
}
```

**Optional flag:** Add `concurrent: Bool` to `HLSThumbnailOptions` for users on lower-end machines who prefer sequential processing.

### FFmpeg Commands

**Extract individual frames:**
```bash
ffmpeg -i input.mp4 -r 1 -s 320:180 -f image2 thumb_%03d.jpg
```
- `-r 1` = 1 frame per second
- `-s 320:180` = thumbnail dimensions
- `-f image2` = image sequence output

**Single-pass sprite with tile filter:**
```bash
ffmpeg -i input.mp4 -vf "select=not(mod(n\,300)),scale=160:-1,tile=10x10" -frames:v 1 sprite.jpg
```
- `select=not(mod(n\,300))` = every 300th frame (~10s at 30fps)
- `tile=10x10` = arrange into 10×10 grid

**WebVTT format for sprite:**
```
WEBVTT

00:00:00.000 --> 00:00:10.000
sprite.jpg#xywh=0,0,160,90

00:00:10.000 --> 00:00:20.000
sprite.jpg#xywh=160,0,160,90
```

---

## Implementation Checklist

### Phase 1: Core Types & Configuration

- [x] **1.1 Create `HLSThumbnailOptions` struct** ✓
  - `enabled: Bool` (default: false)
  - `interval: TimeInterval` (default: 10 seconds)
  - `width: Int` (default: 320) — height calculated from aspect ratio
  - `format: ThumbnailFormat` enum (.jpeg, .webp)
  - `spriteColumns: Int` (default: 10)
  - `concurrent: Bool` (default: true) — run alongside HLS encoding
  - File: `Sources/SwiftyHLS/HLSThumbnailOptions.swift`

- [x] **1.2 Add thumbnail options to `HLSParameters`** ✓
  - Add `thumbnailOptions: HLSThumbnailOptions?` property
  - Keep backward compatible (nil = no thumbnails)
  - File: `Sources/SwiftyHLS/HLSParameters.swift`

### Phase 2: Thumbnail Generator

- [x] **2.1 Create `ThumbnailGenerator` class** ✓
  - Separate from `VideoConverter` for single-responsibility
  - Async API matching `VideoConverter` style
  - File: `Sources/SwiftyHLS/ThumbnailGenerator.swift`
  
  **Public API:**
  ```swift
  public class ThumbnailGenerator {
      public func generateThumbnails(
          inputPath: String,
          outputDirectory: URL,
          options: HLSThumbnailOptions
      ) -> AsyncStream<ThumbnailProgress>
  }
  ```

- [x] **2.2 Implement frame extraction to temp directory** ✓
  - Build FFmpeg args for frame extraction at interval
  - Use `-ss` before `-i` for fast keyframe seeking
  - Extract to temp directory, clean up after sprite generation
  - Output naming: `thumb_%03d.jpg`

- [x] **2.3 Implement sprite sheet assembly** ✓
  - Use FFmpeg to tile extracted frames into single image
  - Calculate grid dimensions based on frame count + `spriteColumns`
  - Command: `ffmpeg -i thumb_%03d.jpg -filter_complex "tile=10xN" sprite.jpg`
  - Output: `thumbnails.jpg` in HLS output directory

- [x] **2.4 Implement VTT file generation** ✓
  - Pure Swift (no FFmpeg needed)
  - Calculate `#xywh` coordinates based on grid layout
  - Output: `thumbnails.vtt`

### Phase 3: Pipeline Integration & Concurrency

- [x] **3.1 Refactor `convertVideo()` for concurrent execution** ✓
  - Use `TaskGroup` to run HLS encoding + thumbnails in parallel
  - Honor `concurrent` flag in `HLSThumbnailOptions`
  - Sequential fallback: thumbnails after HLS encoding completes
  - File: `Sources/SwiftyHLS/VideoConverter.swift`

- [x] **3.2 Add `ThumbnailProgress` enum** ✓
  - States: `.extractingFrames(current:total:)`, `.assemblingSprite`, `.writingVTT`, `.completed`
  - File: `Sources/SwiftyHLS/ThumbnailProgress.swift`

- [x] **3.3 Update `ConversionProgress` to include thumbnail status** ✓
  - Add `.thumbnails(ThumbnailProgress)` case
  - Allows UI to display both HLS + thumbnail progress simultaneously

- [x] **3.4 Handle cancellation across concurrent tasks** ✓
  - Propagate `Task.isCancelled` to both HLS and thumbnail tasks
  - Clean up temp files on cancellation

### Phase 4: GUI Integration

- [x] **4.1 Add thumbnails panel to Inspector** ✓
  - New `OptionPanel` case: `.thumbnails`
  - File: `GUI/SwiftyHLSApp/Inspector.swift`
  - New SwiftUI view: `GUI/SwiftyHLSApp/InspectorThumbnails.swift`

- [x] **4.2 Add thumbnail toggle to Inspector** ✓
  - Checkbox: "Generate seek thumbnails"
  - If checked, show thumbnail options, otherwise hide
  - File: `GUI/SwiftyHLSApp/InspectorThumbnails.swift`

- [x] **4.3 Add thumbnail options UI** ✓
  - Interval picker (5s, 10s, 30s)
  - Size preset (Small 160px, Medium 320px, Large 480px)
  - Concurrent toggle (advanced option)
  - Store options in `AppStorage`
  - File: `GUI/SwiftyHLSApp/InspectorThumbnails.swift`

- [x] **4.4 Wire up to `ContentViewModel`** ✓
  - Pass options to `HLSParameters`
  - File: `GUI/SwiftyHLSApp/ContentViewModel.swift`

- [x] **4.5 Add thumbnail progress to UI** ✓
  - Show progress in `ConversionProgress`
  - File: `GUI/SwiftyHLSApp/ConversionProgress.swift`

### Phase 5: Testing

- [x] **5.1 Unit tests for FFmpeg argument generation** ✓
  - Verify correct thumbnail extraction args
  - File: `Tests/SwiftyHLSTests/ThumbnailGeneratorTests.swift`

- [x] **5.2 Unit tests for VTT generation** ✓
  - Verify correct timecodes and coordinates
  - Test edge cases (short videos, single frame)

- [x] **5.3 Integration test** ✓
  - End-to-end thumbnail generation
  - Verify output files exist and are valid

---

## Technical Notes

### Thumbnail Size Recommendations

| Use Case | Size | Aspect Ratio |
|----------|------|--------------|
| Mobile seek preview | 160×90 | 16:9 |
| Desktop seek preview | 320×180 | 16:9 |
| High-density displays | 480×270 | 16:9 |

### Sprite Sheet Limits

- Most players limit sprite size to ~8192×8192 px
- For 320×180 thumbs at 10 columns: max ~40 rows = 400 thumbnails = ~66 min video at 10s intervals
- Longer videos may need multiple sprite sheets

### Performance Considerations

1. **Seek-based extraction** (`-ss` before `-i`) is faster than full decode
2. **Hardware scaling** may help: `-vf "scale=320:180:flags=fast_bilinear"`
3. **Parallel extraction** possible but may not improve speed (I/O bound)

---

## References

- [FFmpeg image2 muxer](https://ffmpeg.org/ffmpeg-formats.html#image2-2)
- [WebVTT with Media Fragments](https://www.w3.org/TR/media-frags/)
- [JW Player Thumbnail Preview](https://docs.jwplayer.com/players/docs/jw8-add-preview-thumbnails)
- [Video.js Thumbnails Plugin](https://github.com/brightcove/videojs-thumbnails)

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-01-29 | Plan created |
| 2026-01-29 | Decision: Sprite Sheet + VTT approach (not individual JPEGs or tile filter) |
| 2026-01-29 | Added concurrency analysis: thumbnail generation can run in parallel with HLS encoding |
| 2026-01-29 | ✓ Phase 1 complete: Created `HLSThumbnailOptions` struct with size presets and interval presets |
| 2026-01-29 | ✓ Phase 2 complete: Created `ThumbnailGenerator` class with frame extraction, sprite assembly, VTT generation |
| 2026-01-29 | ✓ Phase 3 complete: Integrated into `VideoConverter` with `TaskGroup` for concurrent execution |
| 2026-01-29 | ✓ Phase 4 complete: GUI integration with `InspectorThumbnails` view, `AppStorage` persistence, progress handling |
| 2026-01-29 | ✓ Phase 5 complete: 8 new unit tests for VTT generation, sprite coordinates, options defaults, presets |
| 2026-01-29 | **IMPLEMENTATION COMPLETE** - All phases finished, 13 tests passing |
