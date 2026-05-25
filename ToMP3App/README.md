# ToMP3App — macOS Menu Bar + Finder Extension

Native macOS companion app for [tomp3](https://github.com/aramb-dev/tomp3).

## Features
- 🎵 **Menu bar app** — drop files or pick them via file picker, choose quality preset, see live progress
- 🖱️ **Finder right-click** — "Convert to MP3 →" submenu with all 5 quality presets, works on multi-selection
- 🔔 **Notifications** — system notification on batch completion
- 📁 **Same folder output** — converted file saved next to the original

## Prerequisites
- macOS 13+
- Xcode 15+
- `ffmpeg` installed via Homebrew: `brew install ffmpeg`

## Opening in Xcode

> **One-time setup** — the `.xcodeproj` must be created in Xcode since it can't be generated from Swift files alone.

1. Open Xcode → File → New → Project
2. Choose **macOS → App**, name it `ToMP3App`, bundle ID `dev.aramb.tomp3app`
3. **Delete** the generated `ContentView.swift` and `ToMP3AppApp.swift`
4. Add the source files from this directory to the project (drag into Xcode navigator)
5. Add a new **Target** → macOS → Finder Extension, name `FinderExtension`, bundle ID `dev.aramb.tomp3app.findersync`
6. Add `FinderExtension/FinderSync.swift` + `Shared/*.swift` to the extension target
7. Add `Shared/*.swift` to the main app target
8. Set entitlements files for each target (see `.entitlements` files)
9. Embed the `FinderExtension` target inside the main app (Target → General → Frameworks, Libraries, and Embedded Content)
10. Build & Run (⌘R)

## Activating the Finder Extension
After first launch:
System Settings → Privacy & Security → Extensions → Finder Extensions → enable **tomp3**

## Project Structure
```
ToMP3App/
  ToMP3App/          ← Menu bar app target
    AppDelegate.swift
    MenuBarController.swift
    ConversionManager.swift
    StatusItemView.swift
    Info.plist
    ToMP3App.entitlements
  FinderExtension/   ← Finder Sync Extension target
    FinderSync.swift
    Info.plist
    FinderExtension.entitlements
  Shared/            ← Compiled into both targets
    Preset.swift
    ConversionJob.swift
    FFmpegRunner.swift
```
