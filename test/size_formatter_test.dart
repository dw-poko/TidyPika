import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/size_formatter.dart';

void main() {
  group('formatSize', () {
    test('nothing reads as nothing', () {
      expect(formatSize(0), '0 B');
      expect(formatSize(-1), '0 B');
    });

    test('bytes carry no decimal', () {
      expect(formatSize(1), '1 B');
      expect(formatSize(1023), '1023 B');
    });

    test('steps up at 1024, not 1000', () {
      expect(formatSize(1024), '1.0 KB');
      expect(formatSize(1024 * 1024), '1.0 MB');
      expect(formatSize(1024 * 1024 * 1024), '1.0 GB');
      expect(formatSize(1536), '1.5 KB');
    });

    test('keeps going past terabytes', () {
      expect(formatSize(1024 * 1024 * 1024 * 1024), '1.0 TB');
      expect(formatSize(1024 * 1024 * 1024 * 1024 * 1024), '1.0 PB');
    });
  });

  group('formatCount', () {
    test('groups digits in threes', () {
      expect(formatCount(0), '0');
      expect(formatCount(999), '999');
      expect(formatCount(1000), '1,000');
      expect(formatCount(1234567), '1,234,567');
    });

    test('keeps the sign outside the grouping', () {
      expect(formatCount(-1234), '-1,234');
    });
  });
}
