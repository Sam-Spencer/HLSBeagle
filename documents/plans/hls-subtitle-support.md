# HLS Subtitle Support

**Created**: 2026-01-29  
**Status**: Planning  
**Contact**: Sam Spencer (@Sam-Spencer)

## Overview

Add subtitle support when converting video to HLS streams. Subtitles should be extracted from source video (embedded) or provided externally, converted to WebVTT format, segmented, and included in the master playlist per HLS spec.

## Scope

**In Scope:**
- Extract embedded subtitles from source containers (MKV, MP4)
- Accept external subtitle files (SRT, VTT, ASS)
- Convert subtitles to WebVTT (HLS-required format)
- Segment subtitles to align with video segments
- Generate subtitle playlist (`subtitles.m3u8`)
- Update master playlist with `#EXT-X-MEDIA:TYPE=SUBTITLES` tags
- Support multiple subtitle tracks/languages
- User-facing options (enable/disable, language selection)

**Out of Scope (Future):**
- Closed captions (CEA-608/708)
- Burned-in subtitles (hardcoded into video)
- Real-time subtitle generation (live streams)

---

## Current Understanding

### Key Files
- `Sources/SwiftyHLS/VideoConverter.swift` — main conversion logic
- `Sources/SwiftyHLS/HLSParameters.swift` — encoding options
- Master playlist generation in `createMasterPlaylist()`

### HLS Subtitle Requirements

Per Apple HLS spec:
- Subtitles must be **WebVTT** format
- Each subtitle track needs its own `.m3u8` playlist
- Segments should align with video segment duration
- Master playlist references subtitles via `#EXT-X-MEDIA:TYPE=SUBTITLES`
- Variant streams reference subtitle group via `SUBTITLES=` attribute

### FFmpeg Approach: Separate Segmentation

```bash
# Segment subtitles independently from video encoding
ffmpeg -i input.mkv \
  -vn -an \
  -map 0:s:0 \
  -c:s webvtt \
  -f segment \
  -segment_time 10 \
  -segment_list subtitles_en.m3u8 \
  subtitle_en_%04d.vtt
```

**Advantages:**
- Cleaner separation of concerns
- Easier to handle multiple languages (one call per track)
- Aligns with current per-resolution stream architecture
- **Enables concurrent execution** with video encoding

### Concurrency Model

Subtitle processing has **no dependencies** on video encoding:
- Both read from the same input file
- Subtitles use `-vn -an` (no video/audio processing)
- Outputs are completely separate

**Implementation:** Use same `TaskGroup` pattern as thumbnail generation:
```swift
await withTaskGroup(of: [String].self) { group in
    group.addTask { await generateHLSStreams(...) }        // Video
    group.addTask { await generateThumbnailsIfEnabled(...) } // Thumbnails  
    group.addTask { await generateSubtitlesIfEnabled(...) }  // Subtitles ← NEW
    ...
}
```

Subtitle segmentation is faster than video encoding, so it will complete early and not block.

### Subtitle Detection

```bash
# Detect embedded subtitle streams
ffprobe -v error -select_streams s \
  -show_entries stream=index,codec_name:stream_tags=language \
  -of csv=p=0 input.mkv
```

---

## Implementation Checklist

### Phase 1: Data Models & Configuration

- [x] **1.1 Create `HLSSubtitleOptions.swift`** ✓
  - `enabled: Bool` — toggle subtitle processing
  - `extractEmbedded: Bool` — extract from source container
  - `externalFiles: [HLSExternalSubtitle]` — external subtitle files with language/name/forced
  - `defaultLanguage: String?` — mark default track
  - `concurrent: Bool` — run alongside video encoding (default: `true`)
  - Also includes `HLSExternalSubtitle` struct and `HLSSubtitleFormat` enum
  - File: `Sources/SwiftyHLS/HLSSubtitleOptions.swift`
  - **Completed**: 2026-01-29

- [x] **1.2 Create `HLSSubtitleTrack.swift`** ✓
  - Model for detected/configured subtitle tracks
  - Properties: `index`, `language`, `name`, `isDefault`, `isForced`, `source`, `codec`, `sourcePath`
  - Computed: `playlistFilename`, `segmentPattern`
  - Includes `SubtitleSource` enum and language display name utilities
  - File: `Sources/SwiftyHLS/HLSSubtitleTrack.swift`
  - **Completed**: 2026-01-29

- [x] **1.3 Update `HLSParameters.swift`** ✓
  - Add `subtitleOptions: HLSSubtitleOptions?` property
  - File: `Sources/SwiftyHLS/HLSParameters.swift`
  - **Completed**: 2026-01-29

- [x] **1.4 Update `ConversionProgress.swift`** ✓
  - Add `.subtitles(SubtitleProgress)` case for progress reporting
  - Created `SubtitleProgress.swift` with states: `started`, `detectingStreams`, `extracting`, `segmenting`, `writingPlaylist`, `completed`, `failed`
  - Files: `Sources/SwiftyHLS/ConversionProgress.swift`, `Sources/SwiftyHLS/SubtitleProgress.swift`
  - **Completed**: 2026-01-29

### Phase 2: Subtitle Detection & Extraction

- [x] **2.1 Add subtitle stream detection to `VideoProcessor.swift`** ✓
  - Function: `getSubtitleStreams(inputPath:) -> [HLSSubtitleTrack]`
  - Uses ffprobe with JSON output to detect embedded subtitle streams
  - Returns stream index, codec, language tag, title
  - Added `ffprobePath()` to `InstallManager.swift`
  - File: `Sources/SwiftyHLS/VideoProcessor.swift`
  - **Completed**: 2026-01-29

- [x] **2.2 Create `SubtitleProcessor.swift`** ✓
  - Core subtitle processing logic with `processSubtitles()` async stream
  - Handles both embedded and external subtitle sources
  - Extracts, converts to WebVTT, and segments subtitles
  - File: `Sources/SwiftyHLS/SubtitleProcessor.swift`
  - **Completed**: 2026-01-29

### Phase 3: WebVTT Conversion & Segmentation

- [x] **3.1 Implement subtitle extraction from container** ✓
  - Extracts subtitle stream using FFmpeg `-map 0:N` (by stream index)
  - Converts to WebVTT using `-c:s webvtt`
  - Handles embedded and external sources
  - **Completed**: 2026-01-29

- [x] **3.2 Implement subtitle segmentation** ✓
  - Uses FFmpeg segment muxer: `-f segment -segment_list`
  - Aligns segment duration with video via `targetDuration` parameter
  - Output pattern: `subtitle_{lang}_%04d.vtt`
  - **Completed**: 2026-01-29

- [x] **3.3 Generate per-language subtitle playlists** ✓
  - Each language gets its own `.m3u8` playlist
  - Naming via `HLSSubtitleTrack.playlistFilename` computed property
  - Post-processes playlist to add `#EXT-X-PLAYLIST-TYPE:VOD` and `#EXT-X-ENDLIST`
  - **Completed**: 2026-01-29

### Phase 4: Master Playlist Integration

- [x] **4.1 Update `createMasterPlaylist()` for subtitles** ✓
  - Added `subtitleTracks` parameter to function
  - Adds `#EXT-X-MEDIA:TYPE=SUBTITLES` entries with GROUP-ID, LANGUAGE, NAME, DEFAULT, AUTOSELECT, FORCED, URI
  - File: `Sources/SwiftyHLS/VideoConverter.swift`
  - **Completed**: 2026-01-29

- [x] **4.2 Update variant stream entries** ✓
  - Adds `SUBTITLES="subs"` attribute to `#EXT-X-STREAM-INF` lines when subtitles present
  - **Completed**: 2026-01-29

### Phase 5: Integration with VideoConverter

- [x] **5.1 Add subtitle processing to conversion flow** ✓
  - Added `VideoConverterTaskResult` enum for TaskGroup coordination
  - Added `generateSubtitlesIfEnabled()` method
  - Supports concurrent execution alongside video encoding and thumbnails
  - Passes processed tracks to master playlist generation
  - File: `Sources/SwiftyHLS/VideoConverter.swift`
  - **Completed**: 2026-01-29

- [x] **5.2 Handle external subtitle files** ✓
  - `SubtitleProcessor.createTracksFromExternalFiles()` handles external files
  - Format auto-detected via `HLSSubtitleFormat.from(path:)`
  - Supports: `.srt`, `.vtt`, `.ass`, `.ssa`
  - **Completed**: 2026-01-29

### Phase 6: GUI Integration

- [x] **6.1 Add subtitle options to Inspector** ✓
  - Created `InspectorSubtitles.swift` with toggles for enable, extract embedded, concurrent
  - Added `subtitles` case to `Inspector.OptionPanel` enum
  - Wired up panel in `Inspector.swift` switch statement
  - Files: `GUI/SwiftyHLSApp/InspectorSubtitles.swift`, `GUI/SwiftyHLSApp/Inspector.swift`
  - **Completed**: 2026-01-29

- [x] **6.2 Update ContentViewModel** ✓
  - Wired subtitle options from UserDefaults to `HLSParameters`
  - Added `.subtitles` case handler for `SubtitleProgress` updates
  - File: `GUI/SwiftyHLSApp/ContentViewModel.swift`
  - **Completed**: 2026-01-29

### Phase 7: Testing

- [x] **7.1 Unit tests for subtitle track properties** ✓
  - `subtitleTrackPlaylistFilename()` - standard playlist naming
  - `subtitleTrackPlaylistFilenameForced()` - forced subtitle naming
  - `subtitleTrackSegmentPattern()` - segment file patterns
  - `subtitleTrackSegmentPatternForced()` - forced segment patterns
  - `subtitleTrackId()` - unique ID generation
  - File: `Tests/SwiftyHLSTests/SubtitleTests.swift`
  - **Completed**: 2026-01-29

- [x] **7.2 Unit tests for language utilities** ✓
  - `languageDisplayNameCommonCodes()` - ISO 639-1/2 mappings
  - `languageDisplayNameUnknownCode()` - fallback behavior
  - `languageDisplayNameCaseInsensitive()` - case handling
  - **Completed**: 2026-01-29

- [x] **7.3 Unit tests for subtitle format detection** ✓
  - `subtitleFormatFromPath()` - extension detection
  - `subtitleFormatFromPathCaseInsensitive()` - case handling
  - `subtitleFormatFromPathUnsupported()` - unknown formats
  - `subtitleFormatFileExtension()` - extension properties
  - `subtitleFormatDisplayName()` - UI display names
  - **Completed**: 2026-01-29

- [x] **7.4 Unit tests for HLSSubtitleOptions** ✓
  - `subtitleOptionsDefaults()` - default values
  - `subtitleOptionsCustomValues()` - custom configuration
  - **Completed**: 2026-01-29

- [x] **7.5 Unit tests for HLSExternalSubtitle** ✓
  - `externalSubtitleProperties()` - all properties
  - `externalSubtitleDefaults()` - default values
  - `externalSubtitleEquatable()` - equality comparison
  - **Completed**: 2026-01-29

- [x] **7.6 Unit tests for SubtitleProgress** ✓
  - `subtitleProgressCases()` - all enum cases
  - **Completed**: 2026-01-29

---

## Technical Notes

### FFmpeg Subtitle Codecs
| Input Format | FFmpeg Codec | Notes |
|--------------|--------------|-------|
| SRT | `subrip` | Text-based, no styling |
| VTT | `webvtt` | HLS-native format |
| ASS/SSA | `ass` | Styled, needs conversion |
| PGS (Blu-ray) | `pgssub` | Image-based, not supported |

### Master Playlist Subtitle Format
```m3u8
#EXTM3U
#EXT-X-VERSION:3

#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,URI="subtitles_en.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",DEFAULT=NO,AUTOSELECT=YES,URI="subtitles_es.m3u8"

#EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080,SUBTITLES="subs"
variant_1080p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1280x720,SUBTITLES="subs"
variant_720p.m3u8
```

### Subtitle Segment Playlist Format
```m3u8
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:10
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD

#EXTINF:10.000,
subtitle_en_0000.vtt
#EXTINF:10.000,
subtitle_en_0001.vtt
#EXTINF:8.500,
subtitle_en_0002.vtt

#EXT-X-ENDLIST
```

### Language Code Standards
- Use ISO 639-1 (2-letter) or ISO 639-2 (3-letter) codes
- Common: `en`, `es`, `fr`, `de`, `ja`, `zh`
- FFmpeg reports language via `stream_tags=language`

---

## References

- [FFmpeg HLS Muxer Documentation](https://ffmpeg.org/ffmpeg-formats.html#hls-2)
- [FFmpeg Segment Muxer](https://ffmpeg.org/ffmpeg-formats.html#segment_002c-stream_005fsegment_002c-ssegment)
- [Apple HLS Authoring Spec - Subtitles](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices#Subtitles)
- [WebVTT Spec](https://www.w3.org/TR/webvtt1/)

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-01-29 | Plan created |
| 2026-01-29 | ✓ Phase 1 complete: Data models & configuration |
| 2026-01-29 | ✓ Phase 2-5 complete: Core subtitle processing, master playlist integration, VideoConverter integration |
| 2026-01-29 | ✓ Phase 6 complete: GUI integration with InspectorSubtitles panel |
| 2026-01-29 | ✓ Phase 7 complete: 19 unit tests for subtitle functionality |
