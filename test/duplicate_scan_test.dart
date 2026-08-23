import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/models.dart';

void main() {
  group('DuplicateScan.truncated', () {
    test('a walk that reached the limit saw only part of the tree', () {
      const scan = DuplicateScan(groups: [], indexed: 400000, limit: 400000);
      expect(scan.truncated, isTrue);
    });

    test('a walk that ran out of files saw all of them', () {
      const scan = DuplicateScan(groups: [], indexed: 12345, limit: 400000);
      expect(scan.truncated, isFalse);
    });
  });
}
