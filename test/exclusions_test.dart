import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/exclusions.dart';

void main() {
  group('isExcluded', () {
    final roots = {
      normaliseExclusion(r'C:\Games'),
      normaliseExclusion(r'D:\Footage\'),
    };

    test('the folder itself is excluded', () {
      expect(isExcluded(r'C:\Games', roots), isTrue);
      expect(isExcluded(r'D:\Footage', roots), isTrue);
    });

    test('so is everything inside it', () {
      expect(isExcluded(r'C:\Games\Steam\common\game.pak', roots), isTrue);
    });

    test('a name that merely starts the same is not', () {
      // The trap a plain prefix test falls into.
      expect(isExcluded(r'C:\GamesBackup', roots), isFalse);
      expect(isExcluded(r'C:\Games2\save.dat', roots), isFalse);
    });

    test('case and separators do not matter', () {
      expect(isExcluded(r'c:\games\STEAM', roots), isTrue);
      expect(isExcluded('C:/Games/Steam', roots), isTrue);
    });

    test('nothing excluded excludes nothing', () {
      expect(isExcluded(r'C:\Games', const {}), isFalse);
    });

    test('a trailing separator on the rule changes nothing', () {
      expect(
        normaliseExclusion(r'C:\Games\'),
        normaliseExclusion(r'C:\Games'),
      );
    });

    test('a drive root keeps its separator, being nothing without it', () {
      expect(normaliseExclusion(r'C:\'), r'c:\');
      expect(isExcluded(r'C:\anything', {normaliseExclusion(r'C:\')}), isTrue);
    });
  });
}
