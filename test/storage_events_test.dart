import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/storage_events.dart';

void main() {
  group('storageChanged', () {
    test('an announcement reaches a listener', () {
      final heard = storageChanged.first;
      announceStorageChanged();

      expect(heard, completes);
    });

    test('more than one listener hears the same announcement', () {
      final first = storageChanged.first;
      final second = storageChanged.first;
      announceStorageChanged();

      expect(Future.wait([first, second]), completes);
    });

    test('a listener that arrives later is not handed the old news', () async {
      announceStorageChanged();

      // A broadcast stream keeps nothing for whoever was not there, which is
      // what stops a page from reloading over an announcement it missed.
      await expectLater(
        storageChanged.first.timeout(
          const Duration(milliseconds: 50),
          onTimeout: () => throw TimeoutException(),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}

class TimeoutException implements Exception {}
