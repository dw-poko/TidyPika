# TidyPika

**A tiny Windows storage cleaner.**

TidyPika finds what is eating your disk — temp files, browser caches, crash
dumps, oversized files, duplicates — and lets you clear it out safely.

Built with **Flutter** and **Material 3**, so the interface is Google's own
Material design rather than an imitation of it. The whole app is an 11 MB
download that unpacks to 27 MB.

![Flutter](https://img.shields.io/badge/Flutter-stable-02569B)
![Material 3](https://img.shields.io/badge/Material-3-6750A4)
![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Platform: Windows](https://img.shields.io/badge/platform-Windows%2010%2F11-informational)

---

## Features

| Feature | Description |
|---------|-------------|
| **Quick Clean** | Scans eleven known cache and temp locations, cleans the ones you pick |
| **Large Files** | Finds the biggest files under any folder, above a size you choose |
| **Duplicates** | Byte-identical files, confirmed by SHA-256 content hash |
| **Disk Analysis** | Which sub-folders are using the space, with share-of-total bars |
| **Drive Overview** | Free and used space across every attached drive |
| **Live progress** | Stage, running file count, a real percentage, and a log of what is being walked |
| **Cancel anytime** | Scans run on their own isolate and stop the moment you ask |
| **Safe deletion** | Recycle Bin by default; system binaries are never touched |
| **한국어 / English** | Switch language from the navigation rail, no restart |

## Cleanup targets

Windows and user temp directories, Prefetch, thumbnail cache, Windows Update
downloads, system and application logs, crash dumps, Chrome and Edge caches,
and the pip and npm package caches.

---

## Install

The latest [build](../../actions) publishes two artifacts:

- **`TidyPika-exe`** — a single `TidyPika.exe`. Nothing to unpack or install.
- **`TidyPika-folder`** — the plain build: `TidyPika.exe`,
  `flutter_windows.dll` and `data/`.

Flutter keeps its engine and assets as separate files on disk, so the
single-file build is a self-extractor rather than one genuine binary: it
unpacks to a temp directory at launch and starts the app from there. That
costs a moment on every start, and an unsigned self-extracting executable is
likelier to draw a SmartScreen or antivirus prompt than the plain folder
build. Either one is the same app — take the folder build if that trade is
not worth it.

Windows 10 1809 or newer, x64. The app expects the Microsoft Visual C++
runtime, which almost every Windows install already has.

---

## Build

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install/windows)
and Visual Studio with the "Desktop development with C++" workload. Flutter's
Windows target needs the MSVC toolchain, so it cannot be cross-compiled from
Linux or macOS.

The generated `windows/` runner is not committed — it belongs to whichever SDK
version builds the app — so create it once after cloning:

```powershell
git clone https://github.com/dw-poko/TidyPika.git
cd TidyPika

flutter create --platforms=windows .
flutter pub get

flutter run -d windows              # debug
flutter build windows --release     # release
```

The release build lands in `build/windows/x64/runner/Release/`.

CI does the same on a `windows-latest` runner — see
[`.github/workflows/build.yml`](.github/workflows/build.yml).

---

## Architecture

```
lib/
├── main.dart                  # Entry point
├── app.dart                   # MaterialApp, M3 theme, NavigationRail shell
├── core/                      # No Flutter imports — pure Dart, runs in isolates
│   ├── models.dart            # CleanTarget, ScanResult, DuplicateGroup, ScanProgress
│   ├── fs_walk.dart           # Permission-tolerant, link-skipping tree walk
│   ├── scanner.dart           # Clean targets, large files, directory sizes
│   ├── duplicate_finder.dart  # Three-phase duplicate detection
│   ├── cleaner.dart           # Recycle Bin / permanent deletion + guards
│   ├── disk_scanner.dart      # Drive enumeration
│   ├── win32.dart             # Hand-rolled FFI bindings
│   └── tasks.dart             # Isolate plumbing and progress streaming
├── l10n/strings.dart          # Korean/English tables
├── widgets/                   # Progress panel, shared Material pieces
└── pages/                     # Home, QuickClean, LargeFiles, Duplicates, Analyze
```

### Scanning off the UI thread

Every scan runs on its own isolate, streaming `ScanProgress` back over a port.
Cancelling the stream kills the isolate, so a walk of `C:\` never blocks a
frame and never has to run to completion.

### Duplicate detection

1. **Size grouping** — a file with a unique size cannot have a twin
2. **Quick hash** — SHA-256 of the first 4 KB splits same-size buckets cheaply
3. **Full hash** — a complete SHA-256 confirms the survivors

Phases 2 and 3 share one progress budget, so the percentage never runs
backwards. Only the first copy in each group is left unselected, so a scan
never proposes deleting every copy of a file.

### Safety

`cleaner.dart` refuses to delete `.sys`, `.dll`, `.exe`, `.msi`, `.inf`,
`.cat`, and `.mui` files under `C:\Windows` or either `Program Files`, so a
scan cannot take out a system binary. Deletion goes to the Recycle Bin unless
you turn that off, and is always confirmed first.

### Win32 interop

Drive capacity, Recycle Bin deletion, and the UI language come from three small
hand-written `dart:ffi` bindings in `core/win32.dart` rather than a bindings
package, which keeps the dependency list and the struct layout under direct
control.

---

## License

[MIT](LICENSE)
