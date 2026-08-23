import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../core/win32.dart';

/// Each language carries the code it is stored under and its own name, so the
/// picker reads the same whatever the app is currently set to.
enum AppLanguage {
  english('en', 'English'),
  korean('ko', '한국어'),
  japanese('ja', '日本語'),
  chinese('zh', '简体中文');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;
}

final ValueNotifier<AppLanguage> language =
    ValueNotifier<AppLanguage>(AppLanguage.english);

/// Publishes the current language to the widget tree.
///
/// Rebuilding from the top does not work on its own: when a parent rebuilds and
/// hands back a widget it already has — which is exactly what a `const` child
/// is — Flutter reuses the element and skips the whole subtree, so captions
/// would keep their old text. Depending on this instead marks each reader dirty
/// directly, so `const` costs nothing and cannot silently break the switch.
class LanguageScope extends InheritedNotifier<ValueNotifier<AppLanguage>> {
  LanguageScope({required super.child, super.key}) : super(notifier: language);

  /// Call at the top of any `build` that reads [t] or [tf].
  static void watch(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<LanguageScope>();
  }
}

void initLanguage() {
  language.value = _loadPreference() ?? _systemDefault();
  language.addListener(() => _savePreference(language.value));
}

void setLanguage(AppLanguage value) => language.value = value;

String t(String key) {
  return _tables[language.value]?[key] ?? _en[key] ?? key;
}

/// Fills `{0}`, `{1}`, ... in the looked-up string.
String tf(String key, List<Object> args) {
  var text = t(key);
  for (var i = 0; i < args.length; i++) {
    text = text.replaceAll('{$i}', args[i].toString());
  }
  return text;
}

AppLanguage _systemDefault() {
  try {
    return switch (primaryUiLanguage()) {
      langKorean => AppLanguage.korean,
      langJapanese => AppLanguage.japanese,
      langChinese => AppLanguage.chinese,
      _ => AppLanguage.english,
    };
  } catch (_) {
    return AppLanguage.english;
  }
}

File get _preferenceFile {
  final base = Platform.environment['LOCALAPPDATA'] ??
      Directory.systemTemp.path;
  return File(p.join(base, 'TidyPika', 'language.txt'));
}

AppLanguage? _loadPreference() {
  try {
    final file = _preferenceFile;
    if (!file.existsSync()) return null;

    final code = file.readAsStringSync().trim();
    for (final option in AppLanguage.values) {
      if (option.code == code) return option;
    }
  } catch (_) {
    // Falls through to the system default.
  }
  return null;
}

void _savePreference(AppLanguage value) {
  try {
    final file = _preferenceFile;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(value.code);
  } catch (_) {
    // Remembering the choice is best-effort.
  }
}

const Map<String, String> _en = {
  'app.title': 'TidyPika',
  'app.subtitle': 'Storage Cleaner',
  'action.language': 'Language',

  'nav.home': 'Home',
  'nav.quick': 'Quick Clean',
  'nav.large': 'Large Files',
  'nav.duplicates': 'Duplicates',
  'nav.reclaim': 'Reclaim Space',
  'nav.analyze': 'Disk Analysis',

  'home.title': 'Dashboard',
  'home.subtitle': 'Storage overview for this PC',
  'home.free': 'free',
  'home.usage': '{0} of {1} used',
  'home.refresh': 'Refresh',

  'reclaim.title': 'Reclaim Space',
  'reclaim.subtitle':
      'Space Windows sets aside for itself, used or not',

  'quick.title': 'Quick Clean',
  'quick.subtitle': 'Find and remove temporary files, caches and logs',
  'quick.scan': 'Scan',
  'quick.clean': 'Clean selected',
  'quick.recycle': 'Send to Recycle Bin',
  'quick.selected': '{0} selected · {1}',
  'quick.showFiles': 'Show files',
  'quick.hideFiles': 'Hide files',
  'quick.more': '{0} more files not shown',

  'target.windowsTemp': 'Windows Temp',
  'target.windowsTemp.desc': 'Windows temporary files',
  'target.userTemp': 'User Temp',
  'target.userTemp.desc': 'User temporary files',
  'target.prefetch': 'Prefetch',
  'target.prefetch.desc': 'Windows Prefetch cache',
  'target.thumbnails': 'Thumbnail Cache',
  'target.thumbnails.desc': 'Explorer thumbnail database',
  'target.windowsUpdate': 'Windows Update Cache',
  'target.windowsUpdate.desc': 'Downloaded update files',
  'target.logs': 'Log Files',
  'target.logs.desc': 'System and application logs',
  'target.crashDumps': 'Crash Dumps',
  'target.crashDumps.desc': 'Windows crash dump files',
  'target.chromeCache': 'Chrome Cache',
  'target.chromeCache.desc': 'Google Chrome browser cache',
  'target.edgeCache': 'Edge Cache',
  'target.edgeCache.desc': 'Microsoft Edge browser cache',
  'target.pipCache': 'pip Cache',
  'target.pipCache.desc': 'Python pip download cache',
  'target.npmCache': 'npm Cache',
  'target.npmCache.desc': 'Node.js npm cache',

  'elevate.title': 'Running as administrator is recommended',
  'elevate.body':
      'TidyPika is running with ordinary permissions. Files only an '
      'administrator can see — Windows Update downloads, the Windows temp '
      'folder, system logs — are left out of the scan, and what does show up '
      'there cannot be deleted. Restart elevated to work on all of it.',
  'elevate.continue': 'Continue anyway',

  'hiber.title': 'Hibernation',
  'hiber.none': 'Off — no hibernation file on disk',
  'hiber.unknown': 'The setting could not be read',
  'hiber.confirmOn': 'Turn hibernation on?',
  'hiber.confirmOff': 'Turn hibernation off?',
  'hiber.bodyOn':
      'Windows creates the hibernation file again, sized from the '
      'memory installed in this PC — commonly several gigabytes.',
  'hiber.bodyOff':
      '{0} is deleted and {1} goes back to the drive. Fast Startup '
      'uses the same file and turns off with it.',
  'hiber.bodyOffUnknown':
      'The hibernation file at {0} is deleted and its space goes back to '
      'the drive. Fast Startup uses the same file and turns off with it.',
  'hiber.enable': 'Turn on',
  'hiber.disable': 'Turn off',
  'hiber.needsAdmin':
      'Hibernation is a system setting, so changing it needs '
      'administrator rights.',
  'hiber.failed':
      'powercfg could not change the setting. Its own output '
      'follows.',

  'page.title': 'Virtual memory',
  'page.change': 'Change',
  'page.none': 'Off — no paging file',
  'page.unknown': 'The setting could not be read',
  'page.auto': 'Managed by Windows',
  'page.system': 'System managed size',
  'page.custom': '{0}–{1} MB',
  'page.dialogTitle': 'Paging file',
  'page.optionAuto': 'Let Windows manage it',
  'page.optionCustom': 'Set a size on {0}',
  'page.optionNone': 'No paging file',
  'page.initial': 'Initial (MB)',
  'page.maximum': 'Maximum (MB)',
  'page.noneWarning':
      'Without a paging file the machine can run out of memory under '
      'load, some programs refuse to start, and Windows cannot write '
      'a crash dump.',
  'page.invalidSize':
      'Give an initial size above zero and a maximum no smaller '
      'than it.',
  'page.apply': 'Apply',
  'page.needsAdmin':
      'The paging file is a system setting, so changing it needs '
      'administrator rights.',
  'page.failed':
      'The paging file setting could not be changed. The output '
      'follows.',
  'page.rebootTitle': 'Restart to apply',
  'page.reboot':
      'The paging file changes when Windows next starts. Nothing on '
      'disk moves until then.',

  'large.title': 'Large Files',
  'large.subtitle': 'Track down the files using the most space',
  'large.minSize': 'Minimum size',
  'large.scan': 'Scan',

  'dupes.title': 'Duplicate Files',
  'dupes.subtitle': 'Identical files verified by SHA-256 content hash',
  'dupes.scan': 'Scan',
  'dupes.wasted': 'Wasted',
  'dupes.copies': '{0} copies',
  'dupes.groups': '{0} groups',

  'analyze.title': 'Disk Analysis',
  'analyze.subtitle': 'See which folders are taking up space',
  'analyze.run': 'Analyze',
  'analyze.folders': '{0} folders',

  'col.files': 'Files',
  'col.size': 'Size',
  'col.share': 'Share',

  'risk.low': 'Low',
  'risk.medium': 'Medium',
  'risk.high': 'High',

  'stage.preparing': 'Preparing',
  'stage.scanning': 'Scanning',
  'stage.comparing': 'Comparing',
  'stage.hashing': 'Verifying',
  'stage.deleting': 'Deleting',
  'stage.done': 'Done',
  'status.scanned': '{0} files',

  'common.browse': 'Browse',
  'common.cancel': 'Cancel',
  'common.selectAll': 'Select all',
  'common.empty': 'Nothing found',
  'common.emptyHint': 'Run a scan to see results here.',
  'common.working': 'Working...',
  'common.cancelled': 'Cancelled',
  'common.folder': 'Folder',

  'confirm.title': 'Delete these files?',
  'confirm.recycle': '{0} files ({1}) will be moved to the Recycle Bin.',
  'confirm.permanent':
      '{0} files ({1}) will be permanently deleted. This cannot be undone.',
  'confirm.ok': 'Delete',

  'result.title': 'Clean complete',
  'result.body': 'Deleted {0} files and reclaimed {1}.',
  'result.failures': 'Could not remove {0} files:',
  'result.moreFailures': '{0} more',
  'result.elevate': 'Restart as administrator',
  'result.elevateHint':
      'Windows folders refuse a delete unless the app is elevated.',

  'failure.protected': 'Protected',
  'failure.accessDenied': 'Access denied',
  'failure.inUse': 'In use',
  'failure.notFound': 'Already gone',
  'failure.refused': 'Refused',
  'result.close': 'Close',

  'error.title': 'Something went wrong',
};

const Map<String, String> _ko = {
  'app.title': 'TidyPika',
  'app.subtitle': '저장소 클리너',
  'action.language': '언어',

  'nav.home': '홈',
  'nav.quick': '빠른 정리',
  'nav.large': '대용량 파일',
  'nav.duplicates': '중복 파일',
  'nav.reclaim': '용량 줄이기',
  'nav.analyze': '디스크 분석',

  'home.title': '대시보드',
  'home.subtitle': '이 PC의 저장소 현황',
  'home.free': '사용 가능',
  'home.usage': '{1} 중 {0} 사용',
  'home.refresh': '새로 고침',

  'reclaim.title': '용량 줄이기',
  'reclaim.subtitle': 'Windows가 쓰든 안 쓰든 미리 잡아두는 공간',

  'quick.title': '빠른 정리',
  'quick.subtitle': '임시 파일, 캐시, 로그를 찾아 삭제합니다',
  'quick.scan': '검사',
  'quick.clean': '선택 항목 삭제',
  'quick.recycle': '휴지통으로 보내기',
  'quick.selected': '{0}개 선택 · {1}',
  'quick.showFiles': '파일 목록 보기',
  'quick.hideFiles': '파일 목록 숨기기',
  'quick.more': '파일 {0}개는 표시하지 않았습니다',

  'target.windowsTemp': 'Windows 임시 파일',
  'target.windowsTemp.desc': 'Windows 임시 폴더에 쌓인 파일',
  'target.userTemp': '사용자 임시 파일',
  'target.userTemp.desc': '사용자 계정의 임시 폴더',
  'target.prefetch': 'Prefetch',
  'target.prefetch.desc': '앱 실행을 앞당기려고 만드는 미리 읽기 캐시',
  'target.thumbnails': '썸네일 캐시',
  'target.thumbnails.desc': '탐색기 미리 보기 이미지 데이터베이스',
  'target.windowsUpdate': 'Windows Update 캐시',
  'target.windowsUpdate.desc': '내려받아 둔 업데이트 설치 파일',
  'target.logs': '로그 파일',
  'target.logs.desc': '시스템·응용 프로그램 로그',
  'target.crashDumps': '크래시 덤프',
  'target.crashDumps.desc': '프로그램이 비정상 종료할 때 남는 덤프',
  'target.chromeCache': 'Chrome 캐시',
  'target.chromeCache.desc': 'Google Chrome 브라우저 캐시',
  'target.edgeCache': 'Edge 캐시',
  'target.edgeCache.desc': 'Microsoft Edge 브라우저 캐시',
  'target.pipCache': 'pip 캐시',
  'target.pipCache.desc': 'Python pip 다운로드 캐시',
  'target.npmCache': 'npm 캐시',
  'target.npmCache.desc': 'Node.js npm 캐시',

  'elevate.title': '관리자 권한으로 실행하는 것을 권장합니다',
  'elevate.body': '지금은 일반 권한으로 실행 중입니다. Windows Update 다운로드, '
      'Windows 임시 폴더, 시스템 로그처럼 관리자 권한이 있어야 보이는 파일은 '
      '검사에서 아예 빠지고, 보이더라도 삭제할 수 없습니다. 전부 정리하시려면 '
      '관리자 권한으로 다시 실행하세요.',
  'elevate.continue': '이대로 계속',

  'hiber.title': '최대 절전 모드',
  'hiber.none': '꺼짐 — 최대 절전 파일 없음',
  'hiber.unknown': '설정을 읽지 못했습니다',
  'hiber.confirmOn': '최대 절전 모드를 켤까요?',
  'hiber.confirmOff': '최대 절전 모드를 끌까요?',
  'hiber.bodyOn':
      'Windows가 최대 절전 파일을 다시 만듭니다. 크기는 설치된 '
      '메모리에 따라 정해지며 보통 수 GB입니다.',
  'hiber.bodyOff':
      '{0}을(를) 삭제하고 {1}을(를) 드라이브에 돌려줍니다. 같은 '
      '파일을 쓰는 빠른 시작도 함께 꺼집니다.',
  'hiber.bodyOffUnknown':
      '{0}을(를) 삭제하고 그만큼의 공간을 드라이브에 돌려줍니다. 같은 '
      '파일을 쓰는 빠른 시작도 함께 꺼집니다.',
  'hiber.enable': '켜기',
  'hiber.disable': '끄기',
  'hiber.needsAdmin':
      '최대 절전 모드는 시스템 설정이라 관리자 권한이 '
      '필요합니다.',
  'hiber.failed':
      'powercfg가 설정을 바꾸지 못했습니다. 아래는 powercfg가 낸 '
      '출력입니다.',

  'page.title': '가상 메모리',
  'page.change': '변경',
  'page.none': '사용 안 함 — 페이징 파일 없음',
  'page.unknown': '설정을 읽지 못했습니다',
  'page.auto': 'Windows가 관리',
  'page.system': '시스템이 크기 관리',
  'page.custom': '{0}–{1} MB',
  'page.dialogTitle': '페이징 파일',
  'page.optionAuto': 'Windows가 관리하도록 맡기기',
  'page.optionCustom': '{0}에 크기 지정',
  'page.optionNone': '페이징 파일 사용 안 함',
  'page.initial': '초기 크기(MB)',
  'page.maximum': '최대 크기(MB)',
  'page.noneWarning':
      '페이징 파일이 없으면 부하가 걸릴 때 메모리가 모자랄 수 '
      '있고, 일부 프로그램이 실행되지 않으며, Windows가 크래시 '
      '덤프를 남기지 못합니다.',
  'page.invalidSize':
      '초기 크기는 0보다 커야 하고, 최대 크기는 초기 크기보다 '
      '작을 수 없습니다.',
  'page.apply': '적용',
  'page.needsAdmin': '페이징 파일은 시스템 설정이라 관리자 권한이 필요합니다.',
  'page.failed': '페이징 파일 설정을 바꾸지 못했습니다. 아래는 출력입니다.',
  'page.rebootTitle': '다시 시작하면 적용됩니다',
  'page.reboot':
      '페이징 파일은 Windows를 다시 시작할 때 바뀝니다. 그때까지 '
      '디스크에서 달라지는 것은 없습니다.',

  'large.title': '대용량 파일',
  'large.subtitle': '공간을 가장 많이 쓰는 파일을 찾습니다',
  'large.minSize': '최소 크기',
  'large.scan': '검사',

  'dupes.title': '중복 파일',
  'dupes.subtitle': 'SHA-256 해시로 내용이 같은 파일을 확인합니다',
  'dupes.scan': '검사',
  'dupes.wasted': '낭비',
  'dupes.copies': '사본 {0}개',
  'dupes.groups': '{0}개 그룹',

  'analyze.title': '디스크 분석',
  'analyze.subtitle': '어떤 폴더가 공간을 차지하는지 확인합니다',
  'analyze.run': '분석',
  'analyze.folders': '폴더 {0}개',

  'col.files': '파일',
  'col.size': '크기',
  'col.share': '비중',

  'risk.low': '낮음',
  'risk.medium': '보통',
  'risk.high': '높음',

  'stage.preparing': '준비 중',
  'stage.scanning': '검사 중',
  'stage.comparing': '비교 중',
  'stage.hashing': '확인 중',
  'stage.deleting': '삭제 중',
  'stage.done': '완료',
  'status.scanned': '파일 {0}개',

  'common.browse': '찾아보기',
  'common.cancel': '취소',
  'common.selectAll': '전체 선택',
  'common.empty': '결과가 없습니다',
  'common.emptyHint': '검사를 실행하면 결과가 여기에 표시됩니다.',
  'common.working': '작업 중...',
  'common.cancelled': '취소됨',
  'common.folder': '폴더',

  'confirm.title': '파일을 삭제할까요?',
  'confirm.recycle': '파일 {0}개({1})를 휴지통으로 보냅니다.',
  'confirm.permanent': '파일 {0}개({1})를 영구 삭제합니다. 되돌릴 수 없습니다.',
  'confirm.ok': '삭제',

  'result.title': '정리 완료',
  'result.body': '파일 {0}개를 삭제하고 {1}를 확보했습니다.',
  'result.failures': '{0}개는 삭제하지 못했습니다:',
  'result.moreFailures': '외 {0}개 더',
  'result.elevate': '관리자 권한으로 다시 실행',
  'result.elevateHint': 'Windows 폴더는 관리자 권한 없이는 삭제할 수 없습니다.',

  'failure.protected': '보호됨',
  'failure.accessDenied': '권한 없음',
  'failure.inUse': '사용 중',
  'failure.notFound': '이미 없음',
  'failure.refused': '거부됨',
  'result.close': '닫기',

  'error.title': '문제가 발생했습니다',
};

// Japanese.
const Map<String, String> _ja = {
  'app.title': 'TidyPika',
  'app.subtitle': 'ストレージクリーナー',
  'action.language': '言語',

  'nav.home': 'ホーム',
  'nav.quick': 'クイッククリーン',
  'nav.large': '大きいファイル',
  'nav.duplicates': '重複ファイル',
  'nav.reclaim': '容量を空ける',
  'nav.analyze': 'ディスク分析',

  'home.title': 'ダッシュボード',
  'home.subtitle': 'この PC のストレージ概要',
  'home.free': '空き',
  'home.usage': '{1} 中 {0} 使用',
  'home.refresh': '更新',

  'reclaim.title': '容量を空ける',
  'reclaim.subtitle': 'Windows が使う使わないに関わらず確保している領域',

  'quick.title': 'クイッククリーン',
  'quick.subtitle': '一時ファイル、キャッシュ、ログを探して削除します',
  'quick.scan': 'スキャン',
  'quick.clean': '選択した項目を削除',
  'quick.recycle': 'ごみ箱に移動',
  'quick.selected': '{0} 件選択 · {1}',
  'quick.showFiles': 'ファイルを表示',
  'quick.hideFiles': 'ファイルを隠す',
  'quick.more': '他 {0} 件は表示していません',

  'target.windowsTemp': 'Windows 一時ファイル',
  'target.windowsTemp.desc': 'Windows の一時フォルダーにあるファイル',
  'target.userTemp': 'ユーザー一時ファイル',
  'target.userTemp.desc': 'ユーザーアカウントの一時フォルダー',
  'target.prefetch': 'Prefetch',
  'target.prefetch.desc': 'アプリの起動を速くするための先読みキャッシュ',
  'target.thumbnails': 'サムネイルキャッシュ',
  'target.thumbnails.desc': 'エクスプローラーのサムネイルデータベース',
  'target.windowsUpdate': 'Windows Update キャッシュ',
  'target.windowsUpdate.desc': 'ダウンロード済みの更新プログラム',
  'target.logs': 'ログファイル',
  'target.logs.desc': 'システムとアプリケーションのログ',
  'target.crashDumps': 'クラッシュダンプ',
  'target.crashDumps.desc': '異常終了したときに残るダンプファイル',
  'target.chromeCache': 'Chrome キャッシュ',
  'target.chromeCache.desc': 'Google Chrome のブラウザーキャッシュ',
  'target.edgeCache': 'Edge キャッシュ',
  'target.edgeCache.desc': 'Microsoft Edge のブラウザーキャッシュ',
  'target.pipCache': 'pip キャッシュ',
  'target.pipCache.desc': 'Python pip のダウンロードキャッシュ',
  'target.npmCache': 'npm キャッシュ',
  'target.npmCache.desc': 'Node.js npm のキャッシュ',

  'elevate.title': '管理者として実行することをおすすめします',
  'elevate.body':
      '現在は通常の権限で実行しています。Windows Update のダウンロード、'
      'Windows の一時フォルダー、システムログなど、管理者権限がないと'
      '見えないファイルはスキャンから外れ、表示されても削除できません。'
      'すべて整理するには管理者として再起動してください。',
  'elevate.continue': 'このまま続行',

  'hiber.title': 'ハイバネーション',
  'hiber.none': 'オフ — ハイバネーションファイルなし',
  'hiber.unknown': '設定を読み取れませんでした',
  'hiber.confirmOn': 'ハイバネーションを有効にしますか?',
  'hiber.confirmOff': 'ハイバネーションを無効にしますか?',
  'hiber.bodyOn':
      'Windows がハイバネーションファイルを作り直します。サイズは'
      '搭載メモリに応じて決まり、通常は数 GB です。',
  'hiber.bodyOff':
      '{0} を削除し、{1} をドライブに戻します。同じファイルを使う'
      '高速スタートアップも一緒に無効になります。',
  'hiber.bodyOffUnknown':
      '{0} を削除し、その分の容量をドライブに戻します。同じファイルを'
      '使う高速スタートアップも一緒に無効になります。',
  'hiber.enable': '有効にする',
  'hiber.disable': '無効にする',
  'hiber.needsAdmin':
      'ハイバネーションはシステム設定なので管理者権限が'
      '必要です。',
  'hiber.failed':
      'powercfg が設定を変更できませんでした。以下は powercfg の'
      '出力です。',

  'page.title': '仮想メモリ',
  'page.change': '変更',
  'page.none': 'オフ — ページファイルなし',
  'page.unknown': '設定を読み取れませんでした',
  'page.auto': 'Windows が管理',
  'page.system': 'システム管理サイズ',
  'page.custom': '{0}–{1} MB',
  'page.dialogTitle': 'ページファイル',
  'page.optionAuto': 'Windows に任せる',
  'page.optionCustom': '{0} にサイズを指定',
  'page.optionNone': 'ページファイルなし',
  'page.initial': '初期サイズ (MB)',
  'page.maximum': '最大サイズ (MB)',
  'page.noneWarning':
      'ページファイルがないと、負荷時にメモリが不足したり、'
      '起動しないプログラムが出たり、Windows がクラッシュ'
      'ダンプを書けなくなります。',
  'page.invalidSize':
      '初期サイズは 0 より大きく、最大サイズは初期サイズ以上に'
      'してください。',
  'page.apply': '適用',
  'page.needsAdmin': 'ページファイルはシステム設定なので管理者権限が必要です。',
  'page.failed': 'ページファイルの設定を変更できませんでした。以下は出力です。',
  'page.rebootTitle': '再起動後に反映されます',
  'page.reboot':
      'ページファイルは次に Windows を起動したときに変わります。'
      'それまでディスク上は変わりません。',

  'large.title': '大きいファイル',
  'large.subtitle': '最も容量を使っているファイルを探します',
  'large.minSize': '最小サイズ',
  'large.scan': 'スキャン',

  'dupes.title': '重複ファイル',
  'dupes.subtitle': 'SHA-256 ハッシュで内容が同一だと確認したファイル',
  'dupes.scan': 'スキャン',
  'dupes.wasted': '無駄',
  'dupes.copies': '{0} 個の複製',
  'dupes.groups': '{0} グループ',

  'analyze.title': 'ディスク分析',
  'analyze.subtitle': 'どのフォルダーが容量を使っているかを表示します',
  'analyze.run': '分析',
  'analyze.folders': '{0} フォルダー',

  'col.files': 'ファイル数',
  'col.size': 'サイズ',
  'col.share': '割合',

  'risk.low': '低',
  'risk.medium': '中',
  'risk.high': '高',

  'stage.preparing': '準備中',
  'stage.scanning': 'スキャン中',
  'stage.comparing': '比較中',
  'stage.hashing': '検証中',
  'stage.deleting': '削除中',
  'stage.done': '完了',
  'status.scanned': '{0} 件',

  'common.browse': '参照',
  'common.cancel': 'キャンセル',
  'common.selectAll': 'すべて選択',
  'common.empty': '見つかりませんでした',
  'common.emptyHint': 'スキャンを実行すると結果がここに表示されます。',
  'common.working': '処理中...',
  'common.cancelled': 'キャンセルしました',
  'common.folder': 'フォルダー',

  'confirm.title': 'これらのファイルを削除しますか?',
  'confirm.recycle': '{0} 件 ({1}) をごみ箱に移動します。',
  'confirm.permanent': '{0} 件 ({1}) を完全に削除します。元に戻せません。',
  'confirm.ok': '削除',

  'result.title': '削除が完了しました',
  'result.body': '{0} 件を削除し、{1} を回収しました。',
  'result.failures': '{0} 件は削除できませんでした:',
  'result.moreFailures': '他 {0} 件',
  'result.elevate': '管理者として再起動',
  'result.elevateHint': 'Windows のフォルダーは管理者権限がないと削除できません。',

  'failure.protected': '保護',
  'failure.accessDenied': 'アクセス拒否',
  'failure.inUse': '使用中',
  'failure.notFound': '既にありません',
  'failure.refused': '拒否',
  'result.close': '閉じる',

  'error.title': '問題が発生しました',
};

// Simplified Chinese.
const Map<String, String> _zh = {
  'app.title': 'TidyPika',
  'app.subtitle': '存储清理工具',
  'action.language': '语言',

  'nav.home': '主页',
  'nav.quick': '快速清理',
  'nav.large': '大文件',
  'nav.duplicates': '重复文件',
  'nav.reclaim': '释放空间',
  'nav.analyze': '磁盘分析',

  'home.title': '概览',
  'home.subtitle': '这台电脑的存储概况',
  'home.free': '可用',
  'home.usage': '已用 {0}，共 {1}',
  'home.refresh': '刷新',

  'reclaim.title': '释放空间',
  'reclaim.subtitle': 'Windows 无论是否使用都会预留的空间',

  'quick.title': '快速清理',
  'quick.subtitle': '查找并删除临时文件、缓存和日志',
  'quick.scan': '扫描',
  'quick.clean': '删除所选项',
  'quick.recycle': '移到回收站',
  'quick.selected': '已选 {0} 项 · {1}',
  'quick.showFiles': '显示文件',
  'quick.hideFiles': '隐藏文件',
  'quick.more': '另有 {0} 个文件未显示',

  'target.windowsTemp': 'Windows 临时文件',
  'target.windowsTemp.desc': 'Windows 临时文件夹中的文件',
  'target.userTemp': '用户临时文件',
  'target.userTemp.desc': '用户账户的临时文件夹',
  'target.prefetch': 'Prefetch',
  'target.prefetch.desc': '用于加快应用启动的预读缓存',
  'target.thumbnails': '缩略图缓存',
  'target.thumbnails.desc': '资源管理器的缩略图数据库',
  'target.windowsUpdate': 'Windows 更新缓存',
  'target.windowsUpdate.desc': '已下载的更新安装文件',
  'target.logs': '日志文件',
  'target.logs.desc': '系统和应用程序日志',
  'target.crashDumps': '崩溃转储',
  'target.crashDumps.desc': '程序异常退出时留下的转储文件',
  'target.chromeCache': 'Chrome 缓存',
  'target.chromeCache.desc': 'Google Chrome 浏览器缓存',
  'target.edgeCache': 'Edge 缓存',
  'target.edgeCache.desc': 'Microsoft Edge 浏览器缓存',
  'target.pipCache': 'pip 缓存',
  'target.pipCache.desc': 'Python pip 下载缓存',
  'target.npmCache': 'npm 缓存',
  'target.npmCache.desc': 'Node.js npm 缓存',

  'elevate.title': '建议以管理员身份运行',
  'elevate.body':
      '当前以普通权限运行。Windows 更新下载、Windows 临时文件夹、'
      '系统日志等只有管理员才能看到的文件会被排除在扫描之外，'
      '即使显示出来也无法删除。若要全部清理，请以管理员身份重新启动。',
  'elevate.continue': '仍然继续',

  'hiber.title': '休眠',
  'hiber.none': '已关闭 — 没有休眠文件',
  'hiber.unknown': '无法读取该设置',
  'hiber.confirmOn': '要开启休眠吗?',
  'hiber.confirmOff': '要关闭休眠吗?',
  'hiber.bodyOn':
      'Windows 会重新创建休眠文件，大小取决于这台电脑的内存，'
      '通常为数 GB。',
  'hiber.bodyOff':
      '将删除 {0}，并把 {1} 归还给驱动器。使用同一文件的快速启动'
      '也会一并关闭。',
  'hiber.bodyOffUnknown':
      '将删除 {0}，并把相应空间归还给驱动器。使用同一文件的快速启动'
      '也会一并关闭。',
  'hiber.enable': '开启',
  'hiber.disable': '关闭',
  'hiber.needsAdmin': '休眠属于系统设置，需要管理员权限。',
  'hiber.failed': 'powercfg 未能更改设置。以下是 powercfg 的输出。',

  'page.title': '虚拟内存',
  'page.change': '更改',
  'page.none': '已关闭 — 没有页面文件',
  'page.unknown': '无法读取该设置',
  'page.auto': '由 Windows 管理',
  'page.system': '系统管理的大小',
  'page.custom': '{0}–{1} MB',
  'page.dialogTitle': '页面文件',
  'page.optionAuto': '交给 Windows 管理',
  'page.optionCustom': '在 {0} 上指定大小',
  'page.optionNone': '不使用页面文件',
  'page.initial': '初始大小 (MB)',
  'page.maximum': '最大大小 (MB)',
  'page.noneWarning':
      '没有页面文件时，负载高时可能内存不足，部分程序无法启动，'
      'Windows 也无法写入崩溃转储。',
  'page.invalidSize': '初始大小要大于 0，最大大小不能小于初始大小。',
  'page.apply': '应用',
  'page.needsAdmin': '页面文件属于系统设置，需要管理员权限。',
  'page.failed': '未能更改页面文件设置。以下是输出。',
  'page.rebootTitle': '重启后生效',
  'page.reboot':
      '页面文件会在下次启动 Windows 时更改。在此之前磁盘上不会有'
      '变化。',

  'large.title': '大文件',
  'large.subtitle': '找出占用空间最多的文件',
  'large.minSize': '最小大小',
  'large.scan': '扫描',

  'dupes.title': '重复文件',
  'dupes.subtitle': '通过 SHA-256 内容哈希确认内容完全相同的文件',
  'dupes.scan': '扫描',
  'dupes.wasted': '浪费',
  'dupes.copies': '{0} 个副本',
  'dupes.groups': '{0} 组',

  'analyze.title': '磁盘分析',
  'analyze.subtitle': '查看哪些文件夹占用了空间',
  'analyze.run': '分析',
  'analyze.folders': '{0} 个文件夹',

  'col.files': '文件数',
  'col.size': '大小',
  'col.share': '占比',

  'risk.low': '低',
  'risk.medium': '中',
  'risk.high': '高',

  'stage.preparing': '准备中',
  'stage.scanning': '扫描中',
  'stage.comparing': '比较中',
  'stage.hashing': '校验中',
  'stage.deleting': '删除中',
  'stage.done': '完成',
  'status.scanned': '{0} 个文件',

  'common.browse': '浏览',
  'common.cancel': '取消',
  'common.selectAll': '全选',
  'common.empty': '没有找到内容',
  'common.emptyHint': '运行扫描后，结果会显示在这里。',
  'common.working': '正在处理...',
  'common.cancelled': '已取消',
  'common.folder': '文件夹',

  'confirm.title': '要删除这些文件吗?',
  'confirm.recycle': '将把 {0} 个文件（{1}）移到回收站。',
  'confirm.permanent': '将永久删除 {0} 个文件（{1}）。此操作无法撤消。',
  'confirm.ok': '删除',

  'result.title': '清理完成',
  'result.body': '已删除 {0} 个文件，回收 {1}。',
  'result.failures': '有 {0} 个文件无法删除：',
  'result.moreFailures': '另有 {0} 个',
  'result.elevate': '以管理员身份重新启动',
  'result.elevateHint': '未提升权限时，Windows 文件夹会拒绝删除。',

  'failure.protected': '受保护',
  'failure.accessDenied': '拒绝访问',
  'failure.inUse': '正在使用',
  'failure.notFound': '已不存在',
  'failure.refused': '被拒绝',
  'result.close': '关闭',

  'error.title': '出现问题',
};

/// Every table, keyed by the language that selects it. `t` falls back to `_en`
/// for anything a table is missing, so a gap surfaces as English rather than a
/// raw key.
const Map<AppLanguage, Map<String, String>> _tables = {
  AppLanguage.english: _en,
  AppLanguage.korean: _ko,
  AppLanguage.japanese: _ja,
  AppLanguage.chinese: _zh,
};
