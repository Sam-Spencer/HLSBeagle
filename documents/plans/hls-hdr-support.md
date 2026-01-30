# HDR Support for HLS Beagle

## Overview

This plan outlines the implementation of HDR (High Dynamic Range) content preservation when converting video to HLS format. The goal is to detect HDR source content and maintain its color metadata, transfer functions, and mastering display information through the encoding pipeline.

## Research Summary

### HDR Formats to Support

| Format | Transfer Function | Color Primaries | Notes |
|--------|------------------|-----------------|-------|
| **HDR10** | SMPTE ST 2084 (PQ) | BT.2020 | Static metadata; most common |
| **HLG** | ARIB STD-B67 | BT.2020 | Broadcast-focused; backwards compatible with SDR |
| **HDR10+** | SMPTE ST 2084 (PQ) | BT.2020 | Dynamic metadata; Samsung-backed |
| **Dolby Vision** | SMPTE ST 2084 (PQ) | BT.2020 | Dynamic metadata; requires RPU layer |

### Apple HLS Requirements (from Apple Tech Talks & HLS Authoring Spec)

1. **Codec Requirements**:
   - HDR requires **HEVC (H.265)** - H.264 does not support HDR
   - Must use **10-bit color depth** (`yuv420p10le`)
   - Profile: Main 10 (`main10`)

2. **Master Playlist Tags**:
   - `VIDEO-RANGE=PQ` for HDR10/Dolby Vision
   - `VIDEO-RANGE=HLG` for HLG content
   - `VIDEO-RANGE=SDR` for standard dynamic range
   - `CODECS` must accurately reflect the stream (e.g., `hvc1.2.4.L150.B0` for HDR10)

3. **Segment Format**:
   - fMP4 (fragmented MP4) segments recommended for HDR
   - Use `-hls_segment_type fmp4` instead of `.ts` segments
   - Tag video with `hvc1` codec tag (`-tag:v hvc1`)

4. **Static Metadata (HDR10)**:
   - Must be in HEVC configuration box, not individual samples
   - Mastering Display Color Volume (MDCV) metadata
   - Content Light Level (CLL) metadata

### FFmpeg HDR Encoding Requirements

From research on FFmpeg HDR encoding:

#### 1. Detecting HDR Metadata (via ffprobe)
```bash
ffprobe -hide_banner -loglevel warning \
  -select_streams v \
  -print_format json \
  -show_frames -read_intervals "%+#1" \
  -show_entries "frame=color_space,color_primaries,color_transfer,side_data_list,pix_fmt" \
  -i input.mp4
```

Key fields to extract:
- `color_space`: e.g., `bt2020nc`
- `color_primaries`: e.g., `bt2020`
- `color_transfer`: e.g., `smpte2084` (PQ) or `arib-std-b67` (HLG)
- `pix_fmt`: e.g., `yuv420p10le`
- `side_data_list`: Contains mastering display and content light level metadata

#### 2. libx265 HDR Encoding Parameters
```bash
-c:v libx265 \
-x265-params "hdr-opt=1:repeat-headers=1:\
colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:\
master-display=G(8500,39850)B(6550,2300)R(35400,14600)WP(15635,16450)L(40000000,50):\
max-cll=1000,400" \
-pix_fmt yuv420p10le \
-tag:v hvc1
```

#### 3. VideoToolbox (hevc_videotoolbox) HDR Encoding
For hardware-accelerated encoding on Apple Silicon:
```bash
-c:v hevc_videotoolbox \
-pix_fmt p010le \
-color_primaries bt2020 \
-color_trc smpte2084 \
-colorspace bt2020nc \
-tag:v hvc1
```
**Note**: VideoToolbox has limited control over HDR metadata injection compared to libx265.

### Known Limitations

1. **Dolby Vision in HLS** (FFmpeg ticket #10490):
   - FFmpeg HLS muxer does not preserve Dolby Vision metadata when packaging
   - DV requires special handling with RPU files and external tools
   - **Recommendation**: Initially support HDR10/HLG only; Dolby Vision as future enhancement

2. **Hardware Encoder Limitations**:
   - `hevc_videotoolbox` may not pass through all HDR metadata
   - May need fallback to `libx265` for full HDR metadata preservation

3. **Bitrate Considerations**:
   - HDR content typically requires 20-30% higher bitrates than SDR
   - Apple recommends specific bitrate ladders for HDR

---

## Implementation Plan

### Phase 1: HDR Detection

- [ ] **1.1 Create `HDRMetadata` struct**
  - File: `Sources/SwiftyHLS/HDRMetadata.swift`
  - Properties:
    - `transferFunction`: enum (SDR, PQ, HLG)
    - `colorPrimaries`: enum (bt709, bt2020)
    - `colorSpace`: enum (bt709, bt2020nc, bt2020c)
    - `bitDepth`: Int (8, 10, 12)
    - `masteringDisplay`: optional struct (primaries, white point, luminance)
    - `contentLightLevel`: optional struct (maxCLL, maxFALL)

- [ ] **1.2 Create `HDRTransferFunction` enum**
  - File: `Sources/SwiftyHLS/HDRTransferFunction.swift`
  - Cases: `.sdr`, `.pq` (HDR10), `.hlg`
  - Properties: `ffmpegName`, `hlsVideoRange`, `displayName`

- [ ] **1.3 Extend `VideoProcessor` with HDR detection**
  - File: `Sources/SwiftyHLS/VideoProcessor.swift`
  - New method: `getHDRMetadata(inputPath:) throws -> HDRMetadata?`
  - Use ffprobe with `-show_frames -read_intervals "%+#1"` to extract first frame metadata
  - Parse `color_transfer`, `color_primaries`, `color_space`, `pix_fmt`
  - Parse `side_data_list` for mastering display and content light level

### Phase 2: HDR Configuration

- [ ] **2.1 Add HDR options to `HLSParameters`**
  - File: `Sources/SwiftyHLS/HLSParameters.swift`
  - New property: `hdrOptions: HLSHDROptions?`

- [ ] **2.2 Create `HLSHDROptions` struct**
  - File: `Sources/SwiftyHLS/HLSHDROptions.swift`
  - Properties:
    - `enabled: Bool` - Whether to preserve HDR (default: true)
    - `mode: HDRMode` - `.auto`, `.forceSDR`, `.preserveHDR`
    - `fallbackToSoftwareEncoder: Bool` - Use libx265 if hardware fails HDR
  - Consider: `preferFmp4Segments: Bool` for HDR compatibility

- [ ] **2.3 Update `HLSResolution` with HDR bitrates**
  - File: `Sources/SwiftyHLS/HLSResolution.swift`
  - Add `hdrBitrateKbps` property (20-30% higher than SDR)
  - Example: 4K HDR → 14,000 kbps (vs 10,000 kbps SDR)

### Phase 3: FFmpeg Argument Generation

- [ ] **3.1 Update `buildFFmpegArguments` for HDR**
  - File: `Sources/SwiftyHLS/VideoConverter.swift`
  - Detect if input is HDR and adjust arguments:
    - Force HEVC encoder if HDR detected
    - Add pixel format: `-pix_fmt yuv420p10le` (software) or `-pix_fmt p010le` (hardware)
    - Add color metadata flags
    - Add codec tag: `-tag:v hvc1`

- [ ] **3.2 Implement libx265 HDR parameter builder**
  - New internal method: `buildX265HDRParams(metadata:) -> String`
  - Construct `-x265-params` string with:
    - `hdr-opt=1`
    - `repeat-headers=1`
    - `colorprim`, `transfer`, `colormatrix`
    - `master-display` (formatted from metadata)
    - `max-cll` (formatted from metadata)

- [ ] **3.3 Implement VideoToolbox HDR parameter builder**
  - New internal method: `buildVideoToolboxHDRParams(metadata:) -> [String]`
  - Add color primaries, transfer, colorspace flags
  - Note limitations in comments

- [ ] **3.4 Add fMP4 segment support**
  - New option in `HLSParameters`: `segmentFormat: HLSSegmentFormat` (`.ts`, `.fmp4`)
  - When HDR + fMP4:
    - `-hls_segment_type fmp4`
    - `-hls_fmp4_init_filename "init_<height>p.mp4"`
    - Adjust segment filename pattern

### Phase 4: Master Playlist Updates

- [ ] **4.1 Update `createMasterPlaylist` for HDR**
  - File: `Sources/SwiftyHLS/VideoConverter.swift`
  - Add `VIDEO-RANGE` attribute to `#EXT-X-STREAM-INF`
  - Add proper `CODECS` string for HEVC HDR
  - Pass HDR metadata through conversion pipeline

- [ ] **4.2 Implement HEVC codec string builder**
  - New method: `buildHEVCCodecString(profile:level:hdr:) -> String`
  - Examples:
    - HDR10: `hvc1.2.4.L150.B0`
    - HLG: `hvc1.2.4.L150.B0`
    - SDR HEVC: `hvc1.1.6.L120.B0`

### Phase 5: GUI Integration

- [ ] **5.1 Add HDR indicator to Inspector**
  - File: `GUI/SwiftyHLSApp/Inspector.swift`
  - Show detected HDR format (HDR10, HLG, SDR)
  - Display color primaries and transfer function

- [ ] **5.2 Add HDR options section**
  - File: `GUI/SwiftyHLSApp/InspectorHDR.swift` (new file)
  - Toggle: Preserve HDR
  - Picker: HDR Mode (Auto, Force SDR, Preserve)
  - Toggle: Use fMP4 segments (recommended for HDR)

- [ ] **5.3 Update `ContentViewModel`**
  - File: `GUI/SwiftyHLSApp/ContentViewModel.swift`
  - Add HDR detection on file drop
  - Update conversion parameters based on HDR options

### Phase 6: Testing

- [ ] **6.1 Unit tests for HDR detection**
  - File: `Tests/SwiftyHLSTests/HDRTests.swift`
  - Test parsing of ffprobe HDR metadata output
  - Test `HDRMetadata` struct initialization
  - Test transfer function detection (PQ, HLG, SDR)

- [ ] **6.2 Unit tests for FFmpeg argument building**
  - Test libx265 HDR params generation
  - Test VideoToolbox HDR params generation
  - Test master playlist VIDEO-RANGE attribute

- [ ] **6.3 Integration tests (manual)**
  - Test with HDR10 source file
  - Test with HLG source file
  - Test with SDR source file (no HDR processing)
  - Verify output plays correctly in Safari/QuickTime

---

## Technical Details

### Master Display Metadata Format

FFprobe output:
```json
{
  "red_x": "35400/50000",
  "red_y": "14600/50000",
  "green_x": "8500/50000",
  "green_y": "39850/50000",
  "blue_x": "6550/50000",
  "blue_y": "2300/50000",
  "white_point_x": "15635/50000",
  "white_point_y": "16450/50000",
  "min_luminance": "50/10000",
  "max_luminance": "40000000/10000"
}
```

x265 format:
```
G(8500,39850)B(6550,2300)R(35400,14600)WP(15635,16450)L(40000000,50)
```

### Content Light Level Format

FFprobe output:
```json
{
  "max_content": 1000,
  "max_average": 400
}
```

x265 format:
```
max-cll=1000,400
```

### Apple Recommended HDR Bitrate Ladder

| Resolution | SDR Bitrate | HDR Bitrate | Notes |
|------------|-------------|-------------|-------|
| 4K (2160p) | 10,000 kbps | 14,000 kbps | +40% |
| 2K (1440p) | 5,000 kbps | 7,000 kbps | +40% |
| 1080p | 3,000 kbps | 4,500 kbps | +50% |
| 720p | 1,500 kbps | 2,250 kbps | +50% |

---

## Future Enhancements

1. **Dolby Vision Support**
   - Requires external tools (dovi_tool, MP4Box)
   - RPU extraction and re-injection
   - Profile 5 (single layer) and Profile 8.1 support

2. **HDR10+ Support**
   - Dynamic metadata extraction
   - Requires hdr10plus_tool for metadata handling

3. **Tone Mapping**
   - Option to convert HDR → SDR for legacy devices
   - Use FFmpeg `zscale` or `tonemap` filters

4. **SDR Fallback Variants**
   - Generate both HDR and SDR variants in master playlist
   - Per Apple spec: "For backward compatibility SDR trick play streams MUST be provided"

---

## References

- [Apple: Authoring 4K and HDR HLS Streams](https://developer.apple.com/videos/play/tech-talks/501/)
- [Apple: HLS Authoring Specification](https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices-appendixes)
- [Apple: High Dynamic Range Metadata for Apple Devices (PDF)](https://developer.apple.com/av-foundation/High-Dynamic-Range-Metadata-for-Apple-Devices.pdf)
- [Code Calamity: Encoding UHD 4K HDR10 Videos with FFmpeg](https://codecalamity.com/encoding-uhd-4k-hdr10-videos-with-ffmpeg/)
- [FFmpeg Ticket #10490: HLS packaging does not preserve Dolby Vision metadata](https://trac.ffmpeg.org/ticket/10490)
- [FFmpeg Ticket #7037: HDR metadata encoding support](https://trac.ffmpeg.org/ticket/7037)

---

## Progress

| Phase | Status | Notes |
|-------|--------|-------|
| Phase 1: HDR Detection | ⬜ Not Started | |
| Phase 2: HDR Configuration | ⬜ Not Started | |
| Phase 3: FFmpeg Arguments | ⬜ Not Started | |
| Phase 4: Master Playlist | ⬜ Not Started | |
| Phase 5: GUI Integration | ⬜ Not Started | |
| Phase 6: Testing | ⬜ Not Started | |
