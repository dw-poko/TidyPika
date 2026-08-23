import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/hibernation.dart';

void main() {
  group('hibernationStateFrom', () {
    test('the setting decides when it can be read', () {
      expect(hibernationStateFrom(true, null), HibernationState.on);
      expect(hibernationStateFrom(true, 8000), HibernationState.on);
      expect(hibernationStateFrom(false, null), HibernationState.off);

      // Even with a file still on disk: the setting is the answer.
      expect(hibernationStateFrom(false, 8000), HibernationState.off);
    });

    test('without the setting, a file that is there proves it is on', () {
      expect(hibernationStateFrom(null, 8000), HibernationState.on);
    });

    test('without the setting, a file that is not there proves nothing', () {
      // This is the bug that shipped twice: a read that failed and a file that
      // is absent look identical from here, and the difference was being
      // guessed at as off.
      expect(hibernationStateFrom(null, null), HibernationState.unknown);
    });
  });
}
