import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import 'fs_walk.dart';
import 'models.dart';
import 'paths.dart';
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

/// Places under a protected root that exist to be emptied.
///
/// Update payloads and installer leftovers are expanded packages, so they are
/// full of the same extensions as the system binaries the guard is there for:
/// SoftwareDistribution\Download alone is mostly .dll, .cat, .mui and .inf.
/// Without these exceptions the guard refuses most of what Quick Clean is
/// pointed at, and refuses it silently.
const List<String> _disposableDirectories = [
  r'\softwaredistribution\',
  r'\windows\temp\',
  r'\windows\systemtemp\',
  r'\windows\logs\',
  r'\windows\prefetch\',
  r'\windows\minidump\',
  r'\logfiles\',
];

/// Guards against removing a system binary that happens to sit inside a
/// scanned directory.
bool isProtected(String path) {
  if (!_protectedExtensions.contains(p.extension(path).toLowerCase())) {
    return false;
  }

  final lower = path.toLowerCase();
  if (_disposableDirectories.any(lower.contains)) return false;

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
      result.errors.add(CleanError(path, CleanFailure.protected));
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
      File(extendedPath(path)).deleteSync();
      result.deleted++;
      result.freedBytes += size;
    } on FileSystemException catch (e) {
      result.errors.add(CleanError(path, _reasonFor(e)));
    } catch (_) {
      result.errors.add(CleanError(path, CleanFailure.refused));
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
          result.errors.add(CleanError(batch[i], _whySurvived(batch[i], code)));
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
    // SHFileOperation predates the extended path form and will not take it,
    // so a file this deep can be found and measured but not recycled. Saying
    // so beats deleting it outright when the Recycle Bin was asked for.
    if (exceedsMaxPath(path)) {
      result.errors.add(CleanError(path, CleanFailure.pathTooLong));
      continue;
    }

    if (batchChars + path.length + 1 > maxBatchChars && batch.isNotEmpty) {
      flush();
    }

    batch.add(path);
    batchChars += path.length + 1;
  }

  flush();
}

/// Works out why a file is still on disk after the shell was asked to remove
/// it.
///
/// `SHFileOperation` reports one code for the whole batch and says nothing
/// about which file objected, so each survivor is opened for reading first —
/// a lock or a denied ACL shows up there, and read-only open cannot create or
/// alter anything. A file that opens cleanly is one we may read but not
/// delete, and then the batch code is the only evidence left.
CleanFailure _whySurvived(String path, int shellCode) {
  RandomAccessFile? handle;

  try {
    handle = File(path).openSync();
    return _fromShellCode(shellCode);
  } on FileSystemException catch (e) {
    final reason = _reasonFor(e);
    return reason == CleanFailure.refused ? _fromShellCode(shellCode) : reason;
  } catch (_) {
    return _fromShellCode(shellCode);
  } finally {
    try {
      handle?.closeSync();
    } catch (_) {
      // The handle goes away with the isolate either way.
    }
  }
}

CleanFailure _fromShellCode(int code) {
  switch (code) {
    case 0x78: // DE_ACCESSDENIEDSRC
    case 5: // ERROR_ACCESS_DENIED
      return CleanFailure.accessDenied;
    case 0x20: // ERROR_SHARING_VIOLATION
      return CleanFailure.inUse;
    default:
      return CleanFailure.refused;
  }
}

CleanFailure _reasonFor(FileSystemException error) {
  switch (error.osError?.errorCode) {
    case 5: // ERROR_ACCESS_DENIED
      return CleanFailure.accessDenied;
    case 32: // ERROR_SHARING_VIOLATION
    case 33: // ERROR_LOCK_VIOLATION
      return CleanFailure.inUse;
    case 2: // ERROR_FILE_NOT_FOUND
    case 3: // ERROR_PATH_NOT_FOUND
      return CleanFailure.notFound;
    default:
      return CleanFailure.refused;
  }
}

/// What removing this file hands back, which is the number the result
/// reports. A compressed file gives back less than its length says.
int _sizeOrZero(String path) => reclaimableSize(path) ?? 0;
