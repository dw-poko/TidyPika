import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// What the dashboard remembers between runs.
///
/// Two things worth keeping: how much room the system drive had each day, so
/// the last week can be compared, and what the last clean actually recovered.
/// Both are small, both are written best-effort — a storage tool that cannot
/// write its own notes should still run.
class Snapshot {
  const Snapshot({required this.day, required this.free});

  /// Date only. One sample a day is enough for a week's comparison, and it
  /// keeps the file from growing with every launch.
  final DateTime day;
  final int free;
}

class CleanRecord {
  const CleanRecord({
    required this.at,
    required this.files,
    required this.bytes,
  });

  final DateTime at;
  final int files;
  final int bytes;
}

class History {
  const History({required this.samples, required this.lastClean});

  final List<Snapshot> samples;
  final CleanRecord? lastClean;

  /// Change in free space against the oldest sample no more than [days] old.
  /// Null until there is an earlier day to compare against.
  int? freeChangeOver(int days) {
    if (samples.length < 2) return null;

    final now = samples.last;
    final cutoff = now.day.subtract(Duration(days: days));

    for (final sample in samples) {
      if (sample.day.isBefore(cutoff)) continue;
      if (sample.day == now.day) break;

      return now.free - sample.free;
    }

    return null;
  }
}

/// Days kept. Enough for a week's comparison several times over, small enough
/// that the file stays a few kilobytes.
const int _maxSamples = 90;

File _file() {
  final base =
      Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;

  return File(p.join(base, 'TidyPika', 'history.json'));
}

Map<String, dynamic> _read() {
  try {
    final file = _file();
    if (!file.existsSync()) return {};

    final parsed = jsonDecode(file.readAsStringSync());
    return parsed is Map<String, dynamic> ? parsed : {};
  } catch (_) {
    return {};
  }
}

void _write(Map<String, dynamic> data) {
  try {
    final file = _file();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(data));
  } catch (_) {
    // Best effort by design.
  }
}

DateTime _dayOf(DateTime value) =>
    DateTime(value.year, value.month, value.day);

History readHistory() {
  final data = _read();

  final samples = <Snapshot>[];
  final raw = data['samples'];
  if (raw is List) {
    for (final entry in raw) {
      if (entry is! Map) continue;

      final day = DateTime.tryParse('${entry['day']}');
      final free = entry['free'];
      if (day == null || free is! int) continue;

      samples.add(Snapshot(day: _dayOf(day), free: free));
    }
  }

  samples.sort((a, b) => a.day.compareTo(b.day));

  CleanRecord? lastClean;
  final clean = data['lastClean'];
  if (clean is Map) {
    final at = DateTime.tryParse('${clean['at']}');
    final files = clean['files'];
    final bytes = clean['bytes'];

    if (at != null && files is int && bytes is int) {
      lastClean = CleanRecord(at: at, files: files, bytes: bytes);
    }
  }

  return History(samples: samples, lastClean: lastClean);
}

/// Records today's free space, replacing today's sample if there is one.
void recordFreeSpace(int free) {
  final data = _read();
  final today = _dayOf(DateTime.now());

  final samples = <Map<String, dynamic>>[];
  final raw = data['samples'];
  if (raw is List) {
    for (final entry in raw) {
      if (entry is! Map) continue;

      final day = DateTime.tryParse('${entry['day']}');
      if (day == null || _dayOf(day) == today) continue;

      samples.add({
        'day': _dayOf(day).toIso8601String(),
        'free': entry['free'],
      });
    }
  }

  samples.add({'day': today.toIso8601String(), 'free': free});
  if (samples.length > _maxSamples) {
    samples.removeRange(0, samples.length - _maxSamples);
  }

  data['samples'] = samples;
  _write(data);
}

void recordClean({required int files, required int bytes}) {
  final data = _read();
  data['lastClean'] = {
    'at': DateTime.now().toIso8601String(),
    'files': files,
    'bytes': bytes,
  };

  _write(data);
}
