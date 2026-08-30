import 'dart:io';

import 'paths.dart';
import 'win32.dart';

/// Walks a directory tree, skipping anything that cannot be read.
///
/// `Directory.listSync(recursive: true)` aborts the whole walk on the first
/// permission error, which is guaranteed on a Windows system drive. Links are
/// left out entirely so junctions cannot send the walk round in circles.
///
/// Directories are opened in the extended form once they get long, so a tree
/// deep enough to pass 260 characters is walked rather than skipped. A cleaner
/// that cannot see into a deep node_modules is blind to one of the largest
/// things it is for. Paths come back out in their plain form.
Iterable<String> walkFiles(String root) sync* {
  final stack = <String>[root];

  while (stack.isNotEmpty) {
    final current = stack.removeLast();

    final List<FileSystemEntity> entries;
    try {
      entries = Directory(extendedPath(current)).listSync(followLinks: false);
    } catch (_) {
      continue;
    }

    for (final entry in entries) {
      if (entry is File) {
        yield displayPath(entry.path);
      } else if (entry is Directory) {
        stack.add(displayPath(entry.path));
      }
    }
  }
}

List<String> listSubdirectories(String path) {
  try {
    return Directory(extendedPath(path))
        .listSync(followLinks: false)
        .whereType<Directory>()
        .map((d) => displayPath(d.path))
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Files directly inside [path], without descending.
List<String> listFilesShallow(String path) {
  try {
    return Directory(extendedPath(path))
        .listSync(followLinks: false)
        .whereType<File>()
        .map((f) => displayPath(f.path))
        .toList();
  } catch (_) {
    return const [];
  }
}

/// What the file says it is.
///
/// Used where the number is an identity rather than an amount — two copies of
/// the same bytes have the same length whether or not one of them happens to
/// be compressed, and the duplicate finder groups on that.
int? fileSize(String path) {
  try {
    return File(extendedPath(path)).lengthSync();
  } catch (_) {
    return null;
  }
}

/// What deleting the file would hand back.
///
/// Falls back to the length when the volume will not say — on anything but a
/// compressed or sparse file the two are the same anyway.
int? reclaimableSize(String path) => fileSizeOnDisk(path) ?? fileSize(path);
