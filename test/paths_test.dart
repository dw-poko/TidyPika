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

  group('extendedPath', () {
    final deep = r'C:\' + List.filled(30, 'directory').join(r'\');

    test('a short path is left alone', () {
      expect(extendedPath(r'C:\Users\me'), r'C:\Users\me');
    });

    test('a long drive path gets the prefix', () {
      expect(deep.length, greaterThan(260));
      expect(extendedPath(deep), r'\\?\' + deep);
    });

    test('a long UNC path gets the form of its own', () {
      final unc = r'\\server\share\' + List.filled(30, 'directory').join(r'\');
      expect(extendedPath(unc), r'\\?\UNC\server\share\'
          '${List.filled(30, 'directory').join(r'\')}');
    });

    test('an already prefixed path is not prefixed twice', () {
      expect(extendedPath(extendedPath(deep)), extendedPath(deep));
    });

    test('forward slashes are squared away, since the form forbids them', () {
      final withSlashes = deep.replaceAll(r'\', '/');
      expect(extendedPath(withSlashes), r'\\?\' + deep);
    });

    test('a relative path is never prefixed, however long', () {
      final relative = List.filled(40, 'directory').join(r'\');
      expect(extendedPath(relative), relative);
    });
  });

  group('displayPath', () {
    test('takes the prefix back off', () {
      expect(displayPath(r'\\?\C:\Users\me'), r'C:\Users\me');
      expect(displayPath(r'\\?\UNC\server\share'), r'\\server\share');
    });

    test('leaves a path that never had one', () {
      expect(displayPath(r'C:\Users\me'), r'C:\Users\me');
    });

    test('undoes exactly what extendedPath did', () {
      final deep = r'C:\' + List.filled(30, 'directory').join(r'\');
      expect(displayPath(extendedPath(deep)), deep);
    });
  });

  group('exceedsMaxPath', () {
    test('measures the real path, not the prefixed one', () {
      final deep = r'C:\' + List.filled(30, 'directory').join(r'\');

      expect(exceedsMaxPath(deep), isTrue);
      expect(exceedsMaxPath(extendedPath(deep)), isTrue);
      expect(exceedsMaxPath(r'C:\Users\me'), isFalse);
    });
  });
}

