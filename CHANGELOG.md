# Changelog

## Unreleased

### Added

- **A dashboard worth opening.** Four figures across the top of the home page,
  all of them read instantly and all of them pointing at something to do: what
  is sitting in the Recycle Bin, with a button to empty it; what Windows has
  reserved for the hibernation and paging files, which opens Reclaim Space;
  how the system drive's free space has moved over the last seven days; and
  what the last clean recovered. The last two come from a small file of daily
  samples the app keeps for itself.
- **The mascot is the icon.** The executable, its window and the navigation
  rail now wear it, cut out of the artwork the README already used.
- **A Reclaim Space page.** The two settings that reserve space whether or not
  it is used — the hibernation file and the paging file — have their own place
  in the navigation rail rather than sitting on the dashboard, which is for
  looking rather than changing.
- **Hibernation.** What `hiberfil.sys` is costing, and a
  switch that turns the feature on or off through `powercfg`. Windows sizes
  the file from installed memory and reserves it whether or not the machine
  ever hibernates, so it is often several gigabytes doing nothing. Changing
  the setting needs administrator rights, and Fast Startup uses the same file,
  so it turns off along with it.
- **Virtual memory.** What `pagefile.sys` occupies across
  drives, how Windows is set to size it, and a dialog that hands the setting
  back to Windows, pins it to a range on the system drive, or removes it. The
  change goes through WMI, needs administrator rights, and takes effect at the
  next restart. Removing the paging file altogether is the one setting here
  that can destabilise a machine, and the dialog says so before you pick it.

### Changed

- **Duplicates copes with large groups.** A group used to be one card with its
  files in a column, and a column builds everything it holds — so a group with
  a few thousand copies cost a few thousand widgets on every rebuild, and a
  rebuild is every checkbox. Headers and files are now one flat list, so only
  what is on screen is built however large a group gets. The selected total is
  kept as it changes rather than recounted from every file on every rebuild.
- Files of 4 KB or less are no longer hashed twice while scanning: the quick
  hash already covers them whole, so the confirming pass reuses it. On a tree
  full of small duplicates that is half the reading gone.

## v0.0.2

Quick Clean was doing less than it reported and would not say why. Most of
this release is about that, plus two more languages.

### Fixed

- **Windows Update Cache and Windows Temp barely cleaned anything.** The
  safety guard rejected `.dll`, `.exe`, `.cat`, `.mui` and `.inf` anywhere
  under `C:\Windows` — which is most of what an expanded update payload is
  made of. Those folders exist to be emptied and are now exceptions; real
  system binaries are still refused.
- **Target names stayed English** whatever the app was set to, because they
  were built inside the scanning isolate, which holds its own copy of the
  language setting.
- **Every target arrived ticked** after a scan. Nothing starts selected now.

### Added

- **Open a Quick Clean row** to see the files behind it — largest first, name
  over path, first 200 shown. Click again to fold it away.
- **Failure reasons.** A clean used to report a count; it now names each file
  it could not remove and why: Access denied, In use, Protected, Already gone,
  Refused.
- **Restart as administrator**, offered from the result dialog when a delete
  was refused for permissions, and from a notice at startup when the app is
  not elevated. The Windows folders hide much of what they hold from an
  ordinary token, so an unelevated scan under-reports rather than fails.
- **Japanese and Simplified Chinese**, alongside English and Korean. The
  picker sits in the navigation rail and in the startup notice, and lists each
  language in its own name.

### Changed

- The single-file launcher unpacks into `%LOCALAPPDATA%\TidyPika` instead of
  `%TEMP%`, carries version information, and clears out builds it replaces.
  Writing a program into TEMP and running it is the shape Defender's
  machine-learning heuristics score as a dropper, which is what was behind the
  occasional `Trojan:Win32/Wacatac.B!ml` report.
- The font fallback chain follows the selected language. Han characters are
  shared across Japanese, Chinese and Korean, so a fixed chain drew them in
  the wrong regional shapes.

---

빠른 정리가 실제로 하는 일이 표시보다 적었고, 왜 그런지 알려주지도 않았습니다.
이번 릴리스는 대부분 그 문제에 대한 것이고, 언어 두 개가 추가되었습니다.

### 수정

- **Windows Update 캐시와 Windows 임시 폴더가 거의 정리되지 않던 문제.** 안전
  가드가 `C:\Windows` 아래의 `.dll`·`.exe`·`.cat`·`.mui`·`.inf`를 전부
  거부했는데, 압축이 풀린 업데이트 페이로드가 바로 그런 파일들로 이루어져
  있습니다. 비우라고 만든 폴더는 예외로 두고, 실제 시스템 바이너리는 그대로
  보호합니다.
- **항목 이름이 항상 영어로 나오던 문제.** 목록이 스캔 격리(isolate) 안에서
  만들어지는데, 격리는 언어 설정의 자기 복사본을 갖기 때문이었습니다.
- **검사 후 모든 항목이 체크되어 있던 동작.** 이제 아무것도 선택되지 않은
  상태로 시작합니다.

### 추가

- **빠른 정리 항목을 누르면** 해당 파일 목록이 펼쳐집니다. 큰 파일 순, 파일명
  아래 경로, 최대 200개. 다시 누르면 접힙니다.
- **실패 사유 표시.** 개수만 알려주던 것을, 삭제하지 못한 파일마다 이유를
  붙여 보여줍니다: 권한 없음, 사용 중, 보호됨, 이미 없음, 거부됨.
- **관리자 권한으로 다시 실행.** 권한 때문에 삭제가 거부되면 결과 창에서,
  그리고 일반 권한으로 실행 중이면 시작할 때 안내와 함께 제공합니다. Windows
  폴더는 일반 권한에 내용을 상당 부분 숨기기 때문에, 권한이 없으면 실패가
  아니라 용량이 적게 잡힙니다.
- **일본어와 중국어(간체)** 지원. 선택기는 내비게이션 레일과 시작 안내창에
  있고, 각 언어를 그 언어 자체로 표기합니다.

### 변경

- 단일 실행 파일 런처가 `%TEMP%` 대신 `%LOCALAPPDATA%\TidyPika`에 압축을 풀고,
  버전 정보를 담으며, 교체한 이전 빌드를 정리합니다. TEMP에 프로그램을 쓰고
  즉시 실행하는 형태가 Defender 머신러닝이 드로퍼로 판정하는 모양이고, 가끔
  나오던 `Trojan:Win32/Wacatac.B!ml`이 여기서 비롯됐습니다.
- 폰트 폴백 순서가 선택한 언어를 따릅니다. 한자는 일본어·중국어·한국어가
  공유하는 문자라, 순서가 고정이면 다른 지역의 글자 모양으로 그려집니다.

## v0.0.1

First tagged build.
