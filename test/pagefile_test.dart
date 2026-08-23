import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/pagefile.dart';

void main() {
  group('parsePagefileEntries', () {
    test('reads a path with its range', () {
      final entries = parsePagefileEntries([r'C:\pagefile.sys 4096 8192']);

      expect(entries, hasLength(1));
      expect(entries.single.path, r'C:\pagefile.sys');
      expect(entries.single.initialMb, 4096);
      expect(entries.single.maximumMb, 8192);
    });

    test('reads a path with no range', () {
      final entries = parsePagefileEntries([r'?:\pagefile.sys']);

      expect(entries.single.isAutomatic, isTrue);
      expect(entries.single.initialMb, isNull);
    });

    test('survives odd spacing and blank lines', () {
      final entries = parsePagefileEntries([
        r'  C:\pagefile.sys   0   0  ',
        '',
        r'D:\pagefile.sys 1024 2048',
      ]);

      expect(entries, hasLength(2));
      expect(entries.first.isSystemManaged, isTrue);
      expect(entries.last.maximumMb, 2048);
    });

    test('nothing configured is no entries', () {
      expect(parsePagefileEntries(null), isEmpty);
      expect(parsePagefileEntries(const []), isEmpty);
    });
  });

  group('pagefileModeFor', () {
    // The distinction the whole card rests on: a setting that could not be
    // read must not be reported as a setting that says none.
    test('unreadable is not the same as none', () {
      expect(pagefileModeFor(null, const []), PagefileMode.unknown);
      expect(pagefileModeFor(const [], const []), PagefileMode.none);
    });

    test('a question mark for the drive means Windows manages it', () {
      final configured = [r'?:\pagefile.sys'];
      expect(
        pagefileModeFor(configured, parsePagefileEntries(configured)),
        PagefileMode.automatic,
      );
    });

    test('zero to zero means the system sizes it', () {
      final configured = [r'C:\pagefile.sys 0 0'];
      expect(
        pagefileModeFor(configured, parsePagefileEntries(configured)),
        PagefileMode.systemManaged,
      );
    });

    test('a real range means someone set it', () {
      final configured = [r'C:\pagefile.sys 2048 4096'];
      expect(
        pagefileModeFor(configured, parsePagefileEntries(configured)),
        PagefileMode.custom,
      );
    });

    test('one custom drive among system-managed ones counts as custom', () {
      final configured = [r'C:\pagefile.sys 0 0', r'D:\pagefile.sys 512 1024'];
      expect(
        pagefileModeFor(configured, parsePagefileEntries(configured)),
        PagefileMode.custom,
      );
    });
  });
}
