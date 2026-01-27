# FFmpeg HLS Encoding Improvements

**Created**: 2026-01-27  
**Status**: Planning  
**Contact**: Sam Spencer (@Sam-Spencer)

## Overview

This plan addresses FFmpeg gotchas and best practices identified during a codebase review. The current implementation has several issues that affect HLS stream quality, ABR switching, and compatibility.

## Scope

Improve `VideoConverter.swift` and related files to follow FFmpeg HLS encoding best practices.

**In Scope:**
- Keyframe alignment for ABR
- Rate control fixes
- HLS playlist improvements
- Bug fixes

**Out of Scope (Future):**
- Single-pass multi-output encoding
- fMP4/CMAF segments
- HDR passthrough

---

## Current Understanding

### Key Files
- `Sources/SwiftyHLS/VideoConverter.swift` — main conversion logic
- `Sources/SwiftyHLS/HLSParameters.swift` — encoding options
- `Sources/SwiftyHLS/HLSResolution.swift` — resolution/bitrate mappings

### Identified Issues

| Issue | Severity | Location |
|-------|----------|----------|
| Missing keyframe alignment flags | Critical | `VideoConverter.swift:105-200` |
| Conflicting `-crf` + `-b:v` rate control | High | `VideoConverter.swift:131,140` |
| Missing `-hls_playlist_type vod` | Medium | `VideoConverter.swift:148-155` |
| Missing `-hls_flags independent_segments` | Medium | `VideoConverter.swift:148-155` |
| Encoder detection bug (extra "ffmpeg" arg) | High | `VideoConverter.swift:272` |
| `startNumber` param unused | Low | `HLSParameters.swift:10` |

---

## Implementation Checklist

### Phase 1: Critical Fixes (High Priority)

- [x] **1.1 Add keyframe alignment flags** ✓
  - Add `-g 48 -keyint_min 48 -sc_threshold 0` to FFmpeg args
  - These ensure keyframes align across resolutions for smooth ABR switching
  - File: `VideoConverter.swift`, function `generateResolutionStream()`
  - **Completed**: 2026-01-27

- [ ] **1.2 Fix rate control conflict** (Option C: Capped CRF)
  - **Approach**: Use CRF for quality + VBV (`-maxrate`/`-bufsize`) for bitrate cap
  - Remove `-b:v` (not needed with CRF+VBV)
  - Keep `-crf` (quality-based encoding)
  - Add `-maxrate` = resolution's target bitrate
  - Add `-bufsize` = 2× maxrate (standard VBV buffer)
  - File: `VideoConverter.swift`, function `generateResolutionStream()`
  
  **Implementation Subtasks:**
  - [ ] 1.2.1 Update `HLSResolution` to expose numeric bitrate (currently string "3000k")
  - [ ] 1.2.2 Remove `-b:v` argument from FFmpeg args
  - [ ] 1.2.3 Add `-maxrate` using resolution's bitrate
  - [ ] 1.2.4 Add `-bufsize` calculated as 2× maxrate
  - [ ] 1.2.5 Add new `HLSQualityPreset` enum for user-facing quality levels (see below)
  - [ ] 1.2.6 Update `HLSParameters` with quality preset option
  - [ ] 1.2.7 Map quality preset to CRF value in VideoConverter
  
  **User Preference Considerations:**
  
  The CRF value directly affects output quality vs file size. Currently hardcoded:
  - H.264: CRF 23
  - H.265: CRF 28
  
  Users may want control over this tradeoff. Proposed new enum in `HLSQualityPreset.swift`:
  
  ```swift
  public enum HLSQualityPreset: String, HLSParameterProtocol {
      case high       // CRF 18 (H.264) / 24 (H.265) - larger files, best quality
      case balanced   // CRF 23 (H.264) / 28 (H.265) - default, good tradeoff
      case efficient  // CRF 28 (H.264) / 32 (H.265) - smaller files, lower quality
  }
  ```
  
  **Validation Checks:**
  - [ ] Verify `-maxrate` value includes unit suffix (e.g., "3000k")
  - [ ] Verify `-bufsize` calculation handles all resolution bitrate formats
  - [ ] Test with hardware encoders (VideoToolbox may handle VBV differently)
  - [ ] Ensure CRF is supported by hardware encoders (fallback to `-b:v` if not)

- [ ] **1.3 Fix encoder detection bug**
  - Remove erroneous `"ffmpeg"` from `process.arguments`
  - Should be `["-encoders"]` not `["ffmpeg", "-encoders"]`
  - File: `VideoConverter.swift`, line 272

### Phase 2: HLS Compliance (Medium Priority)

- [ ] **2.1 Add VOD playlist type**
  - Add `-hls_playlist_type vod` to FFmpeg args
  - Ensures proper `#EXT-X-PLAYLIST-TYPE:VOD` and `#EXT-X-ENDLIST` tags
  - File: `VideoConverter.swift`, function `generateResolutionStream()`

- [ ] **2.2 Add independent segments flag**
  - Add `-hls_flags independent_segments` to FFmpeg args
  - Indicates segments start with keyframes
  - File: `VideoConverter.swift`, function `generateResolutionStream()`

- [ ] **2.3 Apply startNumber parameter**
  - Wire up `HLSParameters.startNumber` to `-start_number` FFmpeg arg
  - Currently defined but never used
  - Files: `VideoConverter.swift`, `HLSParameters.swift`

### Phase 3: Quality & Robustness (Lower Priority)

- [x] ~~**3.1 Add maxrate/bufsize for VBV compliance**~~ — *Moved to Phase 1.2*

- [ ] **3.2 Validate hardware encoder functionality**
  - Current check only verifies encoder presence, not that it works
  - Consider test-encoding a small buffer to verify

- [ ] **3.3 Add `-movflags +faststart`**
  - Helps with progressive download if segments are large
  - Low priority since HLS segments are typically small

### Phase 4: Testing

- [ ] **4.1 Add unit test for FFmpeg argument generation**
  - Verify correct flags are present
  - Verify no conflicting flags

- [ ] **4.2 Add integration test for encoder detection**
  - Mock or stub FFmpeg output
  - Verify correct encoder selection

---

## Technical Notes

### Keyframe Alignment Math
- GOP size (`-g`) should be ~2× framerate for 2-second segments
- For 24fps video with 10s segments: `-g 48` works (forces keyframe every 2s)
- `-sc_threshold 0` disables scene-change keyframes that break alignment

### Rate Control Modes
```
CRF Mode (quality-based):
  -crf 23 (no -b:v)

CBR/VBV Mode (bitrate-constrained):
  -b:v 3000k -maxrate 4500k -bufsize 6000k (no -crf)
```

### HLS Flags Reference
```
-hls_playlist_type vod    # VOD playlist with ENDLIST
-hls_flags independent_segments  # Segments start with keyframes
-hls_list_size 0          # Keep all segments (already present)
-start_number N           # First segment number
```

---

## References

- [OTTVerse: HLS Packaging using FFmpeg](https://ottverse.com/hls-packaging-using-ffmpeg-live-vod/)
- [FFmpeg HLS Muxer Documentation](https://ffmpeg.org/ffmpeg-formats.html#hls-2)
- Apple HLS Authoring Specification

---

## Progress Log

| Date | Update |
|------|--------|
| 2026-01-27 | Plan created after codebase review |
| 2026-01-27 | ✓ Phase 1.1 complete: Added keyframe alignment flags to VideoConverter.swift |
| 2026-01-27 | Updated Phase 1.2 to use Option C (Capped CRF); added subtasks, user preference considerations, and validation checks |
