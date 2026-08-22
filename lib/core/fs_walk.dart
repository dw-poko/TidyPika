import 'dart:io';

/// Walks a directory tree, skipping anything that cannot be read.
///
/// `Directory.listSync(recursive: true)` aborts the whole walk on the first
/// permission error, which is guaranteed on a Windows system drive. Links are
/// left out entirely so junctions cannot send the walk round in circles.
Iterable<String> walkFiles(String root) sync* {
  final stack = <String>[root];

  while (stack.isNotEmpty) {
    final current = stack.removeLast();

    final List<FileSystemEntity> entries;
    try {
      entries = Directory(current).listSync(followLinks: false);
    } catch (_) {
      continue;
    }

    for (final entry in entries) {
      if (entry is File) {
        yield entry.path;
      } else if (entry is Directory) {
        stack.add(entry.path);
      }
    }
  }
}

List<String> listSubdirectories(String path) {
  try {
    return Directory(path)
        .listSync(followLinks: false)
        .whereType<Directory>()
        .map((d) => d.path)
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Files directly inside [path], without descending.
List<String> listFilesShallow(String path) {
  try {
    return Directory(path)
        .listSync(followLinks: false)
        .whereType<File>()
        .map((f) => f.path)
        .toList();
  } catch (_) {
    return const [];
  }
}

int? fileSize(String path) {
  try {
    return File(path).lengthSync();
  } catch (_) {
    return null;
  }
}
