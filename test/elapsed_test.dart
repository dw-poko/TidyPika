import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/size_formatter.dart';

void main() {
  group('elapsedParts', () {
    test('under a minute is all seconds, fraction kept', () {
      expect(elapsedParts(const Duration(milliseconds: 400)), (0, 0.4));
      expect(elapsedParts(const Duration(seconds: 12, milliseconds: 300)),
          (0, 12.3));
      expect(elapsedParts(Duration.zero), (0, 0.0));
    });

    test('a minute is a minute and no seconds', () {
      expect(elapsedParts(const Duration(minutes: 1)), (1, 0.0));
    });

    test('past a minute the leftover seconds come out', () {
      final (minutes, seconds) =
          elapsedParts(const Duration(minutes: 2, seconds: 5));

      expect(minutes, 2);
      expect(seconds, closeTo(5, 0.001));
    });

    test('the seconds never carry a whole minute of their own', () {
      final (_, seconds) = elapsedParts(
          const Duration(minutes: 3, seconds: 59, milliseconds: 900));

      expect(seconds, lessThan(60));
    });
  });
}
