import 'dart:io';

import 'package:path/path.dart' as p;

/// Folders the scans leave alone.
///
/// A tool that deletes things needs a way to be told not to. A game install
/// with legitimately huge files, a backup folder whose duplicates are the
/// point, a working set of raw footage — all of them look exactly like waste
/// to a scanner, and no amount of cleverness about sizes will tell them apart
/// from the outside.
///
/// Kept as plain lines in a file so it can be read, edited and understood
/// without this app.
File _file() {
  final base =
      Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;

  return File(p.join(base, 'TidyPika', 'exclusions.txt'));
}

List<String> readExclusions() {
  try {
    final file = _file();
    if (!file.existsSync()) return const [];

    return [
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty) line.trim(),
    ];
  } catch (_) {
    return const [];
  }
}

void writeExclusions(List<String> folders) {
  try {
    final file = _file();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(folders.join('\n'));
  } catch (_) {
    // Best effort, like the rest of what this app remembers.
  }
}

/// Prepared once per scan so the comparison inside the walk is a plain string
/// test rather than a normalisation.
Set<String> excludedRoots() => {
      for (final folder in readExclusions()) normaliseExclusion(folder),
    };

String normaliseExclusion(String folder) {
  var normalised = folder.trim().replaceAll('/', r'\').toLowerCase();
  while (normalised.endsWith(r'\') && normalised.length > 3) {
    normalised = normalised.substring(0, normalised.length - 1);
  }

  return normalised;
}

/// Whether a path is one of the excluded folders or sits inside one.
///
/// Matching on the separator matters: `C:\Games` must not exclude
/// `C:\GamesBackup`, which a plain prefix test would.
bool isExcluded(String path, Set<String> roots) {
  if (roots.isEmpty) return false;

  final candidate = normaliseExclusion(path);

  for (final root in roots) {
    if (candidate == root) return true;

    final boundary = root.endsWith(r'\') ? root : '$root\\';
    if (candidate.startsWith(boundary)) return true;
  }

  return false;
}
