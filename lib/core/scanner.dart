import 'dart:io';

import 'package:path/path.dart' as p;

import 'fs_walk.dart';
import 'models.dart';

/// Files to get through before refreshing the live counter.
const int _progressInterval = 2000;

List<CleanTarget> getCleanTargets() {
  final env = Platform.environment;
  final windows = env['SystemRoot'] ?? r'C:\Windows';
  final localAppData =
      env['LOCALAPPDATA'] ?? p.join(env['USERPROFILE'] ?? r'C:\', 'AppData', 'Local');
  final appData =
      env['APPDATA'] ?? p.join(env['USERPROFILE'] ?? r'C:\', 'AppData', 'Roaming');
  final temp = env['TEMP'] ?? env['TMP'] ?? p.join(localAppData, 'Temp');
  final programData = env['ProgramData'] ?? r'C:\ProgramData';

  return [
    CleanTarget(
      id: 'windowsTemp',
      paths: [p.join(windows, 'Temp')],
    ),
    CleanTarget(
      id: 'userTemp',
      paths: [temp],
    ),
    CleanTarget(
      id: 'prefetch',
      paths: [p.join(windows, 'Prefetch')],
      patterns: const ['*.pf'],
      risk: Risk.medium,
    ),
    CleanTarget(
      id: 'thumbnails',
      paths: [p.join(localAppData, 'Microsoft', 'Windows', 'Explorer')],
      patterns: const ['thumbcache_*.db'],
    ),
    CleanTarget(
      id: 'windowsUpdate',
      paths: [p.join(windows, 'SoftwareDistribution', 'Download')],
      risk: Risk.medium,
    ),
    CleanTarget(
      id: 'logs',
      paths: [
        p.join(windows, 'Logs'),
        p.join(windows, 'System32', 'LogFiles'),
      ],
      patterns: const ['*.log', '*.etl', '*.old'],
    ),
    CleanTarget(
      id: 'crashDumps',
      paths: [
        p.join(windows, 'Minidump'),
        p.join(localAppData, 'CrashDumps'),
      ],
      patterns: const ['*.dmp'],
    ),
    CleanTarget(
      id: 'chromeCache',
      paths: chromiumCaches(
        p.join(localAppData, 'Google', 'Chrome', 'User Data'),
      ),
    ),
    CleanTarget(
      id: 'edgeCache',
      paths: chromiumCaches(
        p.join(localAppData, 'Microsoft', 'Edge', 'User Data'),
      ),
    ),
    CleanTarget(
      id: 'firefoxCache',
      paths: firefoxCaches(localAppData),
    ),
    CleanTarget(
      id: 'deliveryOptimization',
      paths: [p.join(windows, 'SoftwareDistribution', 'DeliveryOptimization')],
      risk: Risk.medium,
    ),
    CleanTarget(
      id: 'errorReports',
      paths: [
        p.join(localAppData, 'Microsoft', 'Windows', 'WER', 'ReportArchive'),
        p.join(localAppData, 'Microsoft', 'Windows', 'WER', 'ReportQueue'),
        p.join(programData, 'Microsoft', 'Windows', 'WER', 'ReportArchive'),
        p.join(programData, 'Microsoft', 'Windows', 'WER', 'ReportQueue'),
      ],
    ),
    CleanTarget(
      id: 'shaderCache',
      paths: [
        p.join(localAppData, 'D3DSCache'),
        p.join(localAppData, 'NVIDIA', 'DXCache'),
        p.join(localAppData, 'NVIDIA', 'GLCache'),
        p.join(localAppData, 'AMD', 'DxCache'),
      ],
    ),
    CleanTarget(
      id: 'teamsCache',
      paths: electronCaches(p.join(appData, 'Microsoft', 'Teams')),
    ),
    CleanTarget(
      id: 'discordCache',
      paths: electronCaches(p.join(appData, 'discord')),
    ),
    CleanTarget(
      id: 'slackCache',
      paths: electronCaches(p.join(appData, 'Slack')),
    ),
    CleanTarget(
      id: 'vscodeCache',
      paths: [
        ...electronCaches(p.join(appData, 'Code')),
        p.join(appData, 'Code', 'CachedData'),
      ],
    ),
    CleanTarget(
      id: 'pipCache',
      paths: [p.join(localAppData, 'pip', 'cache')],
    ),
    CleanTarget(
      id: 'npmCache',
      paths: [p.join(appData, 'npm-cache')],
    ),
  ];
}

/// Cache folders under every profile of a Chromium browser, not only the
/// default one. A second profile's cache is the same kind of file and just as
/// disposable, and listing only `Default` quietly missed it.
///
/// Directories that turn out not to exist are skipped by the scan, so nothing
/// is lost by naming a few that never will.
List<String> chromiumCaches(String userData) {
  const folders = ['Cache', 'Code Cache', 'GPUCache'];

  return [
    for (final profile in [userData, ...listSubdirectories(userData)])
      for (final folder in folders) p.join(profile, folder),
  ];
}

/// Firefox keeps a cache per profile under a directory named for the profile,
/// so the profiles have to be looked up rather than written down.
List<String> firefoxCaches(String localAppData) {
  final profiles = p.join(localAppData, 'Mozilla', 'Firefox', 'Profiles');

  return [
    for (final profile in listSubdirectories(profiles))
      p.join(profile, 'cache2'),
  ];
}

/// The cache directories every Electron application keeps in the same shape.
List<String> electronCaches(String root) => [
      p.join(root, 'Cache'),
      p.join(root, 'Code Cache'),
      p.join(root, 'GPUCache'),
      p.join(root, 'Service Worker', 'CacheStorage'),
    ];

bool matchesPatterns(String fileName, List<String> patterns) {
  if (patterns.isEmpty || (patterns.length == 1 && patterns.first == '*')) {
    return true;
  }

  final lower = fileName.toLowerCase();
  for (final pattern in patterns) {
    final pat = pattern.toLowerCase();

    if (pat.startsWith('*.')) {
      if (lower.endsWith(pat.substring(1))) return true;
    } else if (pat.contains('*')) {
      if (_globMatch(pat, lower)) return true;
    } else if (lower == pat) {
      return true;
    }
  }

  return false;
}

bool _globMatch(String pattern, String text) {
  final star = pattern.indexOf('*');
  if (star < 0) return pattern == text;

  final prefix = pattern.substring(0, star);
  final suffix = pattern.substring(star + 1);

  return text.length >= prefix.length + suffix.length &&
      text.startsWith(prefix) &&
      text.endsWith(suffix);
}

ScanResult scanTarget(
  CleanTarget target, {
  ProgressCallback? onProgress,
  int current = 0,
  int total = 0,
  int processedSoFar = 0,
}) {
  final files = <FileEntry>[];
  var totalSize = 0;
  var errors = 0;
  var seen = processedSoFar;

  for (final basePath in target.paths) {
    if (basePath.isEmpty || !Directory(basePath).existsSync()) continue;

    for (final path in walkFiles(basePath)) {
      seen++;
      if (seen % _progressInterval == 0) {
        onProgress?.call(
          ScanProgress(
            ScanStage.scanning,
            detail: target.id,
            current: current,
            total: total,
            processed: seen,
          ),
        );
      }

      if (!matchesPatterns(p.basename(path), target.patterns)) continue;

      final size = reclaimableSize(path);
      if (size == null) {
        errors++;
        continue;
      }

      files.add(FileEntry(path, size));
      totalSize += size;
    }
  }

  return ScanResult(
    target: target,
    files: files,
    totalSize: totalSize,
    errors: errors,
  );
}

List<ScanResult> scanAllTargets({ProgressCallback? onProgress}) {
  final targets = getCleanTargets();
  final results = <ScanResult>[];
  var seen = 0;

  for (var i = 0; i < targets.length; i++) {
    final target = targets[i];
    onProgress?.call(
      ScanProgress(
        ScanStage.scanning,
        detail: target.id,
        current: i,
        total: targets.length,
        processed: seen,
      ),
    );

    final result = scanTarget(
      target,
      onProgress: onProgress,
      current: i,
      total: targets.length,
      processedSoFar: seen,
    );

    seen += result.files.length;
    results.add(result);
  }

  onProgress?.call(
    ScanProgress(
      ScanStage.done,
      current: targets.length,
      total: targets.length,
      processed: seen,
    ),
  );

  results.sort((a, b) => b.totalSize.compareTo(a.totalSize));
  return results;
}

/// Treats each immediate sub-directory as one unit of work, which is what makes
/// a meaningful percentage possible in a single pass — counting every file up
/// front would mean walking the tree twice.
List<FileEntry> scanLargeFiles(
  String root,
  int minSizeBytes, {
  int maxResults = 500,
  ProgressCallback? onProgress,
}) {
  final results = <FileEntry>[];
  var seen = 0;

  onProgress?.call(ScanProgress(ScanStage.preparing, detail: root));

  final branches = <String>[root, ...listSubdirectories(root)];

  for (var i = 0; i < branches.length; i++) {
    final branch = branches[i];
    onProgress?.call(
      ScanProgress(
        ScanStage.scanning,
        detail: branch,
        current: i,
        total: branches.length,
        processed: seen,
      ),
    );

    // The first branch is the root itself, so only its direct files: everything
    // below is covered by the sub-directory branches.
    final files = i == 0 ? listFilesShallow(branch) : walkFiles(branch);

    for (final path in files) {
      final size = reclaimableSize(path);
      if (size != null && size >= minSizeBytes) {
        results.add(FileEntry(path, size));
      }

      seen++;
      if (seen % _progressInterval == 0) {
        onProgress?.call(
          ScanProgress(
            ScanStage.scanning,
            detail: branch,
            current: i,
            total: branches.length,
            processed: seen,
          ),
        );
      }
    }
  }

  onProgress?.call(
    ScanProgress(
      ScanStage.done,
      current: branches.length,
      total: branches.length,
      processed: seen,
    ),
  );

  results.sort((a, b) => b.size.compareTo(a.size));
  if (results.length > maxResults) results.length = maxResults;
  return results;
}

/// Loose files sent back with the report. The list is for reading, not for
/// arithmetic — the entry's count and size cover every file, listed or not.
const int maxLooseFilesListed = 200;

DirectoryReport analyzeDirectory(
  String root, {
  ProgressCallback? onProgress,
}) {
  onProgress?.call(ScanProgress(ScanStage.preparing, detail: root));

  final children = listSubdirectories(root);
  final entries = <DirectoryEntry>[];
  var seen = 0;

  // The files directly inside, before the sub-folders: they belong to this
  // folder as much as any sub-folder does, and leaving them out makes the
  // total smaller than the folder.
  final loose = <FileEntry>[];
  var looseSize = 0;

  for (final path in listFilesShallow(root)) {
    final size = reclaimableSize(path);
    if (size == null) continue;

    loose.add(FileEntry(path, size));
    looseSize += size;
  }

  loose.sort((a, b) => b.size.compareTo(a.size));

  if (loose.isNotEmpty) {
    entries.add(
      DirectoryEntry(
        path: root,
        name: root,
        size: looseSize,
        fileCount: loose.length,
        isLooseFiles: true,
      ),
    );
  }

  if (loose.length > maxLooseFilesListed) {
    loose.length = maxLooseFilesListed;
  }

  for (var i = 0; i < children.length; i++) {
    final dir = children[i];
    onProgress?.call(
      ScanProgress(
        ScanStage.scanning,
        detail: dir,
        current: i,
        total: children.length,
        processed: seen,
      ),
    );

    var size = 0;
    var count = 0;

    for (final path in walkFiles(dir)) {
      final fileBytes = reclaimableSize(path);
      if (fileBytes != null) {
        size += fileBytes;
        count++;
      }

      seen++;
      if (seen % _progressInterval == 0) {
        onProgress?.call(
          ScanProgress(
            ScanStage.scanning,
            detail: dir,
            current: i,
            total: children.length,
            processed: seen,
          ),
        );
      }
    }

    entries.add(
      DirectoryEntry(
        path: dir,
        name: p.basename(dir).isEmpty ? dir : p.basename(dir),
        size: size,
        fileCount: count,
      ),
    );
  }

  onProgress?.call(
    ScanProgress(
      ScanStage.done,
      current: children.length,
      total: children.length,
      processed: seen,
    ),
  );

  entries.sort((a, b) => b.size.compareTo(a.size));

  return DirectoryReport(entries: entries, files: loose);
}
