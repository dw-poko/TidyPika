/// Plain data passed between the scanning isolates and the UI.
library;

typedef ProgressCallback = void Function(ScanProgress progress);

enum Risk { low, medium, high }

enum ScanStage { preparing, scanning, comparing, hashing, deleting, done }

class CleanTarget {
  const CleanTarget({
    required this.id,
    required this.paths,
    this.patterns = const ['*'],
    this.risk = Risk.low,
  });

  /// Looks up `target.<id>` and `target.<id>.desc` for display. The targets are
  /// built inside a scanning isolate, which holds its own copy of the language
  /// setting and would answer in English whatever the window is showing, so the
  /// words are chosen where they are drawn.
  final String id;

  final List<String> paths;
  final List<String> patterns;
  final Risk risk;
}

class FileEntry {
  const FileEntry(this.path, this.size);

  final String path;
  final int size;
}

class ScanResult {
  const ScanResult({
    required this.target,
    required this.files,
    required this.totalSize,
    required this.errors,
  });

  final CleanTarget target;
  final List<FileEntry> files;
  final int totalSize;
  final int errors;
}

class DirectoryEntry {
  const DirectoryEntry({
    required this.path,
    required this.name,
    required this.size,
    required this.fileCount,
    this.isLooseFiles = false,
  });

  final String path;
  final String name;
  final int size;
  final int fileCount;

  /// Not a sub-folder but the files lying directly in the one being analysed.
  /// Without it the total counts only what is in sub-folders, and every step
  /// further in loses whatever was left behind at the last one.
  final bool isLooseFiles;
}

class DuplicateGroup {
  const DuplicateGroup({
    required this.hashPrefix,
    required this.size,
    required this.files,
  });

  final String hashPrefix;
  final int size;
  final List<String> files;

  /// What could be reclaimed by keeping a single copy.
  int get wastedSize => size * (files.length - 1);
}

/// Why a file is still there after a clean.
///
/// The reason has to travel back from the scanning isolate, so it is carried
/// as data and turned into words by the UI — the isolate has its own copy of
/// the language setting and would always answer in English.
enum CleanFailure { protected, accessDenied, inUse, notFound, refused }

class CleanError {
  const CleanError(this.path, this.reason);

  final String path;
  final CleanFailure reason;
}

class CleanResult {
  CleanResult();

  int deleted = 0;
  int freedBytes = 0;
  final List<CleanError> errors = [];

  /// How many files failed for each reason, most common first.
  Map<CleanFailure, int> get failureCounts {
    final counts = <CleanFailure, int>{};
    for (final error in errors) {
      counts[error.reason] = (counts[error.reason] ?? 0) + 1;
    }

    return Map.fromEntries(
      counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  bool get needsElevation =>
      errors.any((error) => error.reason == CleanFailure.accessDenied);
}

class DiskInfo {
  const DiskInfo({
    required this.root,
    required this.total,
    required this.free,
  });

  final String root;
  final int total;
  final int free;

  int get used => total - free;

  double get usedPercent => total > 0 ? used * 100 / total : 0;
}

/// One progress tick. [total] is 0 while the amount of work is still unknown,
/// which the UI renders as an indeterminate bar.
class ScanProgress {
  const ScanProgress(
    this.stage, {
    this.detail = '',
    this.current = 0,
    this.total = 0,
    this.processed = 0,
  });

  final ScanStage stage;
  final String detail;
  final int current;
  final int total;
  final int processed;

  bool get isIndeterminate => total <= 0;

  double get percent =>
      total > 0 ? (current * 100 / total).clamp(0, 100).toDouble() : 0;
}
