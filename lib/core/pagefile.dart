import 'dart:io';

import 'package:path/path.dart' as p;

import 'disk_scanner.dart';
import 'win32.dart';

/// How Windows is set to size the paging file.
enum PagefileMode {
  /// "Automatically manage paging file size for all drives".
  automatic,

  /// Named drives, each left for the system to size.
  systemManaged,

  /// Named drives with a size range set by hand.
  custom,

  /// No paging file at all.
  none,

  /// The setting could not be read, which is not the same as any of the above.
  unknown,
}

/// One line of the `PagingFiles` setting: a path, and the range it may grow
/// within. Automatic management writes the drive as `?`.
class PagefileEntry {
  const PagefileEntry({required this.path, this.initialMb, this.maximumMb});

  final String path;
  final int? initialMb;
  final int? maximumMb;

  bool get isAutomatic => path.startsWith('?');

  bool get isSystemManaged => initialMb == 0 && maximumMb == 0;
}

class PagefileInfo {
  const PagefileInfo({
    required this.mode,
    required this.entries,
    required this.files,
    required this.totalSize,
  });

  /// What the setting says.
  final PagefileMode mode;
  final List<PagefileEntry> entries;

  /// What is actually on disk. A paging file can sit on more than one drive.
  final List<String> files;
  final int totalSize;
}

const String _memoryManagement =
    r'SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management';

String systemDriveRoot() {
  final drive = (Platform.environment['SystemDrive'] ?? 'C:').replaceAll(
    r'\',
    '',
  );

  return '$drive\\';
}

PagefileInfo readPagefile() {
  final configured = registryMultiSz(
    hkeyLocalMachine,
    _memoryManagement,
    'PagingFiles',
  );

  final entries = <PagefileEntry>[];
  for (final line in configured ?? const <String>[]) {
    final parts = line.split(RegExp(r'\s+'))
      ..removeWhere((part) => part.isEmpty);
    if (parts.isEmpty) continue;

    entries.add(
      PagefileEntry(
        path: parts[0],
        initialMb: parts.length > 1 ? int.tryParse(parts[1]) : null,
        maximumMb: parts.length > 2 ? int.tryParse(parts[2]) : null,
      ),
    );
  }

  // Sizes come off the disk rather than out of the setting: a range says what
  // the file may become, not what it is now.
  final files = <String>[];
  var total = 0;

  for (final root in _driveRoots()) {
    final path = '${root}pagefile.sys';
    final size = fileSizeFromDirectory(path);
    if (size == null) continue;

    files.add(path);
    total += size;
  }

  return PagefileInfo(
    mode: _modeFor(configured, entries),
    entries: entries,
    files: files,
    totalSize: total,
  );
}

List<String> _driveRoots() {
  try {
    return [for (final disk in getDisks()) disk.root];
  } catch (_) {
    return [systemDriveRoot()];
  }
}

PagefileMode _modeFor(List<String>? configured, List<PagefileEntry> entries) {
  if (configured == null) return PagefileMode.unknown;
  if (entries.isEmpty) return PagefileMode.none;
  if (entries.any((entry) => entry.isAutomatic)) return PagefileMode.automatic;
  if (entries.every((entry) => entry.isSystemManaged)) {
    return PagefileMode.systemManaged;
  }

  return PagefileMode.custom;
}

/// Hands the setting back to Windows.
Future<ProcessResult> setPagefileAutomatic() => _powershell(r'''
$ErrorActionPreference = 'Stop'
$system = Get-CimInstance Win32_ComputerSystem
Set-CimInstance -InputObject $system -Property @{ AutomaticManagedPagefile = $true }
''');

/// Pins the paging file on the system drive to a range, in megabytes.
Future<ProcessResult> setPagefileCustom({
  required int initialMb,
  required int maximumMb,
}) {
  final name = '${systemDriveRoot()}pagefile.sys';

  return _powershell('''
\$ErrorActionPreference = 'Stop'
\$system = Get-CimInstance Win32_ComputerSystem
if (\$system.AutomaticManagedPagefile) {
  Set-CimInstance -InputObject \$system -Property @{ AutomaticManagedPagefile = \$false }
}
\$name = '$name'
\$setting = Get-CimInstance Win32_PageFileSetting |
  Where-Object { \$_.Name -eq \$name }
if (\$setting) {
  Set-CimInstance -InputObject \$setting -Property @{ InitialSize = $initialMb; MaximumSize = $maximumMb }
} else {
  New-CimInstance -ClassName Win32_PageFileSetting -Property @{ Name = \$name; InitialSize = $initialMb; MaximumSize = $maximumMb }
}
''');
}

/// Removes the paging file entirely.
Future<ProcessResult> setPagefileNone() => _powershell(r'''
$ErrorActionPreference = 'Stop'
$system = Get-CimInstance Win32_ComputerSystem
if ($system.AutomaticManagedPagefile) {
  Set-CimInstance -InputObject $system -Property @{ AutomaticManagedPagefile = $false }
}
Get-CimInstance Win32_PageFileSetting | Remove-CimInstance
''');

/// The paging file is configured through WMI, and PowerShell is the shortest
/// way to reach it from here. Needs an elevated process; unelevated the calls
/// come back access denied and the exit code says so, which is steadier to read
/// than a message written in whatever language Windows is installed in.
Future<ProcessResult> _powershell(String script) {
  final root = Platform.environment['SystemRoot'] ?? r'C:\Windows';

  return Process.run(
    p.join(root, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'),
    ['-NoProfile', '-NonInteractive', '-Command', script],
  );
}
