import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/scanner.dart';

void main() {
  group('matchesPatterns', () {
    test('a lone star takes everything', () {
      expect(matchesPatterns('anything.at.all', const ['*']), isTrue);
      expect(matchesPatterns('anything', const []), isTrue);
    });

    test('matches by extension', () {
      expect(matchesPatterns('setup.log', const ['*.log']), isTrue);
      expect(matchesPatterns('setup.LOG', const ['*.log']), isTrue);
      expect(matchesPatterns('setup.log.bak', const ['*.log']), isFalse);
      expect(matchesPatterns('log', const ['*.log']), isFalse);
    });

    test('matches a star in the middle', () {
      expect(
        matchesPatterns('thumbcache_1024.db', const ['thumbcache_*.db']),
        isTrue,
      );
      expect(
        matchesPatterns('iconcache_1024.db', const ['thumbcache_*.db']),
        isFalse,
      );
      // Prefix and suffix must not be allowed to overlap into each other.
      expect(matchesPatterns('thumbcache_.db', const ['thumbcache_*.db']),
          isTrue);
      expect(matchesPatterns('thumbcache.db', const ['thumbcache_*.db']),
          isFalse);
    });

    test('matches an exact name', () {
      expect(matchesPatterns('desktop.ini', const ['desktop.ini']), isTrue);
      expect(matchesPatterns('desktop.inifile', const ['desktop.ini']),
          isFalse);
    });

    test('takes any of several patterns', () {
      const patterns = ['*.log', '*.etl', '*.old'];
      expect(matchesPatterns('trace.etl', patterns), isTrue);
      expect(matchesPatterns('trace.txt', patterns), isFalse);
    });
  });
}
