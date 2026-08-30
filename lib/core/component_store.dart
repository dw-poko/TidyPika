import 'dart:io';

import 'package:path/path.dart' as p;

/// The Windows component store — the WinSxS folder.
///
/// It is the one place a scan cannot measure honestly. WinSxS is built out of
/// hard links: the same bytes appear both there and in the live Windows
/// folders, and anything that walks directories and adds up lengths counts
/// them twice. Explorer does it too, which is where the folklore about a
/// colossal WinSxS comes from.
///
/// DISM knows the difference, so the figures come from DISM rather than from
/// us. It is also the only supported way to shrink the store — deleting from
/// WinSxS by hand breaks servicing.
class ComponentStore {
  const ComponentStore({
    this.reportedSize,
    this.actualSize,
    this.sharedWithWindows,
    this.reclaimable,
  });

  /// What a directory walk says, hard links counted once per name.
  final int? reportedSize;

  /// What the store really occupies.
  final int? actualSize;

  /// The part of it that is the same bytes as the live Windows folders. The
  /// gap between this and nothing is the size of the illusion.
  final int? sharedWithWindows;

  /// Backups, disabled features and cached data — what a cleanup recovers.
  final int? reclaimable;

  bool get known => actualSize != null;
}

/// Reads the numbers out of DISM's report.
///
/// The labels arrive in whatever language Windows was installed in, so they
/// cannot be matched on. The sizes can: they are the only figures carrying a
/// unit, and they come in a fixed order — reported, actual, shared, backups,
/// cache. Everything else on the page is a date or a count.
ComponentStore parseComponentStore(String report) {
  final sizes = <int>[];
  final pattern = RegExp(
    r'([\d][\d.,]*)\s*(bytes|B|KB|MB|GB|TB)(?![\w])',
    caseSensitive: false,
  );

  for (final line in report.split('\n')) {
    final match = pattern.firstMatch(line);
    if (match == null) continue;

    final value = _number(match.group(1)!);
    if (value == null) continue;

    sizes.add((value * _scale(match.group(2)!)).round());
  }

  int? at(int index) => index < sizes.length ? sizes[index] : null;

  final backups = at(3);
  final cache = at(4);

  return ComponentStore(
    reportedSize: at(0),
    actualSize: at(1),
    sharedWithWindows: at(2),
    reclaimable: backups == null ? null : backups + (cache ?? 0),
  );
}

/// DISM prints through the system's number format, so the separators depend on
/// where the machine thinks it is: `16.18` in one place, `16,18` in another,
/// and `1,234.56` in a third.
double? _number(String text) {
  final comma = text.lastIndexOf(',');
  final dot = text.lastIndexOf('.');

  // Whichever comes last is the decimal point; the other groups digits.
  final normalised = comma > dot
      ? text.replaceAll('.', '').replaceAll(',', '.')
      : text.replaceAll(',', '');

  return double.tryParse(normalised);
}

int _scale(String unit) => switch (unit.toUpperCase()) {
      'TB' => 1024 * 1024 * 1024 * 1024,
      'GB' => 1024 * 1024 * 1024,
      'MB' => 1024 * 1024,
      'KB' => 1024,
      _ => 1,
    };

/// Reads the store's real size. Needs elevation; DISM refuses otherwise.
Future<ComponentStore> readComponentStore() async {
  final result = await _dism([
    '/Online',
    '/Cleanup-Image',
    '/AnalyzeComponentStore',
  ]);

  if (result.exitCode != 0) return const ComponentStore();

  return parseComponentStore('${result.stdout}');
}

/// Runs the cleanup. Minutes rather than seconds: it is rebuilding the store,
/// not deleting files.
Future<ProcessResult> cleanComponentStore() =>
    _dism(['/Online', '/Cleanup-Image', '/StartComponentCleanup']);

Future<ProcessResult> _dism(List<String> arguments) {
  final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';

  return Process.run(p.join(root, 'System32', 'Dism.exe'), arguments);
}
