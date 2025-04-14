<p align="center">
  <img src="https://github.com/user-attachments/assets/da6cfeb9-86b9-4760-a464-a542c67a39e7" width="25%" />
</p>

# HLS Beagle
Quickly transcode video using [FFMPEG](https://ffmpeg.org) into adaptive HLS streams. Includes a lovely Mac app and a handy Swift Package!

## What is this?
A super easy way to convert your video files into adaptive HLS streams! You can either integrate it into your Mac app using the included Swift Package. Or, if you're just looking to convert videos yourself, you can download and build the included Mac app and use the lovely GUI to start transcoding your videos.

## Why?
I recently started moving my own video projects off of Vimeo and onto my own server, and I found myself spending a lot of time figuring out how to get [FFMPEG](https://ffmpeg.org) to convert my videos properly... and also repeating a lot of bash scripts. This project provides a clean, type-safe API (and Mac app) to do just that.

### Why is it called HLS Beagle?
The [HMS Beagle](https://en.wikipedia.org/wiki/HMS_Beagle) was the ship that carried Charles Darwin around the world and helped him develop his theory of evolution. HLS is close to HMS. Seemed like a fun name! And there's a pun in there somewhere about *adapt*ive bitrates (eh? get it?). 🚢🤷

## Getting Started

### The Mac App
If you're looking for a quick and easy way to convert your existing video into adaptive HLS streams, you can use the included Mac app to do just that!

<p align="center">
    <img src="./Docs/hero.png" width="49%" /><img src="./Docs/hero2.png" width="49%" />
</p>

#### Installing
 1. Head to the "Releases" page and download the latest binary attachment (should be "HLS Beagle.app.zip")
 2. Unzip the download.
 3. Drag and drop the app into your Applications folder.
 4. The app is Notarized by Apple so you should be up and running with no further steps!

#### Converting
> [!IMPORTANT]
> You need to have FFMPEG installed before HLS Beagle can convert your video content. Unfortunately, FFMPEG's licensing structure makes it difficult to include it as part of the binary of this application. You can quickly and easily [download and install FFMPEG here](https://ffmpeg.org).

 1. Drag and drop an input video and an output folder into the app, on their respective "boxes".
 2. Choose your encoding preferences for both video and audio.
 3. Click "Convert [video name]"
 4. The raw conversion progress logs will be shown in real-time in the app and you'll see conversion progress for each output size you choose.
 5. You'll get a notification when the conversion completes. The output is saved in your specified output directory.

> [!TIP]
> You should also be able to drag and drop an input video file or an output folder directly onto the app icon in your Dock!

#### Minimum Requirements
Use of the Mac app requires that you're running at least macOS 15.0 and have at least `homebrew` installed on your system (or that you're able to install FFMPEG yourself).

### The Swift Package
If you're interested in integrating this Swift wrapper over FFMPEG into your own project, you can use the included Swift Package to do so.

Just add the following URL as a package dependency in your macOS project:

```
https://github.com/Sam-Spencer/HLSBeagle.git
```

#### Minimum Requirements
Use of the Swift Package requires that your project target at least macOS 14.0 and use Swift 6 or later.

## License
HLS Beagle is licensed under the MIT License. It does not include a binary distribution of FFMPEG, as there are additional complex licensing hoops to jump through in order to do that. As such, APIs are provided as part of the Swift Package to check for the availability of FFMPEG on your system. Same goes for the Mac app: it will check for an existing install of FFMPEG before any conversions can take place.

## Contributing
Feel free to open an issue or pull request to report a problem, ask a question, or make a contribution! I'd love to expand this and make it more useful for others.
