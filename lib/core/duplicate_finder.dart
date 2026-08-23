import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

import 'fs_walk.dart';
import 'models.dart';

const int _quickHashSize = 4096;

/// Where the walk gives up.
///
/// Only paths of files at or above the minimum size are held, so the cost is
/// tens of megabytes at this count — enough for a user profile several times
/// over, and short of what would put a scan of an entire drive in trouble.
const int maxIndexedFiles = 400000;

const int _progressInterval = 200;

DuplicateScan findDuplicates(
  String root, {
  int minSizeBytes = 1024,
  ProgressCallback? onProgress,
}) {
  // Phase 1 — bucket by exact size. A file with a unique size cannot have a
  // twin, so this discards most of the tree before any hashing happens. The
  // tree size is unknown up front, so this phase reports no percentage.
  onProgress?.call(ScanProgress(ScanStage.preparing, detail: root));

  final sizeGroups = <int, List<String>>{};
  var indexed = 0;

  for (final path in walkFiles(root)) {
    final size = fileSize(path);
    if (size == null) continue;

    indexed++;
    if (indexed % _progressInterval == 0) {
      onProgress?.call(
        ScanProgress(ScanStage.preparing, detail: root, processed: indexed),
      );
    }

    if (size >= minSizeBytes) {
      sizeGroups.putIfAbsent(size, () => <String>[]).add(path);
    }

    if (indexed >= maxIndexedFiles) break;
  }

  sizeGroups.removeWhere((_, paths) => paths.length < 2);

  // Phases 2 and 3 have known workloads, so from here the percentage is real.
  // Phase 3 re-reads at most the files phase 2 keeps, so budgeting two passes
  // over the candidates keeps the percentage from snapping backwards when the
  // real phase-3 count becomes known.
  final quickCount = sizeGroups.values.fold(0, (sum, v) => sum + v.length);
  final total = quickCount * 2 == 0 ? 1 : quickCount * 2;
  var done = 0;

  // Phase 2 — hash the first 4 KB to cheaply split same-size buckets.
  final quickGroups = <String, List<String>>{};
  for (final entry in sizeGroups.entries) {
    for (final path in entry.value) {
      done++;
      if (done % _progressInterval == 0 || done == 1) {
        onProgress?.call(
          ScanProgress(
            ScanStage.comparing,
            detail: path,
            current: done,
            total: total,
            processed: done,
          ),
        );
      }

      final hash = _hashFile(path, maxBytes: _quickHashSize);
      if (hash == null) continue;

      quickGroups.putIfAbsent('${entry.key}:$hash', () => <String>[]).add(path);
    }
  }

  quickGroups.removeWhere((_, paths) => paths.length < 2);

  // Phase 3 — a full content hash confirms the survivors really are identical.
  final fullGroups = <String, List<String>>{};
  final sizeOfHash = <String, int>{};

  for (final entry in quickGroups.entries) {
    final separator = entry.key.indexOf(':');
    final size = int.parse(entry.key.substring(0, separator));
    final quickHash = entry.key.substring(separator + 1);

    // The quick hash covers the first 4 KB, so for a file no larger than that
    // it already is the full hash. Re-reading those files would spend a second
    // pass confirming something the first pass settled, which on a tree full
    // of small duplicates is half the reading this phase does.
    final settled = size <= _quickHashSize;

    for (final path in entry.value) {
      done++;
      if (done % _progressInterval == 0 || done == quickCount + 1) {
        onProgress?.call(
          ScanProgress(
            ScanStage.hashing,
            detail: path,
            current: done,
            total: total,
            processed: done,
          ),
        );
      }

      final hash = settled ? quickHash : _hashFile(path);
      if (hash == null) continue;

      fullGroups.putIfAbsent(hash, () => <String>[]).add(path);
      sizeOfHash[hash] = size;
    }
  }

  final results = <DuplicateGroup>[];
  for (final entry in fullGroups.entries) {
    if (entry.value.length < 2) continue;

    entry.value.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    results.add(
      DuplicateGroup(
        hashPrefix: entry.key.substring(0, 16),
        size: sizeOfHash[entry.key] ?? 0,
        files: entry.value,
      ),
    );
  }

  onProgress?.call(
    ScanProgress(
      ScanStage.done,
      current: total,
      total: total,
      processed: done,
    ),
  );

  results.sort((a, b) => b.wastedSize.compareTo(a.wastedSize));

  return DuplicateScan(
    groups: results,
    indexed: indexed,
    limit: maxIndexedFiles,
  );
}

/// SHA-256 of a file, or of its first [maxBytes] when given. Streamed in chunks
/// so a multi-gigabyte candidate never has to be held in memory.
String? _hashFile(String path, {int? maxBytes}) {
  RandomAccessFile? handle;

  try {
    handle = File(path).openSync();

    if (maxBytes != null) {
      return sha256.convert(handle.readSync(maxBytes)).toString();
    }

    final output = AccumulatorSink<Digest>();
    final input = sha256.startChunkedConversion(output);

    while (true) {
      final chunk = handle.readSync(65536);
      if (chunk.isEmpty) break;
      input.add(chunk);
    }

    input.close();
    return output.events.single.toString();
  } catch (_) {
    return null;
  } finally {
    try {
      handle?.closeSync();
    } catch (_) {
      // Nothing useful to do if the handle will not close.
    }
  }
}
