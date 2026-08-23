import 'dart:io';

import 'package:path/path.dart' as p;

import 'win32.dart';

/// The hibernation file and what it costs.
///
/// Windows reserves it up front, sized from installed memory, and it sits
/// there whether or not the machine ever hibernates — on a 32 GB PC that is
/// commonly several gigabytes of the system drive doing nothing.
class HibernationInfo {
  const HibernationInfo({required this.path, required this.size});

  final String path;

  /// Null when the file is not there, which is what the feature being off
  /// looks like on disk.
  final int? size;

  bool get enabled => size != null;
}

String hibernationFile() {
  // SystemDrive is written as `C:`, but strip a trailing separator anyway
  // rather than depend on that and produce `C:\\hiberfil.sys`.
  final drive = (Platform.environment['SystemDrive'] ?? 'C:').replaceAll(
    r'\',
    '',
  );

  return '$drive\\hiberfil.sys';
}

HibernationInfo readHibernation() {
  final path = hibernationFile();
  return HibernationInfo(path: path, size: fileSizeWithoutOpening(path));
}

/// Turns the feature on or off through `powercfg`, which is the only supported
/// way: the file cannot simply be deleted, and Windows would put it back.
///
/// Needs an elevated process. Unelevated, powercfg refuses and exits non-zero,
/// so success is read from the exit code rather than from a message that
/// arrives in whatever language Windows is installed in.
Future<ProcessResult> setHibernation({required bool enabled}) {
  final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';

  return Process.run(
    p.join(root, 'System32', 'powercfg.exe'),
    ['/hibernate', enabled ? 'on' : 'off'],
  );
}
