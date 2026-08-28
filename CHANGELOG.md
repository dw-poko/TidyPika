# Changelog

## v0.0.3

### Added

- **The dashboard keeps up.** Cleaning on another page, emptying the Recycle
  Bin, or turning hibernation off now refreshes the dashboard's figures. It is
  kept alive behind the other pages rather than rebuilt when you return to it,
  so until now it went on showing the free space it read at startup.
- **Scans say how long they took.** The status strip counts while one runs and
  keeps the total once it stops, cancelled or finished, on every page that
  scans.
- **Quick Clean covers nineteen places, not eleven.** Delivery Optimization,
  Windows error reports, GPU shader caches, and the Teams, Discord, Slack and
  VS Code caches. Firefox joins Chrome and Edge — and all three now cover every
  browser profile rather than only the default one, which had been quietly
  missing the caches of anyone with a second profile.
- **Duplicates says when it stopped early.** The walk gives up after a fixed
  number of files so a very large tree cannot run away with memory, and until
  now it gave up in silence — a partial result that looked complete. It now
  says so above the results, and the limit went from a hundred thousand files
  to four hundred thousand, which covers a user profile several times over.
- **Disk Analysis goes in.** A folder in the results opens it, and the path
  above turns into steps that go back — so following the space down a tree no
  longer means retyping the path at every level. The analysis also counts the
  files lying directly in the folder rather than only its sub-folders; without
  that the total was smaller than the folder, and every step further in lost
  whatever was left behind at the last one. That row opens too — the loose
  files have nowhere to descend to, so they unfold in place, largest first.
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
- **Hibernation.** What `hiberfil.sys` is costing, and a switch that turns the
  feature on or off through `powercfg`. Windows sizes the file from installed
  memory and reserves it whether or not the machine ever hibernates, so it is
  often several gigabytes doing nothing. Changing the setting needs
  administrator rights, and Fast Startup uses the same file, so it turns off
  along with it.
- **Virtual memory.** What `pagefile.sys` occupies across drives, how Windows
  is set to size it, and a dialog that hands the setting back to Windows, pins
  it to a range on the system drive, or removes it. The change goes through
  WMI, needs administrator rights, and takes effect at the next restart.
  Removing the paging file altogether is the one setting here that can
  destabilise a machine, and the dialog says so before you pick it.

### Changed

- **CI analyses and tests before it builds.** `flutter analyze` catches in a
  second what the build only reports two minutes into MSBuild, and there is
  now a test suite for the pure functions that decide what gets deleted: the
  guard on protected files, the pattern matching behind each clean target,
  size and count formatting, the `PagingFiles` parser, and the rules that
  decide whether hibernation is on, off, or unreadable. Every bug this release
  fixes was in one of those.
- **Duplicates copes with large groups.** A group used to be one card with its
  files in a column, and a column builds everything it holds — so a group with
  a few thousand copies cost a few thousand widgets on every rebuild, and a
  rebuild is every checkbox. Headers and files are now one flat list, so only
  what is on screen is built however large a group gets. The selected total is
  kept as it changes rather than recounted from every file on every rebuild.
- Files of 4 KB or less are no longer hashed twice while scanning: the quick
  hash already covers them whole, so the confirming pass reuses it. On a tree
  full of small duplicates that is half the reading gone.

---

### 추가

- **대시보드가 뒤처지지 않습니다.** 다른 페이지에서 정리하거나, 휴지통을 비우거나,
  최대 절전 모드를 끄면 대시보드의 숫자가 갱신됩니다. 대시보드는 다른 페이지 뒤에
  살아 있을 뿐 돌아올 때 다시 만들어지지 않기 때문에, 지금까지는 시작할 때 읽은
  여유 공간을 계속 보여주고 있었습니다.
- **검사에 걸린 시간을 표시합니다.** 진행 표시줄이 검사 중에는 시간을 세고, 끝나거나
  취소되면 그 총 시간을 남깁니다. 검사하는 모든 페이지에 적용됩니다.
- **빠른 정리 대상이 11곳에서 19곳으로.** 배달 최적화, Windows 오류 보고, GPU 셰이더
  캐시, Teams·Discord·Slack·VS Code 캐시가 추가됐습니다. Firefox가 Chrome·Edge와
  나란히 들어왔고, 셋 다 기본 프로필만이 아니라 **모든 프로필**을 봅니다. 프로필이
  둘 이상인 사람의 캐시를 그동안 통째로 놓치고 있었습니다.
- **중복 파일이 도중에 멈췄다고 말합니다.** 아주 큰 트리에서 메모리가 무한정 늘지
  않도록 일정 개수에서 검사를 멈추는데, 지금까지는 조용히 멈췄습니다 — 일부만 본
  결과가 전부 본 것처럼 보였습니다. 이제 결과 위에 알리고, 한도도 10만 개에서 40만
  개로 올렸습니다. 사용자 프로필 몇 개 분량입니다.
- **디스크 분석이 폴더 안으로 들어갑니다.** 결과의 폴더를 누르면 그 안으로 들어가고,
  위쪽 경로가 되돌아가는 단계 버튼이 됩니다. 트리를 따라 내려가려고 매번 경로를 다시
  칠 필요가 없습니다. 또한 하위 폴더만이 아니라 **그 폴더에 직접 놓인 파일**도
  셉니다. 그러지 않으면 합계가 폴더보다 작았고, 한 단계 들어갈 때마다 직전 단계에
  남겨둔 파일이 사라졌습니다. 그 행도 펼쳐집니다 — 파일들은 더 들어갈 곳이 없으니
  큰 순서로 제자리에서 펼쳐집니다.
- **열어볼 만한 대시보드.** 홈 화면 위쪽에 숫자 넷이 놓입니다. 넷 다 즉시 읽히고,
  넷 다 할 일을 가리킵니다: 휴지통에 들어 있는 용량과 비우기 버튼, Windows가 최대
  절전·페이징 파일에 잡아둔 용량(누르면 용량 줄이기로 이동), 최근 7일간 시스템
  드라이브 여유 공간의 변화, 그리고 마지막 정리로 회수한 용량. 뒤의 둘은 앱이 스스로
  기록하는 작은 일별 파일에서 나옵니다.
- **마스코트가 아이콘이 됐습니다.** 실행 파일, 창, 내비게이션 레일이 README에 쓰던
  그림에서 오려낸 로고를 답니다.
- **용량 줄이기 페이지.** 쓰든 안 쓰든 공간을 잡아두는 두 설정 — 최대 절전 파일과
  페이징 파일 — 이 내비게이션 레일에 자기 자리를 갖습니다. 대시보드는 바꾸는 곳이
  아니라 보는 곳이라서 옮겼습니다.
- **최대 절전 모드.** `hiberfil.sys`가 차지하는 용량과, `powercfg`로 기능을 켜고 끄는
  스위치입니다. Windows는 설치된 메모리 크기에 맞춰 이 파일을 미리 잡아두며, 실제로
  최대 절전을 쓰든 안 쓰든 자리를 차지합니다 — 보통 수 GB입니다. 설정 변경에는 관리자
  권한이 필요하고, 빠른 시작이 같은 파일을 쓰기 때문에 함께 꺼집니다.
- **가상 메모리.** 드라이브별 `pagefile.sys`가 차지하는 용량, Windows가 크기를 어떻게
  정하도록 설정돼 있는지, 그리고 설정을 Windows에 다시 맡기거나 시스템 드라이브에
  크기 범위를 지정하거나 아예 없애는 대화상자입니다. WMI를 거치고, 관리자 권한이
  필요하며, 다시 시작할 때 적용됩니다. 페이징 파일을 완전히 없애는 것은 여기서
  유일하게 시스템을 불안정하게 만들 수 있는 설정이고, 고르기 전에 대화상자가 그렇게
  말합니다.

### 변경

- **CI가 빌드 전에 분석하고 테스트합니다.** `flutter analyze`는 빌드가 MSBuild 2분
  뒤에야 알려주는 것을 1초에 잡습니다. 그리고 **무엇을 지울지 결정하는 순수 함수들**에
  테스트가 생겼습니다: 보호 파일 가드, 각 정리 대상의 패턴 매칭, 크기·개수 서식,
  `PagingFiles` 파서, 그리고 최대 절전 모드가 켜짐·꺼짐·읽을 수 없음 중 무엇인지
  판정하는 규칙. 이번 릴리스가 고친 버그는 전부 이 중 하나에 있었습니다.
- **중복 파일이 큰 그룹을 감당합니다.** 그룹 하나가 카드 하나였고 그 안의 파일은
  Column에 들어 있었는데, Column은 가진 것을 전부 만듭니다 — 사본이 수천 개인 그룹은
  리빌드마다 위젯 수천 개를 만들었고, 리빌드는 체크박스를 누를 때마다 일어납니다.
  이제 헤더와 파일이 하나의 평평한 목록이라 그룹이 아무리 커도 화면에 보이는 것만
  만듭니다. 선택 용량도 리빌드마다 전부 다시 세지 않고 바뀔 때 누적합니다.
- 4 KB 이하 파일을 검사 중에 두 번 해시하지 않습니다. 빠른 해시가 이미 파일 전체를
  덮으므로 확인 단계가 그 값을 재사용합니다. 작은 중복 파일이 많은 트리에서는 읽기가
  절반으로 줄어듭니다.

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
