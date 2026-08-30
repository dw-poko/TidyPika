import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/component_store.dart';

/// A real report, as DISM prints it.
const String _report = '''
Deployment Image Servicing and Management tool
Version: 10.0.26100.1

Image Version: 10.0.26100.1

[==========================100.0%==========================]

Component Store (WinSxS) information:

Windows Explorer Reported Size of Component Store : 16.18 GB

Actual Size of Component Store : 15.39 GB

    Shared with Windows : 8.33 GB
    Backups and Disabled Features : 7.06 GB
    Cache and Temporary Data : 0 bytes

Date of Last Cleanup : 2025-07-02 02:02:19

Number of Reclaimable Packages : 4
Component Store Cleanup Recommended : Yes

The operation completed successfully.
''';

void main() {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;

  group('parseComponentStore', () {
    test('takes the five sizes in the order DISM prints them', () {
      final store = parseComponentStore(_report);

      expect(store.reportedSize, (16.18 * gb).round());
      expect(store.actualSize, (15.39 * gb).round());
      expect(store.sharedWithWindows, (8.33 * gb).round());
      expect(store.reclaimable, (7.06 * gb).round());
      expect(store.known, isTrue);
    });

    test('the reported size is the one that overcounts', () {
      final store = parseComponentStore(_report);

      // Which is the whole point of asking DISM: a walk would report the
      // larger number and be wrong by the amount that is hard linked.
      expect(store.reportedSize!, greaterThan(store.actualSize!));
    });

    test('adds the cache to the backups when there is any', () {
      final store = parseComponentStore(
        _report.replaceAll('Cache and Temporary Data : 0 bytes',
            'Cache and Temporary Data : 267.32 MB'),
      );

      expect(store.reclaimable, (7.06 * gb).round() + (267.32 * mb).round());
    });

    test('reads a report written with the other separators', () {
      final store = parseComponentStore(
        _report
            .replaceAll('16.18 GB', '16,18 GB')
            .replaceAll('15.39 GB', '15,39 GB'),
      );

      expect(store.reportedSize, (16.18 * gb).round());
      expect(store.actualSize, (15.39 * gb).round());
    });

    test('reads grouped digits', () {
      final store = parseComponentStore(
        _report.replaceAll('16.18 GB', '1,234.50 MB'),
      );

      expect(store.reportedSize, (1234.5 * mb).round());
    });

    test('is not fooled by the version, the date or the package count', () {
      // None of them carry a unit, which is what keeps them out.
      final store = parseComponentStore(_report);

      expect(store.actualSize, isNot(0));
      expect(store.reportedSize, greaterThan(gb));
    });

    test('says it knows nothing rather than guessing', () {
      const store = ComponentStore();

      expect(store.known, isFalse);
      expect(parseComponentStore('DISM failed').known, isFalse);
    });
  });
}
