import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'models.dart';
import 'win32.dart';

const Set<String> _protectedExtensions = {
  '.sys',
  '.dll',
  '.exe',
  '.msi',
  '.inf',
  '.cat',
  '.mui',
};

const List<String> _protectedDirectories = [
  r'c:\windows',
  r'c:\program files',
  r'c:\program files (x86)',
];

/// Guards against removing a system binary that happens to sit inside a
/// scanned directory.
bool isProtected(String path) {
  if (!_protectedExtensions.contains(p.extension(path).toLowerCase())) {
    return false;
  }

  final lower = path.toLowerCase();
  return _protectedDirectories.any(lower.startsWith);
}

CleanResult deleteFiles(
  List<String> files, {
  required bool useRecycleBin,
  ProgressCallback? onProgress,
}) {
  final result = CleanResult();
  final candidates = <String>[];

  for (final path in files) {
    if (isProtected(path)) {
      result.errors.add('Protected: $path');
    } else {
      candidates.add(path);
    }
  }

  if (useRecycleBin) {
    _recycle(candidates, result, onProgress);
  } else {
    _deletePermanently(candidates, result, onProgress);
  }

  return result;
}

void _deletePermanently(
  List<String> files,
  CleanResult result,
  ProgressCallback? onProgress,
) {
  var done = 0;

  for (final path in files) {
    final size = _sizeOrZero(path);

    try {
      File(path).deleteSync();
      result.deleted++;
      result.freedBytes += size;
    } catch (e) {
      result.errors.add('$path: $e');
    }

    done++;
    if (done % 200 == 0) {
      onProgress?.call(
        ScanProgress(
          ScanStage.deleting,
          detail: path,
          current: done,
          total: files.length,
          processed: done,
        ),
      );
    }
  }
}

/// Sends files to the Recycle Bin in batches. Success is decided by re-checking
/// existence afterwards, which keeps the accounting accurate without paying for
/// a shell call per file.
void _recycle(
  List<String> files,
  CleanResult result,
  ProgressCallback? onProgress,
) {
  const maxBatchChars = 20000;

  final batch = <String>[];
  var batchChars = 0;
  var done = 0;

  void flush() {
    if (batch.isEmpty) return;

    final sizes = [for (final path in batch) _sizeOrZero(path)];

    final op = calloc<ShFileOpStruct>();
    final from = toPathList(batch, calloc);

    try {
      op.ref
        ..hwnd = nullptr
        ..wFunc = foDelete
        ..pFrom = from
        ..pTo = nullptr
        ..fFlags =
            fofAllowUndo | fofNoConfirmation | fofNoErrorUi | fofSilent
        ..fAnyOperationsAborted = 0
        ..hNameMappings = nullptr
        ..lpszProgressTitle = nullptr;

      final code = shFileOperation(op);

      for (var i = 0; i < batch.length; i++) {
        if (File(batch[i]).existsSync()) {
          result.errors.add(
            code == 0
                ? '${batch[i]}: not removed'
                : '${batch[i]}: shell error 0x${code.toRadixString(16)}',
          );
        } else {
          result.deleted++;
          result.freedBytes += sizes[i];
        }
      }
    } finally {
      calloc
        ..free(from)
        ..free(op);
    }

    done += batch.length;
    onProgress?.call(
      ScanProgress(
        ScanStage.deleting,
        detail: batch.last,
        current: done,
        total: files.length,
        processed: done,
      ),
    );

    batch.clear();
    batchChars = 0;
  }

  for (final path in files) {
    if (batchChars + path.length + 1 > maxBatchChars && batch.isNotEmpty) {
      flush();
    }

    batch.add(path);
    batchChars += path.length + 1;
  }

  flush();
}

int _sizeOrZero(String path) {
  try {
    return File(path).lengthSync();
  } catch (_) {
    return 0;
  }
}
