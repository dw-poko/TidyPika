import 'package:flutter_test/flutter_test.dart';
import 'package:tidypika/core/history.dart';

History historyFor(List<(int, int)> daysAgoAndFree) {
  final today = DateTime.now();

  return History(
    samples: [
      for (final (daysAgo, free) in daysAgoAndFree)
        Snapshot(
          day: DateTime(today.year, today.month, today.day - daysAgo),
          free: free,
        ),
    ],
    lastClean: null,
  );
}

void main() {
  group('freeChangeOver', () {
    test('one day on its own has nothing to compare against', () {
      expect(historyFor([(0, 100)]).freeChangeOver(7), isNull);
      expect(historyFor([]).freeChangeOver(7), isNull);
    });

    test('reports what was lost since the oldest day in the window', () {
      final history = historyFor([(6, 500), (3, 400), (0, 300)]);
      expect(history.freeChangeOver(7), -200);
    });

    test('reports space recovered as a gain', () {
      final history = historyFor([(2, 100), (0, 350)]);
      expect(history.freeChangeOver(7), 250);
    });

    test('ignores days older than the window', () {
      // The 30-day-old sample must not be the one compared against.
      final history = historyFor([(30, 900), (5, 500), (0, 450)]);
      expect(history.freeChangeOver(7), -50);
    });

    test('a window with only today in it has nothing to say', () {
      expect(historyFor([(30, 900), (0, 450)]).freeChangeOver(7), isNull);
    });
  });
}
