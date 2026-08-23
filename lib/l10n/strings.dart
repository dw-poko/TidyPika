import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../core/win32.dart';

enum AppLanguage { korean, english }

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

void toggleLanguage() {
  language.value = language.value == AppLanguage.korean
      ? AppLanguage.english
      : AppLanguage.korean;
}

String t(String key) {
  final table = language.value == AppLanguage.korean ? _ko : _en;
  return table[key] ?? _en[key] ?? key;
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
    return primaryUiLanguage() == langKorean
        ? AppLanguage.korean
        : AppLanguage.english;
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

    switch (file.readAsStringSync().trim()) {
      case 'ko':
        return AppLanguage.korean;
      case 'en':
        return AppLanguage.english;
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
    file.writeAsStringSync(value == AppLanguage.korean ? 'ko' : 'en');
  } catch (_) {
    // Remembering the choice is best-effort.
  }
}

const Map<String, String> _en = {
  'app.title': 'TidyPika',
  'app.subtitle': 'Storage Cleaner',
  'action.language': '한국어',

  'nav.home': 'Home',
  'nav.quick': 'Quick Clean',
  'nav.large': 'Large Files',
  'nav.duplicates': 'Duplicates',
  'nav.analyze': 'Disk Analysis',

  'home.title': 'Dashboard',
  'home.subtitle': 'Storage overview for this PC',
  'home.free': 'free',
  'home.usage': '{0} of {1} used',
  'home.refresh': 'Refresh',

  'quick.title': 'Quick Clean',
  'quick.subtitle': 'Find and remove temporary files, caches and logs',
  'quick.scan': 'Scan',
  'quick.clean': 'Clean selected',
  'quick.recycle': 'Send to Recycle Bin',
  'quick.selected': '{0} selected · {1}',
  'quick.showFiles': 'Show files',
  'quick.hideFiles': 'Hide files',
  'quick.more': '{0} more files not shown',

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
  'action.language': 'English',

  'nav.home': '홈',
  'nav.quick': '빠른 정리',
  'nav.large': '대용량 파일',
  'nav.duplicates': '중복 파일',
  'nav.analyze': '디스크 분석',

  'home.title': '대시보드',
  'home.subtitle': '이 PC의 저장소 현황',
  'home.free': '사용 가능',
  'home.usage': '{1} 중 {0} 사용',
  'home.refresh': '새로 고침',

  'quick.title': '빠른 정리',
  'quick.subtitle': '임시 파일, 캐시, 로그를 찾아 삭제합니다',
  'quick.scan': '검사',
  'quick.clean': '선택 항목 삭제',
  'quick.recycle': '휴지통으로 보내기',
  'quick.selected': '{0}개 선택 · {1}',
  'quick.showFiles': '파일 목록 보기',
  'quick.hideFiles': '파일 목록 숨기기',
  'quick.more': '파일 {0}개는 표시하지 않았습니다',

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
