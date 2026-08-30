# Changelog

## v0.0.3

### Added

- **A dashboard.** The home page opens with what is sitting in the Recycle Bin
  and a button to empty it, what Windows has reserved for the hibernation and
  paging files, how free space has moved over the last week, and what the last
  clean recovered. It refreshes itself whenever the app removes something.
- **Reclaim Space.** A page for the two files Windows sets aside whether you
  use them or not. See what `hiberfil.sys` and `pagefile.sys` cost, turn
  hibernation on or off, and set the paging file to automatic, a fixed range,
  or none at all. Both need administrator rights.
- **Disk Analysis goes into folders.** Click a folder to open it and use the
  path above to come back, instead of retyping it at every level.
- **Quick Clean covers nineteen places, not eleven.** Delivery Optimization,
  Windows error reports, GPU shader caches, and the Teams, Discord, Slack and
  VS Code caches. Firefox joins Chrome and Edge, and all three now cover every
  browser profile rather than only the default one.
- **Scans say how long they took.**
- **The mascot is now the icon** on the executable, the window and the
  navigation rail.

### Fixed

- Duplicate search no longer crawls on groups holding thousands of copies, and
  small files are no longer read twice, so scans finish sooner.
- A duplicate scan that stopped at its limit used to say nothing, showing a
  partial result as though it were the whole tree. It now says so, and the
  limit rose from a hundred thousand files to four hundred thousand.
- Disk Analysis totals were smaller than the folder they described, because
  files lying directly in it were left out. They are counted now, and the row
  standing for them opens to name them.

---

### 추가

- **대시보드.** 홈 화면에 휴지통에 들어 있는 용량과 비우기 버튼, Windows가 최대
  절전·페이징 파일에 잡아둔 용량, 최근 일주일간 여유 공간의 변화, 마지막 정리로
  회수한 용량이 표시됩니다. 앱이 무언가를 지우면 알아서 갱신됩니다.
- **용량 줄이기.** 쓰든 안 쓰든 Windows가 잡아두는 두 파일을 위한 페이지입니다.
  `hiberfil.sys`와 `pagefile.sys`가 차지하는 용량을 보고, 최대 절전 모드를 켜고
  끄고, 페이징 파일을 자동·고정 크기·사용 안 함으로 설정할 수 있습니다. 둘 다
  관리자 권한이 필요합니다.
- **디스크 분석이 폴더 안으로 들어갑니다.** 폴더를 누르면 그 안으로 들어가고 위쪽
  경로로 되돌아옵니다. 단계마다 경로를 다시 칠 필요가 없습니다.
- **빠른 정리 대상이 11곳에서 19곳으로.** 배달 최적화, Windows 오류 보고, GPU
  셰이더 캐시, Teams·Discord·Slack·VS Code 캐시가 추가됐습니다. Firefox가
  Chrome·Edge와 함께 들어왔고, 셋 다 기본 프로필만이 아니라 모든 프로필을 봅니다.
- **검사에 걸린 시간을 표시합니다.**
- **마스코트가 아이콘이 됐습니다.** 실행 파일, 창, 내비게이션 레일에 적용됩니다.

### 수정

- 사본이 수천 개인 그룹에서 중복 파일 검사가 느려지던 문제를 고쳤습니다. 작은
  파일을 두 번 읽던 것도 없애 검사가 더 빨리 끝납니다.
- 중복 검사가 한도에서 멈출 때 아무 말도 하지 않아, 일부만 본 결과가 전부 본 것처럼
  보였습니다. 이제 멈췄다고 알리고, 한도도 10만 개에서 40만 개로 올렸습니다.
- 디스크 분석의 합계가 실제 폴더보다 작았습니다. 폴더에 직접 놓인 파일을 빼고
  셌기 때문입니다. 이제 함께 세고, 그 행을 펼쳐 파일명을 볼 수 있습니다.

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
