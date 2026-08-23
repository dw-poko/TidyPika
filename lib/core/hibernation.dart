import 'dart:io';

import 'package:path/path.dart' as p;

import 'win32.dart';

/// The hibernation file and what it costs.
///
/// Windows reserves it up front, sized from installed memory, and it sits
/// there whether or not the machine ever hibernates — on a 32 GB PC that is
/// commonly several gigabytes of the system drive doing nothing.
/// Whether the feature is on, off, or not something this app could find out.
///
/// The third case is not a nicety: every wrong answer this card has given was
/// a failed read shown as an off switch.
enum HibernationState { on, off, unknown }

class HibernationInfo {
  const HibernationInfo({
    required this.path,
    required this.state,
    required this.size,
  });

  final String path;

  final HibernationState state;

  /// Null when the size could not be read, which is not the same as the
  /// feature being off — hence [state] being asked separately.
  final int? size;

  bool get enabled => state == HibernationState.on;
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

/// Whether Windows has the feature switched on, straight from the setting
/// rather than inferred.
///
/// The file on disk is the obvious signal and a poor one: it is readable only
/// in ways that can fail for reasons unrelated to the setting. This value is
/// under HKLM\SYSTEM, which every account may read.
bool? _hibernateEnabled() {
  final value = registryDword(
    hkeyLocalMachine,
    r'SYSTEM\CurrentControlSet\Control\Power',
    'HibernateEnabled',
  );

  return value == null ? null : value != 0;
}

HibernationInfo readHibernation() {
  final path = hibernationFile();
  final size = fileSizeFromDirectory(path);

  return HibernationInfo(
    path: path,
    state: _stateFrom(_hibernateEnabled(), size),
    size: size,
  );
}

/// The setting decides. Without it, a file that is there still proves the
/// feature is on — but a file that is not there proves nothing, since a read
/// that failed and a file that is absent look the same from here. That case
/// is reported as unknown rather than guessed at as off.
HibernationState _stateFrom(bool? setting, int? size) {
  if (setting != null) {
    return setting ? HibernationState.on : HibernationState.off;
  }

  return size != null ? HibernationState.on : HibernationState.unknown;
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
