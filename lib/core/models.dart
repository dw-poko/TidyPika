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
  const FileEntry(this.path, this.size, {this.modified});

  final String path;
  final int size;

  /// When the file was last written. Only filled in where it was asked for:
  /// reading it costs a second look at every file, and most scans have no use
  /// for it.
  ///
  /// Last *written*, not last opened — Windows stopped updating access times
  /// by default years ago, so an access time would be a number that looks
  /// like an answer and is not one.
  final DateTime? modified;
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
enum CleanFailure {
  protected,
  accessDenied,
  inUse,
  notFound,
  refused,

  /// Deeper than the Recycle Bin's shell API can reach. Permanent deletion
  /// still gets there.
  pathTooLong,
}

class CleanError {
  const CleanError(this.path, this.reason);

  final String path;
  final CleanFailure reason;
}

/// What one folder holds: its sub-folders, and the files lying in it.
///
/// The loose files travel as themselves rather than only as a total, so the
/// row that stands for them can be opened and read.
class DirectoryReport {
  const DirectoryReport({required this.entries, required this.files});

  /// Sub-folders, plus a row standing for the loose files when there are any.
  final List<DirectoryEntry> entries;

  /// The loose files, largest first, capped — the count and total on the entry
  /// are of all of them, so what is missing here can still be counted.
  final List<FileEntry> files;
}

/// A duplicate scan and whether it saw the whole tree.
///
/// The walk stops at a fixed number of files so a scan of a very large tree
/// cannot run away with memory. Stopping is defensible; not saying so is not —
/// a partial result that looks complete is worse than no result.
class DuplicateScan {
  const DuplicateScan({
    required this.groups,
    required this.indexed,
    required this.limit,
  });

  final List<DuplicateGroup> groups;

  /// Files walked, whatever their size.
  final int indexed;

  /// The point the walk stops at.
  final int limit;

  bool get truncated => indexed >= limit;
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
