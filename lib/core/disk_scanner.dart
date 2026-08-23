import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'models.dart';
import 'win32.dart';

/// The drive Windows is installed on, as a root path such as `C:\`.
String systemDriveRoot() {
  // SystemDrive is written as `C:`, but strip a trailing separator anyway
  // rather than depend on that and produce a doubled one.
  final drive = (Platform.environment['SystemDrive'] ?? 'C:').replaceAll(
    r'\',
    '',
  );

  return '$drive\\';
}

List<DiskInfo> getDisks() {
  final disks = <DiskInfo>[];
  final mask = getLogicalDrives();

  for (var i = 0; i < 26; i++) {
    if (mask & (1 << i) == 0) continue;

    final root = '${String.fromCharCode(65 + i)}:\\';
    final rootPtr = root.toNativeUtf16();

    try {
      final type = getDriveType(rootPtr);
      if (type != driveFixed && type != driveRemovable) continue;

      final free = calloc<Uint64>();
      final total = calloc<Uint64>();
      final totalFree = calloc<Uint64>();

      try {
        if (getDiskFreeSpaceEx(rootPtr, free, total, totalFree) == 0) continue;
        if (total.value == 0) continue;

        disks.add(DiskInfo(root: root, total: total.value, free: free.value));
      } finally {
        calloc
          ..free(free)
          ..free(total)
          ..free(totalFree);
      }
    } finally {
      calloc.free(rootPtr);
    }
  }

  return disks;
}
