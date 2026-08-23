<div align="center">

<img src="assets/mascot.png" alt="TidyPika mascot" width="200">

# TidyPika

**A tiny Windows storage cleaner**<br>
**작고 가벼운 Windows 저장소 클리너**

[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B)](https://flutter.dev)
[![Material 3](https://img.shields.io/badge/Material-3-6750A4)](https://m3.material.io)
![Code](https://img.shields.io/badge/code-100%25%20AI--written-8A2BE2)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11%20x64-informational)

**[English](#english) · [한국어](#한국어)**

</div>

---

## English

TidyPika finds what is eating your disk — temp files, browser caches, crash
dumps, oversized files, duplicates — and lets you clear it out safely.

Built with **Flutter** and **Material 3**, so the interface is Google's own
Material design rather than an imitation of it. The whole app is an 11 MB
download that unpacks to 27 MB.

> [!NOTE]
> **Every line of code in this repository was written by AI.** The Dart, the
> Win32 interop, the single-file launcher and the CI workflow were all produced
> by Claude from a person's requirements and review — none of it was hand-written
> by a human. This is a tool that deletes files, so read the source before you
> point it at anything you care about.

### Features

| Feature | Description |
|---------|-------------|
| **Quick Clean** | Scans eleven known cache and temp locations, cleans the ones you pick |
| **Large Files** | Finds the biggest files under any folder, above a size you choose |
| **Duplicates** | Byte-identical files, confirmed by SHA-256 content hash |
| **Disk Analysis** | Which sub-folders are using the space, with share-of-total bars |
| **Drive Overview** | Free and used space across every attached drive |
| **Live progress** | Stage, running file count and a real percentage |
| **Cancel anytime** | Scans run on their own isolate and stop the moment you ask |
| **Safe deletion** | Recycle Bin by default; system binaries are never touched |
| **4 languages** | English, 한국어, 日本語, 简体中文 — switched from the rail, no restart |

### Cleanup targets

Windows and user temp directories, Prefetch, thumbnail cache, Windows Update
downloads, system and application logs, crash dumps, Chrome and Edge caches,
and the pip and npm package caches.

The targets under `C:\Windows` — Windows Update downloads above all — belong to
SYSTEM and Administrators, and an account in the Administrators group still
runs with the filtered token until it is elevated. Files there are reported as
`Access denied`, and the result dialog offers to restart the app elevated. A
file another program is holding open, such as the thumbnail cache Explorer
never lets go of, is reported as `In use` and needs that program closed first.

### Install

Grab the latest [release](../../releases):

- **`TidyPika.exe`** — a single file. Nothing to unpack or install.
- **`TidyPika-win-x64.zip`** — the plain build: `TidyPika.exe`,
  `flutter_windows.dll` and `data/`.

Flutter keeps its engine and assets as separate files on disk, so the
single-file build is a launcher rather than one genuine binary: it unpacks
once into `%LOCALAPPDATA%\TidyPika` and starts the app from there, clearing
out the previous build as it goes.

Neither download is code-signed, so Windows may show a SmartScreen prompt, and
Defender sometimes flags the single file as `Trojan:Win32/Wacatac.B!ml`. An
`!ml` verdict is not a match against known malware — it is a machine-learning
guess about an unfamiliar file, and an unsigned self-extracting launcher that
nobody has downloaded yet is exactly the shape it guesses at. The folder build
is the same app if either gets in the way, and every build here is produced in
the open by [`.github/workflows/build.yml`](.github/workflows/build.yml) from
the source in this repository.

Every push to `main` also publishes both as
[build artifacts](../../actions), which is where to look for a change that has
not been tagged yet.

Windows 10 1809 or newer, x64. The app expects the Microsoft Visual C++
runtime, which almost every Windows install already has.

### Build

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

### Releasing

Push a `v*` tag, or run the **build** workflow manually and put the tag in the
`release` field. Either way the runner builds, creates the release and attaches
both downloads, so the assets always match the tagged commit.

### Architecture

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
├── l10n/strings.dart          # en, ko, ja, zh string tables
├── widgets/                   # Progress panel, shared Material pieces
└── pages/                     # Home, QuickClean, LargeFiles, Duplicates, Analyze
tools/
└── launcher.cs                # Single-file wrapper with the build embedded
```

**Scanning off the UI thread.** Every scan runs on its own isolate, streaming
`ScanProgress` back over a port. Cancelling the stream kills the isolate, so a
walk of `C:\` never blocks a frame and never has to run to completion.

**Duplicate detection.** Size grouping first — a file with a unique size cannot
have a twin. Then SHA-256 of the first 4 KB to split same-size buckets cheaply.
Then a full SHA-256 to confirm. Phases two and three share one progress budget,
so the percentage never runs backwards, and the first copy in each group is
left unselected so a scan never proposes deleting every copy of a file.

**Win32 interop.** Drive capacity, Recycle Bin deletion and the UI language
come from three small hand-written `dart:ffi` bindings in `core/win32.dart`
rather than a bindings package, which keeps the dependency list and the struct
layout under direct control.

### Safety

`cleaner.dart` refuses to delete `.sys`, `.dll`, `.exe`, `.msi`, `.inf`,
`.cat`, and `.mui` files under `C:\Windows` or either `Program Files`, so a
scan cannot take out a system binary. Deletion goes to the Recycle Bin unless
you turn that off, and is always confirmed first.

---

## 한국어

TidyPika는 디스크를 잡아먹는 것들 — 임시 파일, 브라우저 캐시, 크래시 덤프,
대용량 파일, 중복 파일 — 을 찾아서 안전하게 정리합니다.

**Flutter**와 **Material 3**로 만들어서, 흉내낸 디자인이 아니라 Google이
만든 머티리얼 디자인 그대로입니다. 전체 앱은 11 MB 다운로드이고 풀면 27 MB입니다.

> [!NOTE]
> **이 저장소의 모든 코드는 AI가 작성했습니다.** Dart 코드, Win32 연동, 단일 파일
> 런처, CI 워크플로 전부 사람의 요구사항과 리뷰를 받아 Claude가 만들었습니다.
> 사람이 직접 손으로 쓴 코드는 없습니다. 파일을 삭제하는 도구인 만큼, 중요한
> 대상에 쓰기 전에 소스를 확인해 보시길 권합니다.

### 기능

| 기능 | 설명 |
|------|------|
| **빠른 정리** | 알려진 캐시·임시 폴더 11곳을 검사하고, 고른 항목만 삭제 |
| **대용량 파일** | 지정한 폴더에서 정해둔 크기 이상인 파일을 큰 순서로 |
| **중복 파일** | SHA-256 내용 해시로 확인한, 바이트 단위로 동일한 파일 |
| **디스크 분석** | 어떤 하위 폴더가 공간을 쓰는지, 전체 대비 비중 막대와 함께 |
| **드라이브 현황** | 연결된 모든 드라이브의 여유·사용 공간 |
| **실시간 진행률** | 단계, 누적 파일 수, 실제 퍼센트 |
| **언제든 취소** | 검사는 별도 isolate에서 돌아서 누르는 즉시 멈춤 |
| **안전한 삭제** | 기본은 휴지통, 시스템 바이너리는 건드리지 않음 |
| **4개 언어** | English, 한국어, 日本語, 简体中文 — 레일에서 전환, 재시작 불필요 |

### 정리 대상

Windows·사용자 임시 폴더, Prefetch, 썸네일 캐시, Windows Update 다운로드,
시스템·응용 프로그램 로그, 크래시 덤프, Chrome·Edge 캐시, pip·npm 패키지 캐시.

`C:\Windows` 아래 대상은 — 특히 Windows Update 다운로드는 — SYSTEM과
Administrators의 소유이고, 관리자 그룹 계정이라도 권한을 올리기 전까지는 제한된
토큰으로 실행됩니다. 이런 파일은 `권한 없음`으로 표시되고, 결과 창에서 관리자
권한으로 다시 실행할 수 있습니다. 다른 프로그램이 열어 둔 파일은 — 탐색기가 놓지
않는 썸네일 캐시가 대표적입니다 — `사용 중`으로 표시되며, 그 프로그램을 먼저
닫아야 합니다.

### 설치

최신 [릴리스](../../releases)에서 받으세요:

- **`TidyPika.exe`** — 파일 하나. 압축 해제도 설치도 필요 없습니다.
- **`TidyPika-win-x64.zip`** — 일반 빌드: `TidyPika.exe`,
  `flutter_windows.dll`, `data/`.

Flutter는 엔진과 에셋을 디스크에 별도 파일로 두기 때문에, 단일 파일 빌드는
진짜 단일 바이너리가 아니라 **런처**입니다. 처음 실행할 때
`%LOCALAPPDATA%\TidyPika`에 한 번 풀고 거기서 앱을 띄우며, 이전 빌드는 그때
정리합니다.

두 파일 모두 코드 서명이 없어서 Windows가 SmartScreen 경고를 띄울 수 있고,
Defender가 단일 파일을 `Trojan:Win32/Wacatac.B!ml`로 잡기도 합니다. `!ml`
판정은 알려진 악성코드와 일치했다는 뜻이 아니라 처음 보는 파일에 대한 머신러닝
추측이고, 서명도 배포 이력도 없는 자체 압축 해제 런처가 바로 그 추측에 걸리는
형태입니다. 둘 중 하나라도 거슬리면 폴더 빌드를 쓰시면 됩니다 — 같은 앱이고,
모든 빌드는 이 저장소의 소스로
[`.github/workflows/build.yml`](.github/workflows/build.yml)이 공개된 자리에서
만듭니다.

`main`에 푸시할 때마다 동일한 두 파일이
[빌드 아티팩트](../../actions)로도 올라갑니다. 아직 태그되지 않은 변경사항은
여기서 받으세요.

Windows 10 1809 이상, x64. Microsoft Visual C++ 런타임이 필요한데, 거의 모든
Windows에 이미 설치되어 있습니다.

### 빌드

[Flutter SDK](https://docs.flutter.dev/get-started/install/windows)와 "C++를
사용한 데스크톱 개발" 워크로드가 설치된 Visual Studio가 필요합니다. Flutter의
Windows 타깃은 MSVC 툴체인을 쓰므로 Linux나 macOS에서 크로스 컴파일할 수
없습니다.

생성되는 `windows/` 러너는 커밋하지 않습니다 — 빌드에 쓰는 SDK 버전에 종속되기
때문입니다. 클론 후 한 번 만들어 주세요:

```powershell
git clone https://github.com/dw-poko/TidyPika.git
cd TidyPika

flutter create --platforms=windows .
flutter pub get

flutter run -d windows              # 디버그
flutter build windows --release     # 릴리스
```

릴리스 빌드는 `build/windows/x64/runner/Release/`에 생성됩니다.

### 릴리스 방법

`v*` 태그를 푸시하거나, **build** 워크플로를 수동 실행하면서 `release` 칸에
태그를 넣으세요. 어느 쪽이든 러너가 빌드하고 릴리스를 만들어 두 파일을
첨부하므로, 에셋은 항상 태그된 커밋에서 나온 것입니다.

### 구조

```
lib/
├── main.dart                  # 진입점
├── app.dart                   # MaterialApp, M3 테마, NavigationRail 셸
├── core/                      # Flutter 의존성 없는 순수 Dart, isolate에서 실행
│   ├── models.dart            # CleanTarget, ScanResult, DuplicateGroup, ScanProgress
│   ├── fs_walk.dart           # 권한 오류를 견디고 링크를 건너뛰는 트리 순회
│   ├── scanner.dart           # 정리 대상, 대용량 파일, 디렉토리 크기
│   ├── duplicate_finder.dart  # 3단계 중복 탐지
│   ├── cleaner.dart           # 휴지통/영구 삭제 + 보호 규칙
│   ├── disk_scanner.dart      # 드라이브 열거
│   ├── win32.dart             # 직접 작성한 FFI 바인딩
│   └── tasks.dart             # isolate 연결과 진행률 스트리밍
├── l10n/strings.dart          # 영어·한국어·일본어·중국어 문자열 테이블
├── widgets/                   # 진행률 패널, 공용 머티리얼 조각
└── pages/                     # 홈, 빠른정리, 대용량, 중복, 분석
tools/
└── launcher.cs                # 빌드를 품은 단일 파일 래퍼
```

**UI 스레드 밖에서의 검사.** 모든 검사는 별도 isolate에서 돌면서 `ScanProgress`를
포트로 흘려보냅니다. 스트림을 취소하면 isolate가 죽으므로, `C:\` 전체를 훑어도
프레임이 멈추지 않고 끝까지 돌 필요도 없습니다.

**중복 탐지.** 먼저 크기로 묶습니다 — 크기가 유일한 파일은 쌍이 있을 수
없습니다. 다음 앞 4 KB의 SHA-256으로 같은 크기 묶음을 싸게 쪼갭니다. 마지막에
전체 SHA-256으로 확정합니다. 2·3단계가 진행률 예산을 공유하므로 퍼센트가 뒤로
가지 않고, 각 그룹의 첫 사본은 선택 해제해 두어 모든 사본을 지우자고 제안하는
일이 없습니다.

**Win32 연동.** 드라이브 용량, 휴지통 삭제, UI 언어는 바인딩 패키지 대신
`core/win32.dart`에 직접 작성한 작은 `dart:ffi` 바인딩 3개를 씁니다. 의존성
목록과 구조체 레이아웃을 직접 통제하기 위해서입니다.

### 안전장치

`cleaner.dart`는 `C:\Windows`나 두 `Program Files` 아래의 `.sys`, `.dll`,
`.exe`, `.msi`, `.inf`, `.cat`, `.mui` 파일을 삭제하지 않습니다. 검사가
시스템 바이너리를 날릴 수 없다는 뜻입니다. 삭제는 끄지 않는 한 휴지통으로
가고, 항상 먼저 확인을 받습니다.

---

<div align="center">

**License** · [MIT](LICENSE)

</div>
