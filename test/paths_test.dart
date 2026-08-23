import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/paths.dart';

void main() {
  group('pathCrumbs', () {
    test('a drive root is one step', () {
      expect(pathCrumbs(r'C:\'), [(r'C:', r'C:\')]);
    });

    test('each folder carries the path that reaches it', () {
      expect(pathCrumbs(r'C:\Users\me'), [
        (r'C:', r'C:\'),
        ('Users', r'C:\Users'),
        ('me', r'C:\Users\me'),
      ]);
    });

    test('a trailing separator changes nothing', () {
      expect(pathCrumbs(r'C:\Users\me\'), pathCrumbs(r'C:\Users\me'));
    });

    test('forward slashes are read the same way', () {
      expect(pathCrumbs('C:/Users/me'), pathCrumbs(r'C:\Users\me'));
    });

    test('doubled separators do not make empty steps', () {
      expect(pathCrumbs(r'C:\\Users\\me'), pathCrumbs(r'C:\Users\me'));
    });

    test('nothing in, nothing out', () {
      expect(pathCrumbs(''), isEmpty);
      expect(pathCrumbs(r'\'), isEmpty);
    });
  });
}
